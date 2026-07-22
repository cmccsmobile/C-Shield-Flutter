# CShield iOS SDK — Hướng dẫn sử dụng API

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
   - 3.3 [Tích hợp với URLSession / Alamofire](#33-tích-hợp-với-urlsession--alamofire)
   - 3.4 [Giao thức ký số (protocol)](#34-giao-thức-ký-số-protocol)

---

## 1. Khởi tạo SDK

Gọi `CShield.initialize()` sớm nhất có thể — trong `App.init()` (SwiftUI) hoặc `application(_:didFinishLaunchingWithOptions:)` (UIKit):

```swift
// SwiftUI
@main
struct MyApp: App {
    init() {
        CShield.initialize()
    }
    var body: some Scene { WindowGroup { ContentView() } }
}

// UIKit
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [...]?) -> Bool {
    CShield.initialize()
    return true
}
```

- **Không có return value, không throw.** Nếu phát hiện mối đe dọa lúc khởi động (hooking, jailbreak, tampering, frida), SDK tự hiển thị popup và exit app sau 3 giây.
- Sau khi khởi tạo, **watchdog thread** chạy nền mỗi 20-30 giây — phát hiện mối đe dọa mới sẽ terminate process tự động.
- Chỉ gọi một lần trong vòng đời app.

---

## 2. RASP — Runtime Application Self-Protection

### 2.1 Xây dựng RASPChecker

```swift
let checker = RASPChecker.Builder(
    checkDebugger:       true,  // phát hiện debugger đang attach
    simulator:           true,  // phát hiện đang chạy trên Simulator
    deviceSecurityState: true,  // phát hiện trạng thái bảo mật thiết bị không an toàn
    userCA:              true   // phát hiện user-installed CA / proxy CA
).build()
```

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `checkDebugger` | `Bool` | `true` | Bật kiểm tra debugger |
| `simulator` | `Bool` | `true` | Bật kiểm tra simulator |
| `deviceSecurityState` | `Bool` | `true` | Bật kiểm tra trạng thái bảo mật thiết bị |
| `userCA` | `Bool` | `true` | Bật kiểm tra user-installed / proxy CA |

---

### 2.2 Cấu hình RASPConfig

Sau khi build, cấu hình hành động cho từng loại threat:

```swift
checker.setRASPConfig(
    RASPConfig(
        threatActionConfig: ThreatActionConfig(
            debuggerDetectedAction:                  .killApp,
            simulatorDetectedAction:                 .notifyApp,
            deviceSecurityStateUnsafeDetectedAction: .notifyApp,
            userCADetectedAction:                    .killApp
        )
    )
)
```

**`ThreatActionConfig`** — tất cả trường đều mặc định `.notifyApp`:

| Trường | Mô tả |
|---|---|
| `debuggerDetectedAction` | Hành động khi phát hiện debugger |
| `simulatorDetectedAction` | Hành động khi phát hiện simulator |
| `deviceSecurityStateUnsafeDetectedAction` | Hành động khi trạng thái bảo mật không an toàn |
| `userCADetectedAction` | Hành động khi phát hiện user CA / proxy CA |

---

### 2.3 quickCheck — kiểm tra nhanh

Trả về mối đe dọa nghiêm trọng nhất tìm thấy (theo thứ tự ưu tiên: debugger > simulator > deviceSecurityState > userCA):

```swift
let result = checker.quickCheck()

switch result {
case .secure:                    break  // thiết bị an toàn
case .debuggerFound:             break  // debugger đang attach
case .simulatorFound:            break  // đang chạy trên Simulator
case .deviceSecurityStateUnsafe: break  // trạng thái bảo mật không an toàn
case .userCADetected:            break  // phát hiện user CA / proxy CA
}
```

> `quickCheck()` trả về mối đe dọa đầu tiên, không liệt kê tất cả. Dùng `subscribe()` nếu cần đầy đủ.

---

### 2.4 subscribe — kiểm tra chi tiết

Chạy tất cả checks và gọi callback cho từng kết quả:

```swift
checker.subscribe(automaticallyShowPopup: true) { result in
    if result.vulnerable {
        print("Threat: \(result.checkType.displayName) | Action: \(result.threatAction)")
    }
}
```

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `automaticallyShowPopup` | `Bool` | `true` | Tự hiển thị dialog cảnh báo tổng hợp sau khi chạy xong tất cả checks |
| `subscriber` | `CheckSubscriber` | bắt buộc | Callback nhận từng `RASPExtendedResult` |

Đặt `automaticallyShowPopup: false` để tự xử lý UI:

```swift
checker.subscribe(automaticallyShowPopup: false) { result in
    guard result.vulnerable else { return }
    // Tự hiển thị cảnh báo theo thiết kế của app
    showSecurityAlert(for: result.checkType)
}
```

---

### 2.5 Xử lý kết quả RASPExtendedResult

```swift
public struct RASPExtendedResult {
    public let checkType:    RASPCheckType        // loại check
    public let vulnerable:   Bool                 // true = phát hiện mối đe dọa
    public let threatAction: ThreatDetectedAction // hành động đã cấu hình
}
```

Ví dụ xử lý:

```swift
checker.subscribe { result in
    guard result.vulnerable else { return }

    switch result.threatAction {
    case .killApp:
        // SDK tự hiển thị dialog và kill app (nếu automaticallyShowPopup = true)
        break
    case .notifyApp:
        // Tự hiển thị cảnh báo
        showWarning("Phát hiện: \(result.checkType.displayName)")
    }
}
```

---

### 2.6 Bảng RASPCheckType

| Giá trị | Mô tả |
|---|---|
| `.debuggerCheck` | Kiểm tra debugger đang attach (ptrace / exception port) |
| `.simulatorCheck` | Kiểm tra đang chạy trên iOS Simulator |
| `.deviceSecurityStateCheck` | Kiểm tra trạng thái bảo mật thiết bị (xem bên dưới) |
| `.userCACheck` | Kiểm tra user CA / proxy CA (xem bên dưới) |

**Các điều kiện của `.deviceSecurityStateCheck`** (bất kỳ `true` = vulnerable):

| Điều kiện | Mô tả |
|---|---|
| Device Not Locked | Không thiết lập PIN / mật khẩu màn hình khóa |
| Hardware KeyStore Unavailable | Không hỗ trợ Face ID / Touch ID |
| Dev Mode On | Bật Developer Mode, có `get-task-allow` entitlement, hoặc có lockdown pair records |
| System VPN Enabled | Đang kết nối VPN (interface `utun`, `ipsec`, `ppp`) |

**Các điều kiện của `.userCACheck`** (bất kỳ `true` = vulnerable):

| Điều kiện | Mô tả |
|---|---|
| User CA Installed | Có CA certificate cài thủ công qua profile / MDM |
| Proxy CA Installed | Phát hiện CA thường dùng bởi Burp Suite, Charles Proxy |

---

### 2.7 ThreatDetectedAction

```swift
public enum ThreatDetectedAction {
    case killApp    // hiển thị dialog "Nguy hiểm" → auto-exit sau 3 giây
    case notifyApp  // hiển thị dialog "Cảnh báo" → user có thể dismiss
}
```

---

## 3. AIP — API Integrity Protection

### 3.1 Certificate Pinning — CShieldSSL

Cấu hình SSL pinning trước khi thực hiện bất kỳ network request nào. Gọi ngay sau `CShield.initialize()`:

```swift
CShieldSSL.configure(
    pins: [
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",  // primary pin
        "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="   // backup pin
    ],
    hostname: "api.example.com"
)
```

**Cách lấy pin từ certificate:**

```bash
# Từ server trực tiếp
openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

Kết quả là raw base64. Thêm `sha256/` ở đầu để có format đúng.

**API `CShieldSSL`:**

| Phương thức | Mô tả |
|---|---|
| `configure(pins:hostname:)` | Cấu hình pinning lần đầu (hoặc reset toàn bộ) |
| `updatePins(pins:hostname:)` | Cập nhật pin mới sau khi server rotate certificate |
| `urlSession(configuration:)` | Lấy `URLSession` đã tích hợp pinning |
| `trustManager()` | Lấy `CShieldTrustManager` (dùng khi cần gán delegate thủ công) |
| `isConfigured()` | Kiểm tra đã cấu hình chưa |

> `urlSession()` và `trustManager()` sẽ `fatalError` nếu chưa gọi `configure()`.

> **Khuyến nghị:** Cung cấp ít nhất 2 pin (primary + backup) để tránh lockout khi rotate certificate.

---

### 3.2 Request/Response signing — CShieldInterceptor

`CShieldInterceptor` ký mỗi request và xác thực mỗi response:

```swift
let interceptor = CShieldInterceptor()
```

#### `intercept(request:)` — ký request

```swift
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = jsonData

try interceptor.intercept(request: &request)
// Thêm vào request: cs-timestamp, cs-signature
```

#### `interceptResponse(response:data:)` — xác thực response

```swift
let (data, response) = try await session.data(for: request)
let validatedData = try interceptor.interceptResponse(response: response, data: data)
// Nếu không throw → response hợp lệ
```

**Các lỗi có thể throw:**

| Error | Mô tả |
|---|---|
| `CShieldError.aipMissingHeader` | Thiếu `cs-timestamp` hoặc `cs-signature` trong response |
| `CShieldError.aipTimestampExpired` | Timestamp vượt quá cửa sổ 30 giây |
| `CShieldError.aipInvalidSignature` | Chữ ký response không hợp lệ |
| `CShieldError.aipSigningFailed` | Lỗi ký request (private key chưa load) |
| `CShieldError.aipDetectProxyCA` | Phát hiện proxy CA — từ chối xử lý |

> `aipDetectProxyCA` được throw trên cả `intercept()` lẫn `interceptResponse()`. Không bắt và bỏ qua lỗi này.

---

### 3.3 Tích hợp với URLSession / Alamofire

**URLSession trực tiếp (khuyến nghị):**

```swift
// Khởi tạo một lần, dùng lại nhiều lần
final class APIClient {
    static let shared = APIClient()

    private let interceptor = CShieldInterceptor()
    private let session = CShieldSSL.urlSession()  // URLSession có SSL pinning
    private let baseURL = "https://api.example.com"

    func post<Body: Encodable, Response: Decodable>(
        path: String, body: Body
    ) async throws -> Response {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        try interceptor.intercept(request: &request)
        let (data, response) = try await session.data(for: request)
        let validated = try interceptor.interceptResponse(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: validated)
    }
}
```

**Alamofire (RequestInterceptor):**

```swift
import Alamofire

class CShieldRequestAdapter: RequestInterceptor {
    private let interceptor = CShieldInterceptor()

    func adapt(_ urlRequest: URLRequest,
               for session: Session,
               completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        do {
            try interceptor.intercept(request: &request)
            completion(.success(request))
        } catch {
            completion(.failure(error))
        }
    }
}

let session = Session(
    delegate: SessionDelegate(),
    serverTrustManager: nil,   // hoặc tích hợp CShieldTrustManager nếu cần
    interceptor: CShieldRequestAdapter()
)
```

**Xử lý lỗi:**

```swift
do {
    let data = try interceptor.interceptResponse(response: response, data: data)
} catch CShieldError.aipMissingHeader(let msg) {
    // Server chưa tích hợp CShield backend
} catch CShieldError.aipTimestampExpired(let msg) {
    // Có thể bị replay attack hoặc đồng hồ lệch
} catch CShieldError.aipInvalidSignature(let msg) {
    // Response bị tampering
} catch CShieldError.aipDetectProxyCA(let msg) {
    // Proxy CA đang active — không xử lý tiếp
} catch {
    // Lỗi khác
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
{METHOD}.{url_path}.{timestamp}.{SHA256(body)}
```

Ví dụ:
```
POST./api/v1/verify-otp.1746700000.e3b0c44298fc1c149afb...
```

**Response — server trả về:**

```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

SDK xác thực:
- `cs-timestamp` phải nằm trong cửa sổ ±30 giây so với giờ hiện tại
- Payload verify: `{status_code}.{url_path}.{timestamp}.{SHA256(response_body)}`

**Body normalization:**

| Content-Type | Cách xử lý |
|---|---|
| `application/json` / text | Dùng nguyên văn body bytes |
| `multipart/form-data` | Chỉ lấy các text field (bỏ qua file parts), sắp xếp theo tên field, serialize thành JSON |

---

## Tóm tắt luồng tích hợp điển hình

```
App.init() / application(_:didFinishLaunchingWithOptions:)
  └── CShield.initialize()                          // RASP + AIP watchdog
  └── CShieldSSL.configure(pins:hostname:)          // SSL pinning

Build HTTP client (singleton — khởi tạo một lần)
  └── session     = CShieldSSL.urlSession()         // URLSession có pinning
  └── interceptor = CShieldInterceptor()            // AIP sign + verify

Tại điểm kiểm tra bảo mật (trước khi mở màn hình chính)
  └── RASPChecker.Builder(...).build()
        .setRASPConfig(RASPConfig(...))
        .subscribe { result in
            if result.vulnerable { /* xử lý */ }
        }

Mỗi API call
  └── interceptor.intercept(request: &request)      // ký request
  └── session.data(for: request)                    // gửi qua SSL pinned session
  └── interceptor.interceptResponse(response:data:) // xác thực response
```
