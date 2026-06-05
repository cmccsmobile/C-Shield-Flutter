# Tích hợp CShield Flutter SDK — iOS Host App

Plugin `c_shield_sdk` không bundle XCFramework. Host app chịu trách nhiệm cung cấp
`CShieldSDK.xcframework` (variant Debug/Release) và `OpenSSL.xcframework`.

---

## Yêu cầu

- iOS 13.0+
- Xcode 15+
- CocoaPods

---

## Bước 1 — Nhận file từ CShield team

Nhận đủ các file XCFramework bao gồm:

```
- CShieldSDK.xcframework          ← Release variant
- CShieldSDK-Debug.xcframework    ← Debug variant
- OpenSSL.xcframework
```

---

## Bước 2 — Tổ chức thư mục `Libs/`

Dùng Xcode mở thư mục `ios` của dự án Flutter theo đường dẫn `<your_app>/ios/Runner.xcworkspace`. Tạo thư mục `Libs` trong `Runner`, rồi tạo tiếp các thư mục con `Debug` và `Release` trong `Libs`:

```
Runner
├── Libs/                                       ← thư mục mới tạo
│   ├── OpenSSL.xcframework                     ← copy từ build/
│   ├── Debug/
│   │   └── CShieldSDK.xcframework              ← copy CShieldSDK-Debug.xcframework, đổi tên
│   └── Release/
│       └── CShieldSDK.xcframework              ← copy CShieldSDK.xcframework (release)
├── Flutter/
├── Products/
├── Pods/
├── Framework/
└── ...

```

> **Lưu ý:** `CShieldSDK-Debug.xcframework` phải được **đổi tên** thành `CShieldSDK.xcframework`
> khi đặt vào thư mục `Debug/`.

> **Lưu ý:** Phải **kéo thả** từng file
> `.xcframework` vào đúng vị trí tương ứng trong Xcode Project Navigator:
> - `OpenSSL.xcframework` → kéo vào nhóm `Libs/`
> - `CShieldSDK.xcframework` (Debug) → kéo vào nhóm `Libs/Debug/`
> - `CShieldSDK.xcframework` (Release) → kéo vào nhóm `Libs/Release/`
>
> Nếu không kéo thả, Xcode sẽ không nhận ra các framework này trong project.

---

## Bước 3 — Cập nhật `Podfile`

Mở `ios/Podfile`, thêm `post_install` để set Framework Search Paths cho CShieldSDK.
Cần set ở **hai nơi** để cover cả compile lẫn link:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # 1. Pod targets — để plugin c_shield_sdk compile được `import CShieldSDK`
    target.build_configurations.each do |config|
      variant = (config.name == 'Debug') ? 'Debug' : 'Release'

      existing = Array(config.build_settings['FRAMEWORK_SEARCH_PATHS']).flatten
      existing = ['$(inherited)'] if existing.empty?

      config.build_settings['FRAMEWORK_SEARCH_PATHS'] = (existing + [
        "\"$(PODS_ROOT)/../Libs/#{variant}/CShieldSDK.xcframework/ios-arm64\"",
        "\"$(PODS_ROOT)/../Libs/#{variant}/CShieldSDK.xcframework/ios-arm64_x86_64-simulator\"",
      ]).uniq
    end
  end

  # 2. Aggregate xcconfig (Pods-Runner.debug/release.xcconfig) — để Runner app link được CShieldSDK. Tương đương bước set "Framework Search Paths" thủ công trong Xcode.
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.xcconfigs.each do |config_name, xcconfig|
      variant = (config_name == 'Debug') ? 'Debug' : 'Release'

      paths = [
        "\"$(PODS_ROOT)/../Libs/#{variant}/CShieldSDK.xcframework/ios-arm64\"",
        "\"$(PODS_ROOT)/../Libs/#{variant}/CShieldSDK.xcframework/ios-arm64_x86_64-simulator\"",
      ]

      existing = xcconfig.attributes['FRAMEWORK_SEARCH_PATHS'] || '$(inherited)'
      xcconfig.attributes['FRAMEWORK_SEARCH_PATHS'] = ([existing] + paths).uniq.join(' ')
      xcconfig.save_as(aggregate_target.xcconfig_path(config_name))
    end
  end
end
```

Sau đó chạy:

```bash
flutter pub get
cd ios && pod install
```

---

## Bước 4 — Cấu hình Xcode (thủ công, làm 1 lần)

Mở `Runner.xcworkspace` trong Xcode.

### 4a. Embed OpenSSL

`Runner target → General → Frameworks, Libraries, and Embedded Content → +`

Chọn `Libs/OpenSSL.xcframework`, cột **Embed** đặt thành **Embed & Sign**.

### 4b. Tắt User Script Sandboxing

`Runner target → Build Settings → User Script Sandboxing → No`

### 4c. Thêm Run Script Phase để embed CShieldSDK

`Runner target → Build Phases → + → New Run Script Phase`

Đặt tên phase là **Embed CShieldSDK**, kéo lên ngay bên dưới **Compile Sources**.

Dán script sau vào ô script:

```bash
if [[ "$SDK_NAME" == *"simulator"* ]]; then
  SLICE="ios-arm64_x86_64-simulator"
else
  SLICE="ios-arm64"
fi

