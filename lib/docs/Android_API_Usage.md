# CShield SDK — Hướng dẫn sử dụng API

## Mục lục

1. [Khởi tạo SDK](#1-khởi-tạo-sdk)
2. [RASP — Runtime Application Self-Protection](#2-rasp--runtime-application-self-protection)
   - 2.1 [Xây dựng RASPChecker](#21-xây-dựng-raspchecker)
   - 2.2 [Cấu hình RASPConfig](#22-cấu-hình-raspconfig)
   - 2.3 [quickCheck — kiểm tra nhanh](#23-quickcheck--kiểm-tra-nhanh)
   - 2.4 [subscribe — kiểm tra chi tiết](#24-subscribe--kiểm-tra-chi-tiết)
   - 2.5 [Xử lý kết quả RASPExtendedResult](#25-xử-lý-kết-quả-raspextendedresult)
   - 2.6 [Bảng RASPCheckType](#26-bảng-raspchecktype)
   - 2.7 [ThreatDetectedAction](#27-threatdetectedaction)
3. [AIP — API Integrity Protection](#3-aip--api-integrity-protection)
   - 3.1 [Certificate Pinning — CShieldSSL](#31-certificate-pinning--cshieldssl)
   - 3.2 [Request/Response signing — CShieldInterceptor](#32-requestresponse-signing--cshieldinterceptor)
   - 3.3 [Tích hợp với OkHttp / Retrofit](#33-tích-hợp-với-okhttp--retrofit)
   - 3.4 [Giao thức ký số (protocol)](#34-giao-thức-ký-số-protocol)
   - 3.5 [AIPCore — ký thủ công (nâng cao)](#35-aipcore--ký-thủ-công-nâng-cao)

---

## 1. Khởi tạo SDK

SDK tự khởi tạo qua `ContentProvider` khi app start (không cần gọi thủ công trong hầu hết trường hợp). Nếu cần khởi tạo tường minh, gọi trong `Application.onCreate()`:

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        CShieldSDK.initialize(this)
    }
}
```

> **Lưu ý:** `CShieldSDK.initialize()` chỉ chạy một lần trong vòng đời app. Các lần gọi sau sẽ bị bỏ qua.

---

## 2. RASP — Runtime Application Self-Protection

RASP cho phép kiểm tra môi trường runtime của thiết bị để phát hiện các mối đe dọa bảo mật.

### 2.1 Xây dựng RASPChecker

Dùng `RASPChecker.Builder` để chọn các loại kiểm tra cần bật:

```kotlin
val raspChecker = RASPChecker.Builder(
    context          = context,
    checkDebugger    = true,   // phát hiện debugger đang attach
    rootDetector     = true,   // phát hiện thiết bị đã root
    tampering        = true,   // phát hiện app bị giả mạo / cài từ nguồn không tin cậy
    emulator         = true,   // phát hiện chạy trên máy ảo
    deviceSecurityState = true // phát hiện trạng thái bảo mật thiết bị không an toàn
).build()
```

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `context` | `Context` | bắt buộc | Android context |
| `checkDebugger` | `Boolean` | `true` | Bật kiểm tra debugger |
| `rootDetector` | `Boolean` | `true` | Bật kiểm tra root |
| `tampering` | `Boolean` | `true` | Bật kiểm tra tampering |
| `emulator` | `Boolean` | `true` | Bật kiểm tra emulator |
| `deviceSecurityState` | `Boolean` | `true` | Bật kiểm tra trạng thái bảo mật thiết bị |

---

### 2.2 Cấu hình RASPConfig

Sau khi build, có thể cấu hình thêm qua `setRASPConfig()`:

```kotlin
raspChecker.setRASPConfig(
    RASPConfig(
        trustedStores = arrayOf(
            "com.android.vending",        // Google Play Store
            "com.samsung.android.galaxyapps" // Samsung Galaxy Store (tuỳ chọn)
        ),
        threatActionConfig = ThreatActionConfig(
            debuggerDetectedAction              = ThreatDetectedAction.NotifyApp,
            rootDetectedAction                  = ThreatDetectedAction.KillApp,
            tamperingDetectedAction             = ThreatDetectedAction.KillApp,
            emulatorDetectedAction              = ThreatDetectedAction.NotifyApp,
            deviceSecurityStateUnsafeDetectedAction = ThreatDetectedAction.NotifyApp,
            userCADetectedAction                = ThreatDetectedAction.NotifyApp,
        )
    )
)
```

**`RASPConfig`**

| Trường | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `trustedStores` | `Array<String>?` | `null` (dùng danh sách mặc định) | Danh sách package name của các store tin cậy để kiểm tra tampering |
| `threatActionConfig` | `ThreatActionConfig?` | `null` | Cấu hình hành động khi phát hiện mối đe dọa |

> Khi `trustedStores = null`, SDK dùng danh sách mặc định bao gồm: Google Play, Samsung, Xiaomi, Huawei, OPPO, Vivo, Amazon, OnePlus.

**`ThreatActionConfig`** — tất cả trường đều có giá trị mặc định là `NotifyApp`:

| Trường | Mô tả |
|---|---|
| `debuggerDetectedAction` | Hành động khi phát hiện debugger |
| `rootDetectedAction` | Hành động khi phát hiện root |
| `tamperingDetectedAction` | Hành động khi phát hiện app bị giả mạo |
| `emulatorDetectedAction` | Hành động khi phát hiện emulator |
| `deviceSecurityStateUnsafeDetectedAction` | Hành động khi trạng thái bảo mật thiết bị không an toàn |
| `userCADetectedAction` | Hành động khi phát hiện user CA (chứng chỉ giả mạo) |

---

### 2.3 quickCheck — kiểm tra nhanh

Trả về kết quả tổng quan duy nhất (`RASPResult`). Phù hợp để kiểm tra nhanh tại entry point của app.

```kotlin
val result: RASPResult = raspChecker.quickCheck()

when (result) {
    RASPResult.Secure                   -> { /* thiết bị an toàn */ }
    RASPResult.DebuggerFound            -> { /* debugger đang attach */ }
    RASPResult.DeviceRooted             -> { /* thiết bị đã root */ }
    RASPResult.DeviceTampered           -> { /* app bị giả mạo */ }
    RASPResult.EmulatorFound            -> { /* đang chạy trên emulator */ }
    RASPResult.DeviceSecurityStateUnsafe -> { /* trạng thái bảo mật không an toàn */ }
    RASPResult.UserCADetected           -> { /* user CA được cài đặt */ }
}
```

> `quickCheck()` trả về mối đe dọa đầu tiên tìm thấy, không liệt kê tất cả. Dùng `subscribe()` nếu cần đầy đủ kết quả.

---

### 2.4 subscribe — kiểm tra chi tiết

`subscribe()` chạy kiểm tra và gọi callback với kết quả cho từng mối đe dọa.

**Tham số:**

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `detail` | `Boolean` | `false` | `false` = tổng quan mỗi nhóm, `true` = từng sub-check |
| `automaticallyShowPopup` | `Boolean` | `true` | Tự hiển thị dialog cảnh báo khi phát hiện mối đe dọa |
| `subscriber` | `CheckSubscriber` | bắt buộc | Callback nhận `RASPExtendedResult` |

**Chế độ tổng quan (`detail = false`):**

Callback được gọi một lần cho mỗi nhóm kiểm tra (Debugger, Root, Tampering, Emulator, DeviceSecurityState, UserCA):

```kotlin
raspChecker.subscribe(
    detail = false,
    automaticallyShowPopup = true,
    subscriber = { result: RASPExtendedResult ->
        if (result.vulnerable) {
            Log.w("CShield", "Threat: ${result.checkType} | Action: ${result.threatAction}")
        }
    }
)
```

**Chế độ chi tiết (`detail = true`):**

Callback được gọi cho từng sub-check (ví dụ: `Magisk`, `SuperSu`, `SysWritable` thay vì chỉ `RootCheckOverview`):

```kotlin
raspChecker.subscribe(
    detail = true,
    automaticallyShowPopup = false, // tự xử lý UI
    subscriber = { result: RASPExtendedResult ->
        Log.d("CShield", "[${result.checkType}] vulnerable=${result.vulnerable}")
    }
)
```

---

### 2.5 Xử lý kết quả RASPExtendedResult

```kotlin
data class RASPExtendedResult(
    val checkType: RASPCheckType,        // loại kiểm tra cụ thể
    val vulnerable: Boolean,             // true = phát hiện mối đe dọa
    val threatAction: ThreatDetectedAction // hành động được cấu hình
)
```

Ví dụ xử lý đầy đủ:

```kotlin
raspChecker.subscribe(detail = true) { result ->
    if (!result.vulnerable) return@subscribe

    when (result.threatAction) {
        ThreatDetectedAction.KillApp -> {
            // SDK tự hiển thị dialog và kill app sau 3.5s
            // (nếu automaticallyShowPopup = true)
        }
        ThreatDetectedAction.NotifyApp -> {
            // Hiển thị cảnh báo tuỳ chỉnh
            showSecurityWarning(result.checkType.toString())
        }
    }
}
```

---

### 2.6 Bảng RASPCheckType

Mỗi `checkType` trong `RASPExtendedResult` là một trong các enum sau:

**Debugger** (`DebuggerCheckType`):

| Giá trị | Mô tả |
|---|---|
| `DebuggerOverviewCheck` | Tổng quan nhóm debugger (dùng khi `detail = false`) |
| `Debuggable` | App có flag `FLAG_DEBUGGABLE` |
| `DebuggerConnected` | Debugger đang kết nối (`Debug.isDebuggerConnected()`) |

**Root** (`RootCheckType`):

| Giá trị | Mô tả |
|---|---|
| `RootCheckOverview` | Tổng quan nhóm root |
| `SuperSu` | Phát hiện binary su tại các đường dẫn phổ biến |
| `Magisk` | Phát hiện Magisk qua `/proc/self/mounts` |
| `SysWritable` | Phân vùng `/system` có thể ghi |
| `HasProperties` | System properties nguy hiểm (`ro.debuggable=1`, `ro.secure=0`) |
| `KernelSUorAPatch` | Phát hiện KernelSU hoặc APatch |

**Emulator** (`EmulatorCheckType`):

| Giá trị | Mô tả |
|---|---|
| `EmulatorOverviewCheck` | Tổng quan nhóm emulator |
| `AvdDevice` / `AvdHardware` | Thiết bị AVD (Android Virtual Device) |
| `Genymotion` / `Nox` / `Memu` / `Bluestacks` | Emulator cụ thể |
| `GoogleEmulator` | Google Emulator chính thức |
| `FingerprintFromEmulator` | Build fingerprint có dấu hiệu emulator |
| `SensorsFromEmulator` | Cảm biến giả (goldfish/qemu/ranchu) |
| `SuspiciousFiles` | File đặc trưng của emulator |
| `SuspiciousPackages` | Package của emulator |
| `SuspiciousQemuProperties` | System properties QEMU |
| `SuspiciousMounts` / `SuspiciousCpu` / `SuspiciousModules` | Mount/CPU/module bất thường |
| `SuspiciousRadioVersion` | Radio version giả |

**Tampering** (`TamperingCheckType`):

| Giá trị | Mô tả |
|---|---|
| `TamperingCheckOverview` | Tổng quan nhóm tampering |
| `InvalidCertificateIntegrity` | Chứng chỉ ký của APK không khớp với giá trị nhúng tại build time |
| `UntrustedStore` | App được cài từ store không nằm trong `trustedStores` |

**Device Security State** (`DeviceSecurityStateCheckType`):

| Giá trị | Mô tả |
|---|---|
| `DeviceSecurityStateCheckOverview` | Tổng quan nhóm trạng thái bảo mật |
| `DeviceUnlocked` | Thiết bị không có PIN/pattern/biometric |
| `HardwareBackedKeystoreUnavailable` | Hardware-backed keystore không khả dụng |
| `DeveloperModeOn` | Developer mode đang bật |
| `AdbEnabled` | ADB đang bật |
| `SystemVpnEnabled` | Đang kết nối VPN |
| `AccessibilityServiceOn` | Có accessibility service đang chạy |

**User CA** (`UserCACheckType`):

| Giá trị | Mô tả |
|---|---|
| `UserCACheckOverview` | Tổng quan nhóm user CA |
| `UserInstalledCA` | Có chứng chỉ CA do người dùng tự cài |
| `InjectedSystemCA` | Có chứng chỉ CA giả được inject vào hệ thống |

---

### 2.7 ThreatDetectedAction

```kotlin
sealed interface ThreatDetectedAction {
    data object KillApp    : ThreatDetectedAction  // hiển thị dialog → kill process sau 3.5s
    data object NotifyApp  : ThreatDetectedAction  // hiển thị dialog → người dùng có thể bỏ qua
}
```

---

## 3. AIP — API Integrity Protection

AIP bảo vệ giao tiếp giữa app và server thông qua hai cơ chế: **Certificate Pinning** và **Request/Response Signing**.

### 3.1 Certificate Pinning — CShieldSSL

Cấu hình SSL pinning trước khi khởi tạo HTTP client. Gọi sau `CShieldSDK.initialize()`, thường trong `Activity.onCreate()` hoặc `Application.onCreate()`:

```kotlin
CShieldSSL.configure(
    pins = listOf(
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",  // primary pin
        "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",  // backup pin
    ),
    hostname = "api.example.com"
)
```

**Cách lấy pin từ certificate:**

```bash
# Từ server trực tiếp
openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl base64
```

**API `CShieldSSL`:**

| Phương thức | Mô tả |
|---|---|
| `configure(pins, hostname)` | Cấu hình pinning lần đầu (hoặc reset toàn bộ) |
| `updatePins(pins, hostname)` | Cập nhật pin mới sau khi server rotate certificate |
| `getSSLSocketFactory()` | Lấy `SSLSocketFactory` đã tích hợp pinning |
| `getTrustManager()` | Lấy `X509TrustManager` tuỳ chỉnh |
| `getSSLContext()` | Lấy `SSLContext` (dùng cho Ktor hoặc client cần SSLContext trực tiếp) |
| `isConfigured()` | Kiểm tra đã cấu hình chưa |

> `getSSLSocketFactory()`, `getTrustManager()`, `getSSLContext()` sẽ throw `IllegalStateException` nếu chưa gọi `configure()`.

**Khuyến nghị:** Cung cấp ít nhất 2 pin (primary + backup) để tránh gián đoạn khi rotate certificate.

---

### 3.2 Request/Response signing — CShieldInterceptor

`CShieldInterceptor` là OkHttp `Interceptor` tự động ký mỗi request và xác thực mỗi response:

```kotlin
val client = OkHttpClient.Builder()
    .sslSocketFactory(
        CShieldSSL.getSSLSocketFactory(),
        CShieldSSL.getTrustManager()
    )
    .addInterceptor(CShieldInterceptor())
    .build()
```

**Interceptor thực hiện tự động:**

- **Ký request:** thêm header `cs-timestamp` và `cs-signature` vào mỗi request
- **Xác thực response:** kiểm tra `cs-timestamp` (cửa sổ 30 giây) và `cs-signature` trong response
- **Chặn Proxy CA:** nếu phát hiện user CA (proxy MITM), throw `CShieldException` và không gửi request

Nếu xác thực thất bại, interceptor throw `CShieldException` (extends `IOException`) — xử lý tại tầng gọi API:

```kotlin
try {
    val response = apiService.submitData(request)
} catch (e: CShieldException) {
    // Xảy ra khi: proxy CA, chữ ký không hợp lệ, timestamp quá hạn
    Log.e("Security", "AIP violation: ${e.message}")
}
```

---

### 3.3 Tích hợp với OkHttp / Retrofit

**Retrofit + OkHttp (khuyến nghị):**

```kotlin
// 1. Cấu hình SSL pinning (trong Activity/Application onCreate)
CShieldSSL.configure(
    pins = listOf("sha256/<your-pin-here>="),
    hostname = "api.example.com"
)

// 2. Xây dựng OkHttpClient với CShield
val okHttpClient = OkHttpClient.Builder()
    .sslSocketFactory(
        CShieldSSL.getSSLSocketFactory(),
        CShieldSSL.getTrustManager()
    )
    .addInterceptor(CShieldInterceptor())
    .build()

// 3. Xây dựng Retrofit
val retrofit = Retrofit.Builder()
    .baseUrl("https://api.example.com")
    .client(okHttpClient)
    .addConverterFactory(GsonConverterFactory.create())
    .build()

val apiService = retrofit.create(ApiService::class.java)
```

**HttpURLConnection:**

```kotlin
val url = URL("https://api.example.com/endpoint")
val conn = url.openConnection() as HttpsURLConnection
conn.sslSocketFactory = CShieldSSL.getSSLSocketFactory()
```

**Ktor (Android):**

```kotlin
val httpClient = HttpClient(Android) {
    engine {
        sslManager = { httpsURLConnection ->
            httpsURLConnection.sslSocketFactory = CShieldSSL.getSSLSocketFactory()
        }
    }
}
```

---

### 3.4 Giao thức ký số (protocol)

**Request — client gửi lên server:**

```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

Payload được ký:
```
{METHOD}.{encoded_path}.{timestamp}.{SHA256(body)}
```

Ví dụ:
```
POST./api/v1/verify-otp.1746700000.e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

**Response — server trả về:**

```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

SDK xác thực:
- `cs-timestamp` phải nằm trong cửa sổ ±30 giây so với giờ hiện tại
- Payload verify: `{status_code}.{encoded_path}.{timestamp}.{SHA256(response_body)}`

**Body normalization:**

- **JSON / text:** sử dụng nguyên văn body string
- **Multipart:** chỉ lấy các text field (bỏ qua file), sắp xếp theo tên field, serialize thành JSON

---

### 3.5 AIPCore — ký thủ công (nâng cao)

Dùng `AIPCore` trực tiếp khi cần ký/xác thực ngoài OkHttp (ví dụ: WebSocket, custom HTTP client):

```kotlin
import com.example.c_shield_sdk.aip.api.AIPCore

// Ký payload
val signature: String = AIPCore.sign(context, payload)

// Xác thực signature
val isValid: Boolean = AIPCore.verifySign(context, payload, signature)

// Chuẩn hoá body request thành chuỗi và tính hash
val bodyResult: BodySigningResult = AIPCore.normalizeBodyForSigning(request)
// bodyResult.normalizedString  — chuỗi đã chuẩn hoá
// bodyResult.sizeInBytes       — kích thước tính bằng byte
// bodyResult.hash              — SHA-256 hex của normalizedString
```

> `AIPCore.sign()` và `AIPCore.verifySign()` sẽ throw `CShieldException` nếu phát hiện Proxy CA được cài đặt.

---

## Tóm tắt luồng tích hợp điển hình

```
Application.onCreate()
  └── CShieldSDK.initialize(context)       // (hoặc tự động qua ContentProvider)

Activity.onCreate()
  └── CShieldSSL.configure(pins, hostname) // cấu hình SSL pinning

Build HTTP client (một lần, dùng Singleton)
  └── OkHttpClient.Builder()
        .sslSocketFactory(CShieldSSL.getSSLSocketFactory(), CShieldSSL.getTrustManager())
        .addInterceptor(CShieldInterceptor())
        .build()

Tại điểm kiểm tra bảo mật (ví dụ: trước khi mở màn hình chính)
  └── RASPChecker.Builder(context, ...).build()
        .setRASPConfig(RASPConfig(...))
        .subscribe(detail = false) { result ->
              if (result.vulnerable) { /* xử lý */ }
        }
```
