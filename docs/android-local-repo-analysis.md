# Phân tích Android Local Repo & Giải pháp Remote Maven

## 1. Cấu trúc SDK hiện tại

### Tổng quan

```
c_shield_sdk/
├── android/                  # Android platform implementation
│   ├── src/                  # Kotlin bridge code (RASP/AIP API)
│   ├── build.gradle          # Gradle config, khai báo dependency AAR
│   └── local-repo/           # ⚠ Local Maven repo chứa AAR (~54 MB)
├── ios/
│   ├── Classes/              # Swift bridge code
│   └── Frameworks/
│       ├── CShieldSDK.xcframework
│       └── OpenSSL.xcframework
├── lib/                      # Dart API (platform channel)
│   └── src/api/
└── example/                  # App demo tích hợp
```

### Tại sao phải dùng Local Maven?

Flutter plugin **không thể tích hợp file `.aar` trực tiếp** như một Android app thông thường vì:

- Flutter plugin là một Gradle **sub-project** được nhúng vào build của app. Gradle chỉ resolve dependency theo chuẩn Maven — không hỗ trợ khai báo file `.aar` local bằng đường dẫn thư mục như `implementation(files("libs/foo.aar"))` ở cấp plugin.
- Khi Gradle build toàn bộ project (app + plugin), nó cần resolve `c-shield-sdk` từ một Maven repository hợp lệ với đầy đủ POM metadata.

**Giải pháp hiện tại:** Build AAR từ Android SDK project (`CShieldSampleApp/c-shield-sdk`), publish vào một local Maven repo nằm trong thư mục `android/local-repo/` của Flutter plugin. Flutter plugin khai báo repo này trong `build.gradle` để Gradle có thể resolve.

### Vấn đề của Local Repo

| Vấn đề | Chi tiết |
|--------|---------|
| **Dung lượng lớn** | AAR ~53 MB, chứa 4 ABI (arm64-v8a, armeabi-v7a, x86, x86_64) và native asset `.ccs` cho mỗi ABI |
| **Nặng repo Git** | Binary lớn commit thẳng vào repo → clone/pull chậm, Git không diff được binary |
| **Workflow thủ công** | Dev phải build lại AAR và copy vào `local-repo/` mỗi khi Android SDK có thay đổi |
| **Hardcode đường dẫn** | Path `local-repo/` được hardcode trong `build.gradle` → dễ sai môi trường |
| **x86/x86_64 thừa** | Hai ABI này chỉ dùng cho emulator, chiếm ~35 MB không cần thiết cho production |

---

## 2. Giải pháp: Remote Maven — GitHub Packages

### Mô tả

Thay vì bundle AAR vào repo, publish AAR lên **GitHub Packages Maven Registry** (private). Flutter plugin và consumer app resolve dependency qua URL + token xác thực.

### Kiến trúc

```
Android SDK project
       │
       │  ./gradlew assembleRelease
       ▼
GitHub Packages Maven Registry  (private, cần token)
       │
       │  Gradle resolve tự động
       ▼
Flutter plugin build (consumer app)
```

### Cấu hình Android SDK — publish lên GitHub Packages

```kotlin
// c-shield-sdk/build.gradle.kts
publishing {
    repositories {
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/YOUR_ORG/c-shield-sdk")
            credentials {
                username = System.getenv("GITHUB_ACTOR")
                    ?: (project.findProperty("gpr.user") as String?)
                password = System.getenv("GITHUB_TOKEN")
                    ?: (project.findProperty("gpr.key") as String?)
            }
        }
    }
}
```

### Cấu hình Flutter plugin — resolve từ GitHub Packages

```groovy
// android/build.gradle
gradle.allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/YOUR_ORG/c-shield-sdk")
            credentials(HttpHeaderCredentials) {
                name = "Authorization"
                value = "Bearer " + (System.getenv("GITHUB_TOKEN")
                    ?: project.findProperty("gpr.key"))
            }
            authentication { header(HttpHeaderAuthentication) }
        }
    }
}
```

### Thiết lập cho developer / CI

```properties
# ~/.gradle/gradle.properties (mỗi máy dev)
gpr.user=github-username
gpr.key=ghp_xxxxxxxxxxxxxxxxxxxx   # GitHub PAT, scope: read:packages
```

### Ưu điểm

- Xóa hoàn toàn `local-repo/` khỏi repo Git → repo nhẹ
- Gradle tự cache AAR vào `~/.gradle/caches` → chỉ download một lần
- Phân quyền rõ ràng: deploy token riêng biệt cho CI và từng developer
- Tích hợp tốt với GitHub Actions CI/CD (`$GITHUB_TOKEN` được inject tự động)