# Normalize configuration name to Debug or Release.
# Flutter flavors tạo ra tên config dạng "Debug-production", "Release-production",
# "Profile-production"... không khớp với tên thư mục trong Libs/.
if [[ "$CONFIGURATION" == *"Release"* ]] || [[ "$CONFIGURATION" == *"Profile"* ]]; then
  LIB_CONFIG="Release"
else
  LIB_CONFIG="Debug"
fi

SRC="${PROJECT_DIR}/Libs/${LIB_CONFIG}/CShieldSDK.xcframework/${SLICE}/CShieldSDK.framework"
DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/CShieldSDK.framework"

mkdir -p "${DEST}"
rsync -av --delete "${SRC}/" "${DEST}/"

if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" ]; then
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "${DEST}"
fi
```

Trong phần **Output Files** của phase này, thêm:

```
$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/CShieldSDK.framework
```

---

## Kết quả cuối — Cấu trúc thư mục

```
<your_app>/ios/
├── Libs/
│   ├── OpenSSL.xcframework
│   ├── Debug/
│   │   └── CShieldSDK.xcframework
│   └── Release/
│       └── CShieldSDK.xcframework
├── Podfile                    ← đã cập nhật ở Bước 3
└── Runner.xcworkspace
```

---

## Tóm tắt vai trò các bước

| Bước | Cái gì xảy ra | Tương đương native doc |
|------|---------------|------------------------|
| `s.frameworks = 'CShieldSDK'` trong plugin podspec | CocoaPods tự động ghi `-framework CShieldSDK` vào `Pods-Runner.*.xcconfig` → Runner inherit | Bước 6: Other Linker Flags |
| `post_install` search paths | Compiler và linker tìm được `CShieldSDK.framework` theo variant | Bước 7: Framework Search Paths |
| Embed OpenSSL (Xcode — Bước 4a) | `OpenSSL.xcframework` được đóng gói vào app bundle | Bước 5: Embed & Sign |
| Run Script "Embed CShieldSDK" (Xcode — Bước 4c) | Copy đúng variant (Debug/Release) vào app bundle lúc build | Bước 9: Run Script Phase |
| Tắt User Script Sandboxing (Xcode — Bước 4b) | Cho phép Run Script truy cập file ngoài sandbox | Bước 8: User Script Sandboxing |

---

## Troubleshooting

### Build simulator lỗi: `(l)stat: No such file or directory` tại `Libs/Debug-production/...`

**Nguyên nhân**: Khi project dùng Flutter flavors (e.g. `production`, `development`), Xcode đặt tên build configuration theo dạng `Debug-production`, `Release-production`, `Profile-production`... thay vì `Debug`/`Release` thuần. Script trong phase "Embed CShieldSDK" dùng `${CONFIGURATION}` trực tiếp làm tên thư mục, nên tìm `Libs/Debug-production/` nhưng thư mục đó không tồn tại.

**Fix**: Thêm bước chuẩn hóa trong script trước khi dùng làm đường dẫn (script đã được cập nhật ở Bước 4c phía trên). Nếu đã cấu hình thủ công bằng script cũ, sửa lại bằng cách thêm đoạn sau vào script, trước dòng `SRC=...`:

```bash
if [[ "$CONFIGURATION" == *"Release"* ]] || [[ "$CONFIGURATION" == *"Profile"* ]]; then
  LIB_CONFIG="Release"
else
  LIB_CONFIG="Debug"
fi
```

Và thay `${CONFIGURATION}` → `${LIB_CONFIG}` trong dòng `SRC=...`.

---

### `pod install` báo lỗi: `Unable to find compatibility version string for object version 74`

**Nguyên nhân**: Xcode 16 (một số phiên bản beta/RC) lưu project với `objectVersion = 74`. xcodeproj gem (dùng trong CocoaPods 1.16.x) chỉ biết các giá trị `60` (Xcode 15.0), `63` (Xcode 15.3), `77` (Xcode 16.0 final) — bỏ qua `74`.

**Fix**: Mở `ios/Runner.xcodeproj/project.pbxproj`, tìm dòng đầu file và sửa:

```
objectVersion = 74;
```
thành:
```
objectVersion = 77;
```

---

### `pod install` in warning: `Xcodeproj doesn't know about the following attributes {"attributesByRelativePath" => ...} for the 'PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet'`

**Đây là warning vô hại**, không gây pod install thất bại.

**Giải thích**: Khi thực hiện Bước 4a (thêm `OpenSSL.xcframework` vào "Embed & Sign" trong Xcode UI), Xcode tự động tạo ra một entry kiểu `PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet` trong `project.pbxproj` để lưu các thuộc tính `CodeSignOnCopy` / `RemoveHeadersOnCopy`. Entry này sinh ra vì thư mục `Libs/` được Xcode quản lý dưới dạng **File System Synchronized Root Group** (tính năng Xcode 15+). xcodeproj gem biết ISA này nhưng chưa biết attribute `attributesByRelativePath` bên trong nó nên in cảnh báo.

`pod install` **không ghi đè** `Runner/project.pbxproj` nên attribute được giữ nguyên — OpenSSL vẫn được embed với `CodeSignOnCopy` + `RemoveHeadersOnCopy` đúng cách khi build trong Xcode.

