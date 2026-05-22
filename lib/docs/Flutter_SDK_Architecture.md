# CShield Flutter SDK — Tài liệu kiến trúc & kế hoạch triển khai

> Tài liệu này mô tả **kiến trúc tổng thể** của plugin Flutter `c_shield_sdk` — nhằm wrap hai SDK native có sẵn (Android AAR và iOS XCFramework) và phơi ra một **API thống nhất, idiomatic** cho Flutter developer. Phạm vi: từ public Dart API → method/event channel → native bridge → SDK gốc.

---

## Mục lục

1. [Bối cảnh & mục tiêu](#1-bối-cảnh--mục-tiêu)
2. [Kiến trúc tổng thể (sơ đồ phân lớp)](#2-kiến-trúc-tổng-thể-sơ-đồ-phân-lớp)
3. [Cấu trúc thư mục](#3-cấu-trúc-thư-mục)
4. [Public Dart API — exported](#4-public-dart-api--exported)
5. [Internal Dart API — không exported](#5-internal-dart-api--không-exported)
6. [Method Channel & Event Channel — giao thức cầu nối](#6-method-channel--event-channel--giao-thức-cầu-nối)
7. [Native bridge Android](#7-native-bridge-android)
8. [Native bridge iOS](#8-native-bridge-ios)
9. [Cách xử lý khác biệt giữa hai nền tảng](#9-cách-xử-lý-khác-biệt-giữa-hai-nền-tảng)
10. [Cách tiếp cận tầng HTTP (SSL pinning + AIP signing)](#10-cách-tiếp-cận-tầng-http-ssl-pinning--aip-signing)
11. [Xử lý vòng đời & threading](#11-xử-lý-vòng-đời--threading)
12. [Lỗi & exception mapping](#12-lỗi--exception-mapping)
13. [Kế hoạch triển khai theo phase](#13-kế-hoạch-triển-khai-theo-phase)
14. [Trạng thái hiện tại & việc cần làm ngay](#14-trạng-thái-hiện-tại--việc-cần-làm-ngay)

---

## 1. Bối cảnh & mục tiêu

- **Native SDK** đã được phát triển độc lập:
  - Android: `c-shield-sdk` (Kotlin) — publish dưới dạng Maven artifact vào `android/local-repo/` (xem [§7.3](#73-build-config)).
  - iOS: `CShieldSDK.xcframework` (Swift) — **chưa có file**, sẽ tích hợp khi nhận được.
- **Phạm vi tính năng** (đầy đủ ở `lib/docs/Android_API_Usage.md` và `lib/docs/IOS_API_Usage.md`):
  - **RASP** — kiểm tra debugger, root/jailbreak, tampering, emulator/simulator, device security state, user CA.
  - **AIP** — SSL pinning (`CShieldSSL`) và request/response signing (`CShieldInterceptor`).
- **Mục tiêu của plugin Flutter**:
  - API Dart đơn giản, type-safe, gần với API native nhưng **idiomatic với Flutter** (Future / Stream / Sealed-class).
  - **Không yêu cầu developer chạm vào code native** — chỉ cần `pubspec.yaml: c_shield_sdk: ^x.y.z` và gọi từ Dart.
  - Hỗ trợ cả `package:http` và `package:dio` cho phần mạng (AIP).
  - **Hai nền tảng phơi ra cùng một bề mặt API** — chỉ những kiểm tra không tồn tại trên một nền tảng mới bị no-op (xem [§9](#9-cách-xử-lý-khác-biệt-giữa-hai-nền-tảng)).

**Nguyên tắc thiết kế:**
- *Convention over configuration* — tham số mặc định khớp với SDK native.
- *Fail loud* — lỗi native được map sang `CShieldException` có code rõ ràng, không nuốt lỗi.
- *Zero-cost abstraction* — không thêm logic Dart vào hot path mạng; sign/verify/pinning đều ở native.

---

## 2. Kiến trúc tổng thể (sơ đồ phân lớp)

```
┌──────────────────────────────────────────────────────────────────────┐
│  Tầng 1 — Public Dart API   (lib/c_shield_sdk.dart — export tổng)    │
│  ──────────────────────────────────────────────────────────────────  │
│  • CShieldSdk.initialize()                                           │
│  • RASPChecker / RASPConfig / ThreatActionConfig                     │
│  • RASPResult / RASPExtendedResult / RASPCheckType                   │
│  • ThreatDetectedAction                                              │
│  • CShieldSSL.configure / updatePins / isConfigured                  │
│  • CShieldHttpClient (http.BaseClient)                               │
│  • CShieldDioInterceptor (tuỳ chọn — nếu dùng dio)                   │
│  • CShieldException + các error code                                 │
└──────────────────────────────┬───────────────────────────────────────┘
                               │  chỉ phụ thuộc Tầng 2
┌──────────────────────────────▼───────────────────────────────────────┐
│  Tầng 2 — Platform Interface  (internal — KHÔNG export)              │
│  ──────────────────────────────────────────────────────────────────  │
│  • CShieldSdkPlatform (abstract, plugin_platform_interface)          │
│  • MethodChannelCShieldSdk (implementation mặc định)                 │
│  • CodecRegistry — encode/decode enum & DTO                          │
│  • EventChannelRegistry — quản lý subscription cho RASP & HTTP body  │
└──────────────────────────────┬───────────────────────────────────────┘
                               │  MethodChannel: "c_shield_sdk"
                               │  EventChannel:  "c_shield_sdk/rasp_events"
                               │  EventChannel:  "c_shield_sdk/http_stream" (optional)
┌──────────────────────────────▼───────────────────────────────────────┐
│  Tầng 3 — Native plugin                                              │
│  ──────────────────────────────────────────────────────────────────  │
│  Android (Kotlin)               │  iOS (Swift)                       │
│  android/src/main/kotlin/...    │  ios/Classes/...                   │
│  • CShieldSdkPlugin             │  • CShieldSdkPlugin                │
│  • RaspBridge                   │  • RaspBridge                      │
│  • SslBridge                    │  • SslBridge                       │
│  • AipBridge (signRequest,      │  • AipBridge (intercept,           │
│    verifyResponse, normalize)   │    interceptResponse)              │
│  • HttpBridge (OkHttp client    │  • HttpBridge (URLSession của      │
│    có pinning + interceptor)    │    CShieldSSL)                     │
│  • RaspEventStreamHandler       │  • RaspEventStreamHandler          │
└──────────────────────────────┬───────────────────────────────────────┘
                               │  gọi trực tiếp API của SDK gốc
┌──────────────────────────────▼───────────────────────────────────────┐
│  Tầng 4 — SDK native gốc (binary)                                    │
│  ──────────────────────────────────────────────────────────────────  │
│  Android: android/local-repo/                                        │
│           com.example.c_shield_sdk:c-shield-sdk:<version>           │
│           (Maven local repo — generate từ CShieldSampleApp)          │
│  iOS:     ios/Frameworks/CShieldSDK.xcframework  (cần bổ sung)       │
└──────────────────────────────────────────────────────────────────────┘
```

**Tầng nào có thể thay thế được?**

- Tầng 1 — public, **commit API** theo semver.
- Tầng 2 — internal, có thể đổi đường dây mà không phá public.
- Tầng 3–4 — chỉ thay khi nâng cấp SDK gốc.

---

## 3. Cấu trúc thư mục

```
c_shield_sdk/
├── pubspec.yaml
├── lib/
│   ├── c_shield_sdk.dart                 ← entrypoint, EXPORT tổng
│   ├── docs/
│   │   ├── Android_API_Usage.md
│   │   ├── IOS_API_Usage.md
│   │   └── Flutter_SDK_Architecture.md   ← (tài liệu này)
│   └── src/                              ← code Dart thực sự (không trực tiếp export)
│       ├── api/                          ← các class public (re-export từ c_shield_sdk.dart)
│       │   ├── c_shield_sdk.dart         ← class CShieldSdk
│       │   ├── rasp/
│       │   │   ├── rasp_checker.dart
│       │   │   ├── rasp_config.dart
│       │   │   ├── rasp_result.dart
│       │   │   ├── rasp_check_type.dart
│       │   │   ├── rasp_extended_result.dart
│       │   │   └── threat_action.dart
│       │   ├── ssl/
│       │   │   └── c_shield_ssl.dart
│       │   ├── http/
│       │   │   ├── c_shield_http_client.dart
│       │   │   └── c_shield_dio_interceptor.dart  ← chỉ build nếu user thêm dio
│       │   └── exceptions/
│       │       └── c_shield_exception.dart
│       └── internal/                     ← KHÔNG được export ra ngoài
│           ├── platform/
│           │   ├── c_shield_sdk_platform_interface.dart
│           │   └── c_shield_sdk_method_channel.dart
│           ├── codec/
│           │   ├── rasp_codec.dart       ← enum ↔ string
│           │   └── error_codec.dart      ← PlatformException → CShieldException
│           ├── channels.dart             ← hằng số tên channel & method
│           └── rasp_event_bus.dart       ← gói EventChannel cho RASP
├── android/
│   ├── build.gradle                      ← gradle.allprojects inject local-repo cho mọi consumer
│   ├── local-repo/                       ← Maven local repo (generated — không commit vào git)
│   │   └── com/example/c_shield_sdk/
│   │       └── c-shield-sdk/<version>/
│   │           ├── c-shield-sdk-<version>.aar
│   │           └── (pom, module, checksums...)
│   └── src/main/kotlin/com/cmc/c_shield_sdk/
│       ├── CShieldSdkPlugin.kt           ← entrypoint plugin
│       ├── bridges/
│       │   ├── RaspBridge.kt
│       │   ├── SslBridge.kt
│       │   ├── AipBridge.kt
│       │   └── HttpBridge.kt
│       └── streams/
│           └── RaspEventStreamHandler.kt
├── ios/
│   ├── c_shield_sdk.podspec              ← cần thêm vendored framework
│   ├── Frameworks/
│   │   └── CShieldSDK.xcframework        ← (CẦN BỔ SUNG)
│   └── Classes/
│       ├── CShieldSdkPlugin.swift        ← entrypoint plugin
│       ├── Bridges/
│       │   ├── RaspBridge.swift
│       │   ├── SslBridge.swift
│       │   ├── AipBridge.swift
│       │   └── HttpBridge.swift
│       └── Streams/
│           └── RaspEventStreamHandler.swift
└── example/                              ← app mẫu để test
```

**Quy ước export:**
- File `lib/c_shield_sdk.dart` chỉ `export 'src/api/...'`.
- Tuyệt đối **không export** bất kỳ thứ gì trong `lib/src/internal/`. Dùng `// ignore_for_file: implementation_imports` cho test nội bộ.
- Dùng tiền tố `@internal` (`package:meta`) cho class trong `src/internal` để tooling cảnh báo nếu rò ra.

---

## 4. Public Dart API — exported

Đây là toàn bộ những gì developer thấy khi `import 'package:c_shield_sdk/c_shield_sdk.dart';`.

### 4.1 `CShieldSdk` — khởi tạo

```dart
class CShieldSdk {
  /// Khởi tạo SDK (idempotent — lần gọi thứ 2 trở đi sẽ bị bỏ qua).
  ///
  /// - Android: gọi CShieldSDK.initialize() — chỉ cần khi muốn override ContentProvider auto-init.
  /// - iOS: gọi CShield.initialize() — BẮT BUỘC, vì watchdog thread bắt đầu chạy ở đây.
  ///
  /// Nên gọi sớm nhất có thể trong `main()` trước `runApp()`.
  static Future<void> initialize();
}
```

### 4.2 RASP API

```dart
class RASPChecker {
  /// Builder — flags mặc định khớp với SDK native (mọi check đều ON).
  /// Trên iOS, các flag không tồn tại (rootDetector, tampering, emulator) sẽ
  /// bị bỏ qua silently — không throw.
  factory RASPChecker.builder({
    bool checkDebugger       = true,
    bool rootDetector        = true,   // Android-only
    bool tampering           = true,   // Android-only
    bool emulator            = true,   // Android → emulator, iOS → simulator (auto-map)
    bool deviceSecurityState = true,
    bool userCA              = true,   // iOS-only ở đây — Android có riêng trong action config
  });

  /// Cấu hình hành động khi phát hiện threat. Có thể gọi nhiều lần.
  Future<void> setRASPConfig(RASPConfig config);

  /// Kiểm tra nhanh — trả về threat đầu tiên hoặc Secure.
  Future<RASPResult> quickCheck();

  /// Subscribe — phát ra một stream các RASPExtendedResult, mỗi result cho 1 check.
  ///
  /// [detail]: true = từng sub-check (chỉ Android có ý nghĩa; iOS sẽ ignore).
  /// [automaticallyShowPopup]: SDK native tự hiển thị dialog cảnh báo.
  ///
  /// Stream tự động đóng sau khi tất cả check chạy xong. Caller cần listen
  /// trước khi async gap kết thúc, hoặc dùng `.toList()`.
  Stream<RASPExtendedResult> subscribe({
    bool detail = false,
    bool automaticallyShowPopup = true,
  });

  /// Giải phóng tài nguyên native. Gọi khi instance không còn dùng.
  Future<void> dispose();
}

class RASPConfig {
  final List<String>? trustedStores;    // Android-only — iOS bỏ qua
  final ThreatActionConfig? threatActionConfig;
  const RASPConfig({this.trustedStores, this.threatActionConfig});
}

class ThreatActionConfig {
  /// Mọi trường mặc định = ThreatDetectedAction.notifyApp (khớp native).
  /// Các trường không có ý nghĩa trên một nền tảng sẽ bị silently ignored.
  final ThreatDetectedAction debuggerDetectedAction;
  final ThreatDetectedAction rootDetectedAction;                   // Android
  final ThreatDetectedAction tamperingDetectedAction;              // Android
  final ThreatDetectedAction emulatorDetectedAction;               // Android
  final ThreatDetectedAction simulatorDetectedAction;              // iOS
  final ThreatDetectedAction deviceSecurityStateUnsafeDetectedAction;
  final ThreatDetectedAction userCADetectedAction;

  const ThreatActionConfig({
    this.debuggerDetectedAction = ThreatDetectedAction.notifyApp,
    this.rootDetectedAction = ThreatDetectedAction.notifyApp,
    this.tamperingDetectedAction = ThreatDetectedAction.notifyApp,
    this.emulatorDetectedAction = ThreatDetectedAction.notifyApp,
    this.simulatorDetectedAction = ThreatDetectedAction.notifyApp,
    this.deviceSecurityStateUnsafeDetectedAction = ThreatDetectedAction.notifyApp,
    this.userCADetectedAction = ThreatDetectedAction.notifyApp,
  });
}

enum ThreatDetectedAction { killApp, notifyApp }

/// Kết quả tổng quan của quickCheck.
enum RASPResult {
  secure,
  debuggerFound,
  deviceRooted,              // Android-only
  deviceTampered,            // Android-only
  emulatorFound,             // Android
  simulatorFound,            // iOS
  deviceSecurityStateUnsafe,
  userCADetected,
}

/// Kết quả chi tiết của subscribe.
class RASPExtendedResult {
  final RASPCheckType checkType;
  final bool vulnerable;
  final ThreatDetectedAction threatAction;
  const RASPExtendedResult({
    required this.checkType,
    required this.vulnerable,
    required this.threatAction,
  });
}

/// Loại check — sealed class để type-safe, có overview + sub-check chi tiết
/// (chi tiết chỉ phát ra trên Android khi `detail=true`).
sealed class RASPCheckType {
  // Debugger
  factory RASPCheckType.debuggerOverview() = _DebuggerOverview;
  factory RASPCheckType.debuggable() = _Debuggable;
  factory RASPCheckType.debuggerConnected() = _DebuggerConnected;

  // Root  (Android)
  factory RASPCheckType.rootOverview() = _RootOverview;
  factory RASPCheckType.superSu() = _SuperSu;
  factory RASPCheckType.magisk() = _Magisk;
  // ... (xem bảng đầy đủ trong Android_API_Usage.md §2.6)

  // Simulator / Emulator
  factory RASPCheckType.emulatorOverview() = _EmulatorOverview;
  factory RASPCheckType.simulatorCheck() = _SimulatorCheck;
  // ... các Genymotion / Nox / Memu / Bluestacks / AVD / ...

  // Tampering (Android)
  factory RASPCheckType.tamperingOverview() = _TamperingOverview;
  factory RASPCheckType.invalidCertificateIntegrity() = _InvalidCertificate;
  factory RASPCheckType.untrustedStore() = _UntrustedStore;

  // Device security state
  factory RASPCheckType.deviceSecurityStateOverview() = _DeviceSecurityOverview;
  factory RASPCheckType.deviceUnlocked() = _DeviceUnlocked;
  factory RASPCheckType.hardwareKeystoreUnavailable() = _HardwareKeystoreUnavailable;
  factory RASPCheckType.developerModeOn() = _DeveloperModeOn;
  factory RASPCheckType.adbEnabled() = _AdbEnabled;            // Android
  factory RASPCheckType.systemVpnEnabled() = _SystemVpnEnabled;
  factory RASPCheckType.accessibilityServiceOn() = _AccessibilityServiceOn; // Android

  // User CA
  factory RASPCheckType.userCAOverview() = _UserCAOverview;
  factory RASPCheckType.userInstalledCA() = _UserInstalledCA;
  factory RASPCheckType.proxyCA() = _ProxyCA;                  // iOS-explicit
  factory RASPCheckType.injectedSystemCA() = _InjectedSystemCA; // Android

  /// Trả về dạng string display-friendly. Native cũng trả về key này.
  String get key;
}
```

### 4.3 SSL Pinning API

```dart
class CShieldSSL {
  /// Cấu hình SSL pinning lần đầu (hoặc reset toàn bộ).
  /// [pins] phải có dạng "sha256/<base64>".
  static Future<void> configure({
    required List<String> pins,
    required String hostname,
  });

  /// Cập nhật pin mới (dùng sau khi server rotate certificate).
  static Future<void> updatePins({
    required List<String> pins,
    required String hostname,
  });

  /// Trả về true nếu đã configure thành công.
  static Future<bool> isConfigured();
}
```

### 4.4 HTTP API (AIP)

```dart
/// Drop-in replacement cho http.Client.
/// MỌI request đi qua client này sẽ:
///   1. Được ký bởi CShieldInterceptor (cs-timestamp, cs-signature)
///   2. Đi qua SSL-pinned channel của CShieldSSL
///   3. Response được verify trước khi trả về Dart
/// Throw CShieldException nếu phát hiện proxy CA / chữ ký sai / timestamp lệch.
class CShieldHttpClient extends http.BaseClient {
  CShieldHttpClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request);

  @override
  void close();
}

/// (Tuỳ chọn) Interceptor cho dio — chỉ build nếu app thêm dio.
/// Dùng InterceptorsWrapper, không cần import package:dio cứng từ plugin.
class CShieldDioInterceptor {
  // Khai báo dưới dạng dynamic + adapter pattern để tránh phụ thuộc dio.
  // Xem §10.3.
}
```

### 4.5 Exceptions

```dart
class CShieldException implements Exception {
  final CShieldErrorCode code;
  final String message;
  final Object? nativeCause;   // PlatformException gốc nếu có
  const CShieldException(this.code, this.message, [this.nativeCause]);
}

enum CShieldErrorCode {
  // AIP
  aipMissingHeader,
  aipTimestampExpired,
  aipInvalidSignature,
  aipSigningFailed,
  aipDetectProxyCA,

  // SSL
  sslNotConfigured,
  sslPinMismatch,

  // RASP
  raspCheckerDisposed,

  // Generic
  notInitialized,
  invalidArgument,
  nativeError,
}
```

---

## 5. Internal Dart API — không exported

Những class sau **không** được re-export trong `lib/c_shield_sdk.dart`:

| File | Mục đích |
|---|---|
| `src/internal/platform/c_shield_sdk_platform_interface.dart` | `PlatformInterface` abstract — chỉ test dùng |
| `src/internal/platform/c_shield_sdk_method_channel.dart` | Implementation MethodChannel |
| `src/internal/codec/rasp_codec.dart` | Map giữa enum Dart ↔ string key gửi qua channel |
| `src/internal/codec/error_codec.dart` | Map `PlatformException.code` → `CShieldErrorCode` |
| `src/internal/channels.dart` | Hằng số tên method/channel (single source of truth) |
| `src/internal/rasp_event_bus.dart` | Bọc `EventChannel`, demultiplex theo `subscriptionId` |

**Lý do tách:**
- `PlatformInterface` cần được public cho mục đích **test/mock** trong plugin con (nếu sau này tách ra `c_shield_sdk_android` / `c_shield_sdk_ios` như Flutter chuẩn) — nhưng với one-package layout này chúng ta giữ private và mock qua `MethodChannel.setMockMethodCallHandler`.

---

## 6. Method Channel & Event Channel — giao thức cầu nối

### 6.1 Method Channel: `c_shield_sdk`

Tất cả request → response 1-1 đi qua channel này. Method name dùng dot-notation theo namespace:

| Method | Arguments | Return | Throws |
|---|---|---|---|
| `sdk.initialize` | — | `null` | — |
| `rasp.build` | `{flags: Map<String,bool>}` | `String` checkerId | — |
| `rasp.setConfig` | `{checkerId, config: Map}` | `null` | invalidArgument |
| `rasp.quickCheck` | `{checkerId}` | `String` (key của RASPResult) | raspCheckerDisposed |
| `rasp.subscribe` | `{checkerId, detail, automaticallyShowPopup}` | `String` subscriptionId | — |
| `rasp.cancelSubscribe` | `{subscriptionId}` | `null` | — |
| `rasp.dispose` | `{checkerId}` | `null` | — |
| `ssl.configure` | `{pins: List<String>, hostname: String}` | `null` | invalidArgument |
| `ssl.updatePins` | `{pins, hostname}` | `null` | sslNotConfigured |
| `ssl.isConfigured` | — | `bool` | — |
| `aip.signRequest` | `{method, path, headers, body: Uint8List, contentType}` | `Map<String,String>` (cs-timestamp, cs-signature) | aipSigningFailed, aipDetectProxyCA |
| `aip.verifyResponse` | `{statusCode, path, headers, body: Uint8List}` | `null` | aipMissingHeader, aipTimestampExpired, aipInvalidSignature, aipDetectProxyCA |
| `aip.normalizeBody` | `{contentType, body: Uint8List, multipartFields?}` | `{normalizedString, sizeInBytes, hash}` | — |
| `http.request` | `{method, url, headers, body: Uint8List}` | `{statusCode, headers: Map, body: Uint8List}` | aipDetectProxyCA, sslPinMismatch, network errors |

**Lý do tách `http.request`** ra một method riêng: xem [§10.1](#101-vấn-đề-cốt-lõi-không-thể-inject-pinning-vào-dart-httpclient).

### 6.2 Event Channel: `c_shield_sdk/rasp_events`

Phát kết quả streaming của `rasp.subscribe()`. Một channel duy nhất, demultiplex bằng `subscriptionId` trong payload.

**Payload event:**
```json
{
  "subscriptionId": "uuid-...",
  "type": "result" | "complete" | "error",
  "data": {
    "checkType": "Magisk",
    "vulnerable": true,
    "threatAction": "killApp"
  }
}
```

- `type = "result"` — một `RASPExtendedResult`.
- `type = "complete"` — không có data, đóng stream.
- `type = "error"` — kèm `code` + `message`.

---

## 7. Native bridge Android

### 7.1 Cấu trúc

```kotlin
// android/src/main/kotlin/com/cmc/c_shield_sdk/CShieldSdkPlugin.kt
class CShieldSdkPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var raspEventChannel: EventChannel
  private lateinit var context: Context

  private lateinit var raspBridge: RaspBridge
  private lateinit var sslBridge: SslBridge
  private lateinit var aipBridge: AipBridge
  private lateinit var httpBridge: HttpBridge

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "c_shield_sdk")
    raspEventChannel = EventChannel(binding.binaryMessenger, "c_shield_sdk/rasp_events")

    raspBridge = RaspBridge(context)
    sslBridge = SslBridge()
    aipBridge = AipBridge(context)
    httpBridge = HttpBridge()  // dùng OkHttpClient với CShieldSSL + CShieldInterceptor

    channel.setMethodCallHandler(this)
    raspEventChannel.setStreamHandler(raspBridge.streamHandler)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when {
      call.method == "sdk.initialize"        -> { CShieldSDK.initialize(context); result.success(null) }
      call.method.startsWith("rasp.")        -> raspBridge.handle(call, result)
      call.method.startsWith("ssl.")         -> sslBridge.handle(call, result)
      call.method.startsWith("aip.")         -> aipBridge.handle(call, result)
      call.method.startsWith("http.")        -> httpBridge.handle(call, result)
      else                                   -> result.notImplemented()
    }
  }
}
```

### 7.2 Mapping public API → SDK gốc

| Method Flutter | Gọi vào SDK gốc (giả sử package `com.example.c_shield_sdk`) |
|---|---|
| `sdk.initialize` | `CShieldSDK.initialize(context)` |
| `rasp.build` | `RASPChecker.Builder(context, checkDebugger, rootDetector, tampering, emulator, deviceSecurityState).build()` |
| `rasp.setConfig` | `checker.setRASPConfig(RASPConfig(trustedStores, threatActionConfig))` |
| `rasp.quickCheck` | `checker.quickCheck()` → map enum → string |
| `rasp.subscribe` | `checker.subscribe(detail, autoPopup) { result -> sink.success(...) }` |
| `ssl.configure` | `CShieldSSL.configure(pins, hostname)` |
| `aip.signRequest` | `AIPCore.sign(context, payload)` + tự build payload theo §3.4 |
| `aip.verifyResponse` | `AIPCore.verifySign(context, payload, signature)` |
| `http.request` | Build OkHttp request + execute với `OkHttpClient.Builder().sslSocketFactory(...).addInterceptor(CShieldInterceptor()).build()` |

### 7.3 Build config

AAR không được nhúng trực tiếp vào `libs/` (Flutter không hỗ trợ direct `.aar` file dependency khi build AAR). Thay vào đó dùng **Local Maven Repository**:

**Luồng generate:**
1. Build AAR từ project Android (`CShieldSampleApp`):
   ```bash
   ./gradlew :c-shield-sdk:assembleRelease
   ```
2. Task `assembleRelease` tự động publish AAR vào `android/local-repo/` của Flutter plugin (qua `maven-publish`). Version lấy từ `gradle.properties` (`CSHIELD_SDK_VERSION`).

**Cấu hình `android/build.gradle` của plugin:**

```groovy
// Capture plugin dir trước — gradle.allprojects propagate repo sang mọi consumer
def pluginAndroidDir = project.projectDir

gradle.allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("$pluginAndroidDir/local-repo") }
    }
}

// Version đọc động từ maven-metadata.xml — tự đồng bộ với Android SDK
def resolveCShieldSdkVersion() {
    def metadataFile = file("${project.projectDir}/local-repo/com/example/c_shield_sdk/c-shield-sdk/maven-metadata.xml")
    if (metadataFile.exists()) {
        return new XmlSlurper().parse(metadataFile).versioning.release.text()
    }
    return "1.0.0"
}

dependencies {
    implementation("com.example.c_shield_sdk:c-shield-sdk:${resolveCShieldSdkVersion()}")
}
```

**Tại sao dùng `gradle.allprojects` thay vì `allprojects`?**
`allprojects` trong một sub-module chỉ scope cho chính module đó. `gradle.allprojects` propagate repository sang toàn bộ projects trong build (bao gồm `:app` của consumer) — consumer không cần thêm cấu hình Gradle thủ công.

**Bump version:**
Chỉ cần sửa một chỗ trong `CShieldSampleApp/gradle.properties`:
```properties
CSHIELD_SDK_VERSION=1.1.0
```
Sau đó chạy lại `./gradlew :c-shield-sdk:assembleRelease` — Flutter plugin tự đọc version mới từ `maven-metadata.xml`.

### 7.4 Quyền (permissions)

Plugin Android cần đảm bảo các quyền sau (đặt trong `android/src/main/AndroidManifest.xml` của plugin, **không** trong app người dùng):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<!-- Các quyền khác mà SDK gốc yêu cầu (kiểm tra trong AAR) -->
```

> SDK gốc có thể đã khai báo manifest của riêng nó trong AAR — Gradle sẽ tự merge khi build.

---

## 8. Native bridge iOS

### 8.1 Tích hợp `CShieldSDK.xcframework`

Hiện chưa có file framework. Khi nhận được:

1. Copy vào `ios/Frameworks/CShieldSDK.xcframework`.
2. Cập nhật `ios/c_shield_sdk.podspec`:
   ```ruby
   s.vendored_frameworks = 'Frameworks/CShieldSDK.xcframework'
   s.preserve_paths = 'Frameworks/CShieldSDK.xcframework'
   s.pod_target_xcconfig = {
     'DEFINES_MODULE' => 'YES',
     'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
     'OTHER_LDFLAGS' => '-framework CShieldSDK'
   }
   ```
3. Trong Swift bridge: `import CShieldSDK`.

### 8.2 Cấu trúc plugin

```swift
// ios/Classes/CShieldSdkPlugin.swift
import Flutter
import CShieldSDK

public class CShieldSdkPlugin: NSObject, FlutterPlugin {
  private let raspBridge = RaspBridge()
  private let sslBridge  = SslBridge()
  private let aipBridge  = AipBridge()
  private let httpBridge = HttpBridge()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "c_shield_sdk", binaryMessenger: registrar.messenger())
    let raspEvents = FlutterEventChannel(name: "c_shield_sdk/rasp_events", binaryMessenger: registrar.messenger())
    let instance = CShieldSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    raspEvents.setStreamHandler(instance.raspBridge.streamHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "sdk.initialize":             CShield.initialize(); result(nil)
    case let m where m.hasPrefix("rasp."): raspBridge.handle(call, result: result)
    case let m where m.hasPrefix("ssl."):  sslBridge.handle(call, result: result)
    case let m where m.hasPrefix("aip."):  aipBridge.handle(call, result: result)
    case let m where m.hasPrefix("http."): httpBridge.handle(call, result: result)
    default: result(FlutterMethodNotImplemented)
    }
  }
}
```

### 8.3 Lưu ý quan trọng cho iOS

- `CShield.initialize()` khởi động **watchdog thread**. Nó sẽ kill app khi phát hiện threat dù không có RASPChecker. Cần document rõ cho user Flutter.
- `RASPChecker.subscribe` trên iOS **không hỗ trợ `detail` mode** — plugin phải ignore param `detail`.
- Một số check (`rootDetector`, `tampering`, `emulator`) **không tồn tại** trên iOS — plugin phải bỏ qua flag tương ứng.

---

## 9. Cách xử lý khác biệt giữa hai nền tảng

| Tính năng | Android | iOS | Cách Flutter SDK xử lý |
|---|---|---|---|
| Auto-init via ContentProvider | ✅ | ❌ | API public `initialize()` luôn nên gọi; trên Android nó là idempotent |
| `checkDebugger` | ✅ | ✅ | Forward thẳng |
| `rootDetector` | ✅ | ❌ | Trên iOS: silently ignore flag |
| `tampering` | ✅ | ❌ | Trên iOS: silently ignore flag |
| `emulator` / `simulator` | emulator | simulator | API Flutter dùng tên **`emulator`** và auto-map sang `simulator` trên iOS |
| `deviceSecurityState` | ✅ | ✅ | Forward thẳng (các sub-check khác nhau) |
| `userCA` check | ✅ (qua action config) | ✅ (explicit flag) | Flutter có flag `userCA` riêng, áp dụng tuỳ nền tảng |
| `detail` mode trong `subscribe` | ✅ | ❌ | Trên iOS: ignore param |
| Tampering store list (`trustedStores`) | ✅ | ❌ | Trên iOS: silently ignore |
| RASP watchdog thread chạy nền | ❌ | ✅ (sau initialize) | Document trong README |
| `AIPCore.sign / verifySign` (manual) | ✅ (public) | ❌ (private) | Flutter SDK chỉ phơi `aip.signRequest`/`verifyResponse` ở mức request — không phơi raw sign cho v1 |
| Body normalization rule (multipart) | ✅ | ✅ | Hành vi giống nhau — Flutter chỉ gửi raw bytes + content-type, native xử lý |
| KillApp delay | 3.5s | 3s | Document; không cần can thiệp |

**Quy ước nhất quán:** flag/field **không hỗ trợ trên một nền tảng KHÔNG throw**, chỉ silently ignore — vì developer Flutter sẽ viết code chung cho cả 2 OS.

---

## 10. Cách tiếp cận tầng HTTP (SSL pinning + AIP signing)

### 10.1 Vấn đề cốt lõi: không thể inject pinning vào Dart HttpClient

- Dart `HttpClient` (dart:io) dùng `SecurityContext` — chỉ chấp nhận PEM cert, không phơi callback per-handshake.
- `package:http` và `package:dio` đều build trên `HttpClient`. Không có API để cắm `X509TrustManager` (Android) hay `URLSessionDelegate` (iOS).
- Vì vậy **không thể** dùng pinning của native nếu giữ HTTP call ở Dart.

### 10.2 Giải pháp: route toàn bộ HTTP qua native

Plugin cung cấp `CShieldHttpClient` — một `http.BaseClient` mà mỗi `send()` sẽ:

1. Đọc `BaseRequest` (method, url, headers, body bytes).
2. Gửi qua method `http.request` xuống native.
3. Native dùng `OkHttpClient`/`URLSession` đã cấu hình với:
   - SSLSocketFactory / URLSession từ `CShieldSSL`
   - `CShieldInterceptor` (đã tự ký request + verify response)
4. Native trả về `{statusCode, headers, body}` → Dart bọc thành `http.StreamedResponse`.

```
Dart code → http.Request → CShieldHttpClient.send()
    → MethodChannel("http.request", {method, url, headers, body})
    → Native: build OkHttp request → execute → response
    → Trả về Dart → http.StreamedResponse
```

**Hệ quả:**
- ✅ Pinning + signing hoạt động đầy đủ.
- ✅ API Dart giống hệt `http.Client`, dễ swap-in.
- ⚠️ Có overhead serialize/deserialize body qua channel. Với body > 1MB nên dùng streaming via `EventChannel` (xem [§10.4](#104-streaming-cho-body-lớn)).
- ⚠️ Mất khả năng dùng connection pooling sẵn có của Dart HttpClient — nhưng OkHttp/URLSession đều pool ở phía native, nên tổng thể không tệ.

### 10.3 Adapter cho `dio`

Để không cứng phụ thuộc `dio`, plugin phơi class với tham số `dynamic`:

```dart
class CShieldDioInterceptor {
  /// Trả về một `dio.Interceptor` đã được wire vào CShieldHttpClient.
  /// User cần truyền `Dio()` từ ngoài vào để plugin gán transformer.
  ///
  /// Cách dùng:
  ///   final dio = Dio();
  ///   CShieldDioInterceptor.attach(dio);   // dio.httpClientAdapter = ...
  static void attach(dynamic dio);
}
```

Bên trong dùng kỹ thuật runtime reflection-lite + adapter `HttpClientAdapter` của dio để route qua native — không cần `import 'package:dio'`.

### 10.4 Streaming cho body lớn

Cho v1, đơn giản hoá: body bị giới hạn 8MB qua method channel. Khi cần lớn hơn:

- Method `http.requestStream` → trả về `subscriptionId`.
- Body chunks phát qua `EventChannel("c_shield_sdk/http_stream")`.
- Dart side stitch thành `Stream<List<int>>`.

→ Hoãn sang v1.1.

### 10.5 Manual signing (advanced)

Một số use-case (WebSocket, custom protocol) cần ký thủ công. Chỉ Android có public `AIPCore`. **Đề xuất**: phơi cho v1.1 nếu có yêu cầu, dạng:

```dart
class CShieldAip {
  /// Android-only — trên iOS sẽ throw UnsupportedError.
  static Future<String> sign(Uint8List payload);
  static Future<bool> verifySign(Uint8List payload, String signature);
}
```

---

## 11. Xử lý vòng đời & threading

- **MethodChannel** chạy trên **platform thread** (main thread của native). RASP/SSL/signing là các operation tương đối nhanh — chấp nhận được, không block UI vì Dart side luôn `await`.
- **`http.request`** có thể chậm → trên Android phải submit lên thread pool (`OkHttpClient.dispatcher`), trên iOS dùng `URLSessionTask` async. Result trả về phải post lại main thread trước khi gọi `result.success(...)`.
- **EventChannel sink** (cho RASP subscribe): native phải gọi `runOnUiThread`/`DispatchQueue.main.async` khi gọi `sink.success()` — Flutter requires.
- **Lifecycle:** khi engine detach (`onDetachedFromEngine` / `detachFromEngineForRegistrar`), plugin phải:
  - Cancel mọi `subscriptionId` đang active.
  - Close OkHttpClient (gọi `executorService.shutdown()`).
  - Set channel handler về null.

---

## 12. Lỗi & exception mapping

Native `PlatformException` được map sang `CShieldException`:

| `PlatformException.code` (native quy ước) | `CShieldErrorCode` Dart |
|---|---|
| `aip_missing_header` | `aipMissingHeader` |
| `aip_timestamp_expired` | `aipTimestampExpired` |
| `aip_invalid_signature` | `aipInvalidSignature` |
| `aip_signing_failed` | `aipSigningFailed` |
| `aip_proxy_ca` | `aipDetectProxyCA` |
| `ssl_not_configured` | `sslNotConfigured` |
| `ssl_pin_mismatch` | `sslPinMismatch` |
| `rasp_checker_disposed` | `raspCheckerDisposed` |
| `not_initialized` | `notInitialized` |
| `invalid_argument` | `invalidArgument` |
| Bất kỳ code nào khác | `nativeError` |

Mapping được thực hiện trong `lib/src/internal/codec/error_codec.dart` — gọi từ MethodChannel wrapper, không leak `PlatformException` ra public API.

---

## 13. Kế hoạch triển khai theo phase

### Phase 0 — Setup (đã làm 1 phần)
- [x] Plugin scaffold `c_shield_sdk` đã được sinh ra.
- [x] Tích hợp AAR Android qua Local Maven Repository (`android/local-repo/`).
- [x] `android/build.gradle` cấu hình `gradle.allprojects` + dynamic version từ `maven-metadata.xml`.
- [x] Auto-publish: `assembleRelease` bên Android SDK tự động publish vào `local-repo`.
- [x] Error message rõ ràng khi `local-repo` chưa được generate (`preBuild` check).
- [ ] Tạo cấu trúc thư mục `lib/src/api/...` & `lib/src/internal/...`.

### Phase 1 — RASP (Android trước, vì có sẵn AAR)
- [ ] Implement `RaspBridge.kt` + handler cho 4 method (`build`, `setConfig`, `quickCheck`, `subscribe`).
- [ ] Implement `RaspEventStreamHandler.kt`.
- [ ] Dart side: `RASPChecker`, `RASPConfig`, các enum/sealed class, `RASPExtendedResult`.
- [ ] Codec encode/decode `RASPCheckType` (sealed → string key và ngược lại).
- [ ] App example: nút "Run RASP check" hiển thị kết quả.
- [ ] Unit test với mock MethodChannel.

### Phase 2 — SSL pinning + AIP signing (vẫn Android)
- [ ] `SslBridge.kt` — wrap `CShieldSSL.configure/updatePins/isConfigured`.
- [ ] `AipBridge.kt` — wrap `AIPCore.sign/verifySign` (sẽ dùng nội bộ cho `http.request`).
- [ ] `HttpBridge.kt` — OkHttpClient với pinning + interceptor.
- [ ] Dart: `CShieldSSL`, `CShieldHttpClient`.

### Phase 3 — Port sang iOS (sau khi nhận framework)
- [ ] Bổ sung `ios/Frameworks/CShieldSDK.xcframework`.
- [ ] Sửa `c_shield_sdk.podspec` (vendored_frameworks).
- [ ] Implement 4 bridge tương ứng Swift.
- [ ] Smoke test trên simulator + thiết bị thật.

### Phase 4 — Polish & release
- [ ] Adapter cho `dio` (`CShieldDioInterceptor`).
- [ ] README cuối cùng với code mẫu (cả http + dio + RASP).
- [ ] CI/CD: build + chạy test cả 2 OS.
- [ ] Versioning + `CHANGELOG.md`.

---

## 14. Trạng thái hiện tại & việc cần làm ngay

**Đã có:**
- `pubspec.yaml` khai báo plugin với `pluginClass: CShieldSdkPlugin` (Android + iOS).
- AAR Android tích hợp qua Local Maven Repository tại `android/local-repo/`.
- `android/build.gradle` hoàn chỉnh: `gradle.allprojects`, dynamic version, `preBuild` error check.
- Auto-publish: chạy `./gradlew :c-shield-sdk:assembleRelease` bên `CShieldSampleApp` là xong.
- Plugin scaffold mặc định (`getPlatformVersion`) — sẽ thay thế dần.

**Cần làm ngay (theo thứ tự):**

1. **Generate `local-repo`** trước khi build plugin lần đầu:
   ```bash
   cd <path-to>/CShieldSampleApp
   ./gradlew :c-shield-sdk:assembleRelease
   ```
2. **Xác minh package name của SDK gốc**: `com.example.c_shield_sdk` — đã xác nhận đúng.
3. **Yêu cầu file `CShieldSDK.xcframework`** từ team iOS để mở phase 3.
4. **Quyết định scope v1**: có ship `CShieldDioInterceptor` ngay không, hay v1.0 chỉ ship `http.BaseClient`?
5. Tạo skeleton thư mục `lib/src/api/...` và `lib/src/internal/...` theo [§3](#3-cấu-trúc-thư-mục).

---

## Phụ lục A — Sample usage (dự kiến cho README)

```dart
import 'package:c_shield_sdk/c_shield_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Init SDK
  await CShieldSdk.initialize();

  // 2. Config SSL pinning
  await CShieldSSL.configure(
    pins: ['sha256/AAAAA...=', 'sha256/BBBBB...='],
    hostname: 'api.example.com',
  );

  // 3. RASP check trước khi mở màn hình chính
  final checker = RASPChecker.builder();
  await checker.setRASPConfig(RASPConfig(
    threatActionConfig: const ThreatActionConfig(
      rootDetectedAction: ThreatDetectedAction.killApp,
    ),
  ));

  checker.subscribe(automaticallyShowPopup: true).listen((result) {
    if (result.vulnerable) {
      debugPrint('[CShield] Threat: ${result.checkType.key}');
    }
  });

  // 4. HTTP — dùng CShieldHttpClient drop-in cho http.Client
  final client = CShieldHttpClient();
  try {
    final resp = await client.post(
      Uri.parse('https://api.example.com/api/v1/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: '{"otp":"123456"}',
    );
    print(resp.body);
  } on CShieldException catch (e) {
    if (e.code == CShieldErrorCode.aipDetectProxyCA) {
      // Bị MITM — không retry
    }
  }

  runApp(const MyApp());
}
```

---

> **Tóm tắt cho người đọc nhanh:** Plugin có 4 tầng (Public Dart API / Platform Interface / Native bridge / SDK gốc). Mọi request HTTP đi qua native để pinning + signing hoạt động. RASP dùng EventChannel để stream kết quả. Khác biệt Android/iOS được xử lý bằng cách *silently ignore* các flag không hỗ trợ thay vì throw, để code Flutter chung cho cả 2 OS. AAR Android tích hợp qua Local Maven Repository (`android/local-repo/`) — generate bằng cách chạy `./gradlew :c-shield-sdk:assembleRelease` từ `CShieldSampleApp`. Bước cần làm ngay: generate `local-repo` và yêu cầu file `CShieldSDK.xcframework`.