### Hạn chế

- Consumer cần GitHub account và Personal Access Token (PAT)
- Cần internet để resolve lần đầu (hoặc khi cache expire)

---

## 3. Giải pháp: Remote Maven — GitLab Package Registry (nội bộ)

### Mô tả

Sử dụng **GitLab Maven Package Registry** tích hợp sẵn trong GitLab nội bộ. Phù hợp nhất với yêu cầu bảo mật vì toàn bộ hạ tầng nằm trong mạng nội bộ.

### Kiến trúc

```
Android SDK project (GitLab nội bộ)
       │
       │  GitLab CI pipeline (tag mới → tự publish)
       ▼
GitLab Maven Package Registry  (chỉ accessible trong mạng nội bộ)
       │
       │  Gradle resolve (cần VPN hoặc mạng nội bộ)
       ▼
Flutter plugin build (consumer app)
```

### Cấu hình Android SDK — publish lên GitLab

```kotlin
// c-shield-sdk/build.gradle.kts
publishing {
    repositories {
        maven {
            name = "GitLabPackages"
            url = uri("https://gitlab.internal.company.com/api/v4/projects/PROJECT_ID/packages/maven")
            credentials(HttpHeaderCredentials::class) {
                name = "Deploy-Token"
                value = System.getenv("GITLAB_DEPLOY_TOKEN")
                    ?: (project.findProperty("gitlab.token") as String?)
            }
            authentication {
                create<HttpHeaderAuthentication>("header")
            }
        }
    }
}
```

### Cấu hình Flutter plugin — resolve từ GitLab

```groovy
// android/build.gradle
gradle.allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://gitlab.internal.company.com/api/v4/projects/PROJECT_ID/packages/maven")
            credentials(HttpHeaderCredentials) {
                name = "Deploy-Token"
                value = System.getenv("GITLAB_DEPLOY_TOKEN")
                    ?: project.findProperty("gitlab.token")
            }
            authentication { header(HttpHeaderAuthentication) }
        }
    }
}
```

### Thiết lập Deploy Token

Vào GitLab project → **Settings → Repository → Deploy tokens**:
- Scope: chỉ tick `read_package_registry`
- Dùng `$CI_JOB_TOKEN` cho GitLab CI (inject tự động, không cần lưu secret)

```properties
# ~/.gradle/gradle.properties (mỗi máy dev)
gitlab.token=gldt-xxxxxxxxxxxxxxxxxxxx
```

### GitLab CI — tự động publish khi tag

```yaml
# .gitlab-ci.yml
publish-aar:
  stage: deploy
  script:
    - ./gradlew assembleRelease  # finalizedBy publish task
  only:
    - tags
  variables:
    GITLAB_DEPLOY_TOKEN: $CI_JOB_TOKEN
```

### Vấn đề liên quan đến mạng nội bộ

| Tình huống | Vấn đề | Giải pháp |
|-----------|--------|-----------|
| **Dev làm việc remote** | Không resolve được dependency khi off-VPN | Bắt buộc kết nối VPN khi build, hoặc Gradle offline mode sau lần đầu cache |
| **CI/CD bên ngoài** | Pipeline GitHub Actions / CircleCI không vào được mạng nội bộ | Dùng GitLab CI hoặc self-hosted runner trong mạng nội bộ |
| **Khách hàng external** | Không thể download AAR nếu không có quyền truy cập mạng nội bộ | Cần VPN account riêng, hoặc chuyển sang GitLab Registry với external access được mở |
| **Cache Gradle** | Sau khi resolve lần đầu, Gradle cache local → build offline được | Đảm bảo `~/.gradle/caches` không bị xóa giữa các build |

---

## Tóm tắt so sánh

| Tiêu chí | Local Repo (hiện tại) | GitHub Packages | GitLab nội bộ |
|---------|----------------------|-----------------|---------------|
| Dung lượng repo | ⚠ +54 MB binary | ✅ Không có binary | ✅ Không có binary |
| Bảo mật | ⚠ Binary trong repo | ✅ Private, cần token | ✅ Chỉ trong mạng nội bộ |
| Workflow update | ⚠ Thủ công | ✅ CI tự động | ✅ CI tự động |
| Yêu cầu network | ✅ Offline hoàn toàn | ⚠ Cần internet | ⚠ Cần mạng nội bộ/VPN |
| Setup phức tạp | ✅ Đơn giản | ⚠ Cần PAT token | ⚠ Cần Deploy token + VPN |

