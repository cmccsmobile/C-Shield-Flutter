# C-Shield Flutter SDK

C-Shield Flutter SDK là plugin bảo mật di động cung cấp hai lớp bảo vệ cho ứng dụng Flutter:

- **RASP (Runtime Application Self-Protection):** Phát hiện và phản ứng với các mối đe dọa bảo mật trong suốt vòng đời ứng dụng — debugger, root/jailbreak, giả mạo, emulator, trạng thái thiết bị không an toàn, và chứng chỉ CA giả.
- **AIP (API Integrity Protection):** Bảo vệ giao tiếp giữa app và server thông qua certificate pinning và ký số request/response.

SDK bọc native AAR (Android) và XCFramework (iOS), đảm bảo khả năng phát hiện mối đe dọa mạnh mẽ ở tầng native.

---

## Mục lục

1. [Tích hợp SDK](#1-tích-hợp-sdk)
   - 1.1 [Thêm dependency vào pubspec.yaml](#11-thêm-dependency-vào-pubspecyaml)
   - 1.2 [Cấu hình Android](#12-cấu-hình-android)
   - 1.3 [Cấu hình iOS](#13-cấu-hình-ios)
2. [Khởi tạo SDK](#2-khởi-tạo-sdk)
3. [Threat phát hiện lúc load app](#3-threat-phát-hiện-lúc-load-app)
4. [RASP — Runtime Application Self-Protection](#4-rasp--runtime-application-self-protection)
   - 4.1 [Xây dựng RASPChecker](#41-xây-dựng-raspchecker)
   - 4.2 [Cấu hình RASPConfig](#42-cấu-hình-raspconfig)
   - 4.3 [quickCheck — kiểm tra nhanh](#43-quickcheck--kiểm-tra-nhanh)
   - 4.4 [subscribe — kiểm tra liên tục](#44-subscribe--kiểm-tra-liên-tục)
   - 4.5 [Bảng RASPCheckType chi tiết](#45-bảng-raspchecktype-chi-tiết)
   - 4.6 [Giải phóng tài nguyên](#46-giải-phóng-tài-nguyên)
5. [AIP — API Integrity Protection](#5-aip--api-integrity-protection)
   - 5.1 [Chế độ tự động — CShieldInterceptor (http)](#51-chế-độ-tự-động--cshieldinterceptor-http)
   - 5.2 [Chế độ tự động — CShieldDioInterceptor (Dio)](#52-chế-độ-tự-động--cshielddiointerceptor-dio)
   - 5.3 [Chế độ thủ công — CShieldAIP](#53-chế-độ-thủ-công--cshieldaip)
   - 5.4 [Giao thức ký số](#54-giao-thức-ký-số)
6. [SSL — Certificate Pinning](#6-ssl--certificate-pinning)
   - 6.1 [Lấy giá trị pin](#61-lấy-giá-trị-pin)
   - 6.2 [Cấu hình CShieldSSL](#62-cấu-hình-cshieldssl)
   - 6.3 [Tích hợp với http package](#63-tích-hợp-với-http-package)
   - 6.4 [Tích hợp với Dio](#64-tích-hợp-với-dio)
   - 6.5 [Xác minh thủ công](#65-xác-minh-thủ-công)
   - 6.6 [Khả năng, hạn chế và khuyến nghị](#66-khả-năng-hạn-chế-và-khuyến-nghị)
7. [Exceptions](#7-exceptions)

---

## 1. Tích hợp SDK

### 1.1 Thêm dependency vào pubspec.yaml

Thêm `c_shield_sdk` vào `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  c_shield_sdk: ^1.0.0
```

Sau đó chạy:

```bash
flutter pub get
```

### 1.2 Cấu hình Android

#### Bước 1 — Nhận các file AAR từ CMC CShield

C-Shield SDK Android được build riêng cho từng khách hàng với certificate hash của app đã ký. Liên hệ CMC CShield để nhận file `c-shield-sdk.aar` tương ứng với signing certificate của bạn.

#### Bước 2 — Đặt các file AAR vào project

Tạo thư mục `libs/` trong `android/app/` và đặt file AAR vào đó:

```
your_app_flutter/
└── android/
    └── app/
        └── libs/  ← đặt file AAR vào đây
            └── c-shield-sdk-release.aar
            └── c-shield-sdk-debug.aar
```

#### Bước 3 — Khai báo dependency trong build.gradle

Mở `android/app/build.gradle.kts` (hoặc `build.gradle`) và thêm:

```kotlin
android {
    defaultConfig {
        minSdk = 24       // yêu cầu tối thiểu của C-Shield SDK
    }
    compileSdk = 34       // yêu cầu tối thiểu của C-Shield SDK
}

dependencies {
    // C-Shield Android SDK — file AAR do CMC CShield cung cấp
    debugImplementation(files("libs/c-shield-sdk-debug.aar"))
    releaseImplementation(files("libs/c-shield-sdk-release.aar"))

    // Các dependency bắt buộc của C-Shield SDK (Compose UI nội bộ + networking)
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.runtime:runtime")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
}
```

> **Tại sao phải khai báo thủ công?** File AAR được cung cấp trực tiếp (không qua Maven), nên Gradle không tự resolve được các transitive dependency. Các thư viện trên là những gì C-Shield SDK sử dụng nội bộ (Compose UI cho màn hình cảnh báo, Retrofit/Gson cho networking).

#### Bước 4 — Build AAB khi release

C-Shield SDK chứa native code cho 4 ABI (arm64-v8a, armeabi-v7a, x86, x86_64) để hỗ trợ cả thiết bị thật và emulator. Khi phát hành lên Play Store, **bắt buộc dùng Android App Bundle (AAB)** để Play Store tự động chỉ giao đúng ABI cho từng thiết bị — giúp giảm dung lượng download ~50-70%:

```bash
flutter build appbundle --release
```

### 1.3 Cấu hình iOS

Vui lòng đọc và làm theo các bước tại [iOS Integration Guide](doc/ios-host-app-integration.md).

---

## 2. Khởi tạo SDK

Gọi `CShieldSdk.initialize()` **trước `runApp()`** trong hàm `main()`:

```dart
import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CShieldSdk.initialize();
  runApp(const MyApp());
}
```

**Lưu ý theo nền tảng:**

| Nền tảng | Hành vi khi gọi `initialize()` |
|---|---|
| Android | Gọi `CShieldSDK.initialize(context)` native; idempotent — gọi nhiều lần vẫn an toàn |
| iOS | Khởi động **watchdog thread** chạy nền mỗi 20-30 giây; **bắt buộc phải gọi** |

Nếu không gọi `initialize()` trước khi dùng các API khác, SDK sẽ throw `CShieldException` với code `notInitialized`.

---

## 3. Threat phát hiện lúc load app

Khi app khởi động, native SDK tự động quét một số mối đe dọa nguy hiểm nhất (Frida, root/jailbreak, hooking, tampering). Nếu phát hiện: **native hiển thị một popup cảnh báo rồi kill process**. Việc kill này **native lo hoàn toàn, Flutter không thể can thiệp** — threat xảy ra ngay lúc native load, trước khi Flutter kịp render, và process bị đóng ngay sau đó.

Từ phía Flutter, bạn chỉ điều chỉnh được **nội dung** và **có/không hiện** popup:

```dart
await CShieldSdk.initialize(
  // Override text của popup mặc định. Trường null → giữ string mặc định của native.
  loadAppThreatPopup: const ThreatPopupText(
    title: 'Phát hiện mối đe dọa',
    description: 'Ứng dụng không thể chạy trong môi trường không an toàn và sẽ đóng lại.',
  ),
  // false → tắt hẳn popup (app vẫn bị kill).
  showLoadAppThreatPopup: true,
  // Thông báo best-effort — CHỈ để ghi log. Xem cảnh báo bên dưới.
  onLoadAppThreat: (event) {
    debugPrint('Load-app threat: ${event.threatType}');
  },
);
```

**Tham số của `initialize()` liên quan load-app threat:**

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `loadAppThreatPopup` | `ThreatPopupText?` | `null` | Override `title` / `description` của popup mặc định. Trường nào `null` thì dùng string mặc định của native (có thể chứa tên threat) |
| `showLoadAppThreatPopup` | `bool` | `true` | `false` = không hiện popup nào (app **vẫn bị kill**) |
| `onLoadAppThreat` | `void Function(LoadAppThreatEvent)?` | `null` | Callback thông báo khi phát hiện threat |

> ⚠️ **`onLoadAppThreat` là best-effort, KHÔNG phải hook để vẽ UI.** Threat bắn ra trước khi Flutter render và process bị đóng ngay sau đó, nên không đảm bảo callback chạy xong, cũng không đảm bảo việc nó khởi động (gọi mạng, mở dialog) kịp hoàn tất. Chỉ dùng để ghi log/diagnostics cục bộ. Muốn **thay hẳn popup bằng UI của riêng bạn**, phải làm ở tầng native (custom Activity trên Android / ViewController trên iOS) — đây là đặc quyền native, không với tới từ Flutter.

**`LoadAppThreatEvent.threatType` là enum `LoadAppThreatType`:**

| Giá trị | Mô tả | Nền tảng |
|---|---|---|
| `LoadAppThreatType.frida` | Phát hiện Frida framework | Android & iOS |
| `LoadAppThreatType.rooted` | Thiết bị bị root (Zygisk/Magisk trên Android) hoặc jailbreak (iOS) | Android & iOS |
| `LoadAppThreatType.hookingFramework` | Phát hiện framework hooking | Android & iOS |
| `LoadAppThreatType.tampering` | App bị can thiệp, chữ ký không hợp lệ | Android & iOS |

---

## 4. RASP — Runtime Application Self-Protection

RASP kiểm tra môi trường runtime trong suốt quá trình app chạy. Khác với load-time threat, RASP có thể được cấu hình để chỉ **thông báo** (`notifyApp`) thay vì kill app ngay lập tức, cho phép bạn hiển thị UI tuỳ chỉnh.

### 4.1 Xây dựng RASPChecker

Dùng `RASPChecker.builder()` để chọn các loại kiểm tra cần bật:

```dart
final checker = RASPChecker.builder(
  checkDebugger: true,        // phát hiện debugger đang attach
  rootDetector: true,         // phát hiện root (Android) / jailbreak
  tampering: true,            // phát hiện app bị giả mạo (Android only)
  emulator: true,             // phát hiện emulator (Android) / simulator (iOS)
  deviceSecurityState: true,  // phát hiện trạng thái thiết bị không an toàn
  userCA: true,               // phát hiện user-installed CA / proxy CA
);
```

Tất cả tham số đều mặc định là `true`. Tắt những check không cần thiết để giảm overhead.

**Lưu ý theo nền tảng:**

| Tham số | Android | iOS |
|---|---|---|
| `checkDebugger` | Debuggable flag + debugger connected | ptrace / exception port |
| `rootDetector` | Root detection (SuperSU, Magisk, KernelSU...) | Không áp dụng |
| `tampering` | Certificate integrity + untrusted store | Không áp dụng |
| `emulator` | Nhiều phương pháp phát hiện emulator | Phát hiện iOS Simulator |
| `deviceSecurityState` | PIN, ADB, developer mode, VPN... | PIN, Face ID, developer mode, VPN... |
| `userCA` | User CA, injected CA, proxy CA | User CA qua profile/MDM, proxy CA |

### 4.2 Cấu hình RASPConfig

Sau khi tạo checker, cấu hình hành động cho từng loại threat:

```dart
await checker.setRASPConfig(
  RASPConfig(
    trustedStores: [
      'com.android.vending',            // Google Play Store
      'com.samsung.android.galaxyapps', // Samsung Galaxy Store
    ],
    threatActionConfig: ThreatActionConfig(
      debuggerDetectedAction: ThreatDetectedAction.killApp,
      rootDetectedAction: ThreatDetectedAction.killApp,
      tamperingDetectedAction: ThreatDetectedAction.killApp,
      emulatorDetectedAction: ThreatDetectedAction.notifyApp,
      deviceSecurityStateUnsafeDetectedAction: ThreatDetectedAction.notifyApp,
      userCADetectedAction: ThreatDetectedAction.notifyApp,
    ),
  ),
);
```

**`RASPConfig`:**

| Trường | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `trustedStores` | `List<String>?` | `null` | Package name của các store tin cậy (Android only). `null` = dùng danh sách mặc định (Google Play, Samsung, Xiaomi, Huawei, OPPO, Vivo, Amazon, OnePlus) |
| `threatActionConfig` | `ThreatActionConfig?` | `null` | Hành động cho từng loại threat. `null` = tất cả mặc định `notifyApp` |

**`ThreatDetectedAction`:**

| Giá trị | Hành vi |
|---|---|
| `ThreatDetectedAction.killApp` | Hiển thị dialog cảnh báo -> tự động kill app sau ~3 giây |
| `ThreatDetectedAction.notifyApp` | Phát sự kiện để app tự xử lý (hiển thị cảnh báo tuỳ chỉnh, ghi log...) |

### 4.3 quickCheck — kiểm tra nhanh

`quickCheck()` chạy một lần và trả về mối đe dọa đầu tiên tìm thấy. Phù hợp để chặn lối vào app (màn hình splash, màn hình đăng nhập).

```dart
final result = await checker.quickCheck();

switch (result) {
  case RASPResult.secure:
    // thiết bị an toàn, tiếp tục
    break;
  case RASPResult.debuggerFound:
    showDialog(context, 'Phát hiện debugger');
    break;
  case RASPResult.deviceRooted:
    showDialog(context, 'Thiết bị đã root');
    break;
  case RASPResult.deviceTampered:
    showDialog(context, 'App bị giả mạo');
    break;
  case RASPResult.emulatorFound:
  case RASPResult.simulatorFound:
    showDialog(context, 'Đang chạy trên máy ảo');
    break;
  case RASPResult.deviceSecurityStateUnsafe:
    showDialog(context, 'Thiết bị không an toàn');
    break;
  case RASPResult.userCADetected:
    showDialog(context, 'Phát hiện chứng chỉ CA giả');
    break;
}
```

**Toàn bộ giá trị `RASPResult`:**

| Giá trị | Mô tả | Nền tảng |
|---|---|---|
| `secure` | Không phát hiện mối đe dọa | Android & iOS |
| `debuggerFound` | Debugger đang attach | Android & iOS |
| `deviceRooted` | Thiết bị đã root | Android only |
| `deviceTampered` | App bị giả mạo hoặc cài từ nguồn không tin cậy | Android only |
| `emulatorFound` | Đang chạy trên Android emulator | Android only |
| `simulatorFound` | Đang chạy trên iOS Simulator | iOS only |
| `deviceSecurityStateUnsafe` | Trạng thái bảo mật thiết bị không đạt yêu cầu | Android & iOS |
| `userCADetected` | Phát hiện user-installed CA hoặc proxy CA | Android & iOS |

> `quickCheck()` chỉ trả về mối đe dọa đầu tiên theo thứ tự ưu tiên. Dùng `subscribe()` để nhận toàn bộ kết quả.

### 4.4 subscribe — kiểm tra liên tục

`subscribe()` chạy kiểm tra định kỳ và trả về `Stream<RASPExtendedResult>`. Phù hợp để giám sát liên tục trong suốt phiên sử dụng app.

```dart
final subscription = checker.subscribe(
  detail: false,                // true = chi tiết từng sub-check, false = tổng quan theo nhóm
  automaticallyShowPopup: true, // true = SDK tự hiển thị dialog khi phát hiện threat
).listen((RASPExtendedResult result) {
  if (!result.vulnerable) return;

  switch (result.threatAction) {
    case ThreatDetectedAction.killApp:
      // SDK đã tự hiển thị dialog và sẽ kill app — không cần làm gì thêm
      break;
    case ThreatDetectedAction.notifyApp:
      // Tự xử lý UI
      _handleThreat(result.checkType);
      break;
  }
});

// Huỷ khi không cần nữa (ví dụ: dispose widget)
await subscription.cancel();
```

**Tham số `subscribe()`:**

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `detail` | `bool` | `false` | `false` = một sự kiện tổng quan mỗi nhóm; `true` = sự kiện cho từng sub-check |
| `automaticallyShowPopup` | `bool` | `true` | Tự động hiển thị dialog khi phát hiện threat |

**`RASPExtendedResult`:**

```dart
class RASPExtendedResult {
  final RASPCheckType checkType;           // loại kiểm tra cụ thể
  final bool vulnerable;                   // true = phát hiện mối đe dọa
  final ThreatDetectedAction threatAction; // hành động được cấu hình
}
```

**Ví dụ với `detail: true` — xử lý từng sub-check:**

```dart
checker.subscribe(detail: true, automaticallyShowPopup: false).listen((result) {
  if (!result.vulnerable) return;

  if (result.checkType is Magisk) {
    _logThreat('Magisk detected');
  } else if (result.checkType is FingerprintFromEmulator) {
    _logThreat('Emulator fingerprint detected');
  }
});
```

**Hiển thị popup tuỳ chỉnh bằng Flutter:**

Khác với load-app threat, RASP chạy khi app **đang sống** (engine Flutter đã render), nên bạn **vẽ được UI Dart** ngay trong callback. Điều kiện: đặt `automaticallyShowPopup: false` để native **không** hiện popup của nó song song (nếu để `true` sẽ ra **hai** popup).

Vì callback nằm ngoài cây widget (thường ở `main()`), dùng `navigatorKey` để mở dialog:

```dart
final navigatorKey = GlobalKey<NavigatorState>();
bool _dialogVisible = false; // stream chi tiết bắn nhiều kết quả liên tiếp → giữ 1 dialog

// Trong MaterialApp: navigatorKey: navigatorKey

checker.subscribe(detail: true, automaticallyShowPopup: false).listen((result) {
  if (!result.vulnerable) return;
  _showThreatDialog(result);
});

Future<void> _showThreatDialog(RASPExtendedResult result) async {
  final context = navigatorKey.currentContext;
  if (context == null || _dialogVisible) return;

  final isCritical = result.threatAction == ThreatDetectedAction.killApp;
  _dialogVisible = true;
  await showDialog<void>(
    context: context,
    barrierDismissible: !isCritical,
    builder: (ctx) => AlertDialog(
      title: Text(isCritical ? 'Phát hiện mối đe dọa' : 'Cảnh báo bảo mật'),
      content: Text('Loại: ${result.checkType.key}'),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            if (isCritical) SystemNavigator.pop(); // tự đóng app
          },
          child: Text(isCritical ? 'Thoát' : 'OK'),
        ),
      ],
    ),
  );
  _dialogVisible = false;
}
```

> Khi `automaticallyShowPopup: false`, native giao **toàn quyền** phản ứng cho app — kể cả việc kill. Với threat `killApp`, nếu muốn đóng app bạn phải tự làm (`SystemNavigator.pop()` như trên). Muốn giữ auto-kill của native thì để `automaticallyShowPopup: true`, nhưng khi đó **đừng** vẽ popup riêng nữa kẻo trùng.

### 4.5 Bảng RASPCheckType chi tiết

Khi `detail: true`, `RASPExtendedResult.checkType` là một trong các lớp sau:

**Debugger** (Android & iOS):

| Lớp | `key` | Mô tả |
|---|---|---|
| `DebuggerOverview` | `DebuggerOverviewCheck` | Tổng quan nhóm debugger (dùng khi `detail: false`) |
| `Debuggable` | `Debuggable` | App có flag `FLAG_DEBUGGABLE` (Android) |
| `DebuggerConnected` | `DebuggerConnected` | Debugger đang kết nối |

**Root** (Android only):

| Lớp | `key` | Mô tả |
|---|---|---|
| `RootOverview` | `RootCheckOverview` | Tổng quan nhóm root |
| `SuperSu` | `SuperSu` | Binary su tại các đường dẫn phổ biến |
| `Magisk` | `Magisk` | Magisk qua `/proc/self/mounts` |
| `SysWritable` | `SysWritable` | Phân vùng `/system` có thể ghi |
| `HasProperties` | `HasProperties` | System properties nguy hiểm (`ro.debuggable=1`, `ro.secure=0`) |
| `KernelSUorAPatch` | `KernelSUorAPatch` | KernelSU hoặc APatch |

**Emulator / Simulator** (Android & iOS):

| Lớp | `key` | Mô tả |
|---|---|---|
| `EmulatorOverview` | `EmulatorOverviewCheck` | Tổng quan nhóm emulator |
| `AvdDevice` | `AvdDevice` | Android Virtual Device |
| `AvdHardware` | `AvdHardware` | AVD hardware fingerprint |
| `Genymotion` | `Genymotion` | Genymotion emulator |
| `Nox` | `Nox` | Nox emulator |
| `Memu` | `Memu` | MEmu emulator |
| `Bluestacks` | `Bluestacks` | BlueStacks emulator |
| `GoogleEmulator` | `GoogleEmulator` | Google AVD chính thức |
| `FingerprintFromEmulator` | `FingerprintFromEmulator` | Build fingerprint có dấu hiệu emulator |
| `SensorsFromEmulator` | `SensorsFromEmulator` | Cảm biến giả (goldfish/qemu) |
| `SuspiciousFiles` | `SuspiciousFiles` | File đặc trưng của emulator |
| `SuspiciousPackages` | `SuspiciousPackages` | Package của emulator |
| `SuspiciousQemuProperties` | `SuspiciousQemuProperties` | System properties QEMU |
| `SuspiciousMounts` | `SuspiciousMounts` | Mount point bất thường |
| `SuspiciousCpu` | `SuspiciousCpu` | CPU model bất thường |
| `SuspiciousModules` | `SuspiciousModules` | Kernel module bất thường |
| `SuspiciousRadioVersion` | `SuspiciousRadioVersion` | Radio version giả |
| `SimulatorCheck` | `SimulatorCheck` | iOS Simulator |

**Tampering** (Android only):

| Lớp | `key` | Mô tả |
|---|---|---|
| `TamperingOverview` | `TamperingCheckOverview` | Tổng quan nhóm tampering |
| `InvalidCertificateIntegrity` | `InvalidCertificateIntegrity` | Chứng chỉ ký APK không khớp |
| `UntrustedStore` | `UntrustedStore` | App cài từ store không nằm trong `trustedStores` |

**Device Security State** (Android & iOS):

| Lớp | `key` | Mô tả |
|---|---|---|
| `DeviceSecurityStateOverview` | `DeviceSecurityStateCheckOverview` | Tổng quan nhóm trạng thái bảo mật |
| `DeviceUnlocked` | `DeviceUnlocked` | Không có PIN/pattern/biometric |
| `HardwareBackedKeystoreUnavailable` | `HardwareBackedKeystoreUnavailable` | Hardware-backed keystore không khả dụng |
| `DeveloperModeOn` | `DeveloperModeOn` | Developer mode đang bật |
| `AdbEnabled` | `AdbEnabled` | ADB đang bật (Android only) |
| `SystemVpnEnabled` | `SystemVpnEnabled` | Đang kết nối VPN |
| `AccessibilityServiceOn` | `AccessibilityServiceOn` | Có accessibility service đang chạy (Android only) |

**User CA** (Android & iOS):

| Lớp | `key` | Mô tả |
|---|---|---|
| `UserCAOverview` | `UserCACheckOverview` | Tổng quan nhóm user CA |
| `UserInstalledCA` | `UserInstalledCA` | CA do người dùng tự cài |
| `InjectedSystemCA` | `InjectedSystemCA` | CA giả được inject vào hệ thống |
| `ProxyCA` | `ProxyCA` | CA của proxy phổ biến (Burp, Charles...) |

### 4.6 Giải phóng tài nguyên

Khi không còn dùng checker, gọi `dispose()` để giải phóng tài nguyên native:

```dart
@override
void dispose() {
  _checker.dispose();
  super.dispose();
}
```

Sau khi `dispose()`, mọi lời gọi method khác trên checker sẽ throw `CShieldException(raspCheckerDisposed)`.

---

## 5. AIP — API Integrity Protection

AIP ký số mỗi request gửi lên server và xác thực chữ ký của mỗi response nhận về, ngăn chặn MITM và replay attack.

SDK cung cấp hai cách tích hợp:

- **Chế độ tự động (khuyến nghị):** Dùng `CShieldInterceptor` (cho `http` package) hoặc `CShieldDioInterceptor` (cho Dio). Sign/verify diễn ra hoàn toàn tự động.
- **Chế độ thủ công:** Dùng `CShieldAIP` trực tiếp để kiểm soát hoàn toàn payload và timing.

### 5.1 Chế độ tự động — CShieldInterceptor (http)

```dart
import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:http/http.dart' as http;

// Khởi tạo một lần, tái sử dụng cho toàn bộ app
final client = CShieldInterceptor();

// Hoặc kết hợp với SSL pinning:
final client = CShieldInterceptor(
  inner: CShieldSSL.createIOClient(),
);

// Sử dụng như http.Client thông thường:
final response = await client.post(
  Uri.parse('https://api.example.com/users'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'name': 'Alice'}),
);
// cs-timestamp / cs-signature được đính kèm tự động vào request.
// Response signature được xác thực tự động trước khi trả về.
```

**Tham số `CShieldInterceptor`:**

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `inner` | `http.Client?` | `http.Client()` | HTTP client bên trong (truyền client có SSL pinning để kết hợp) |
| `verifyResponses` | `bool` | `true` | Xác thực chữ ký response; đặt `false` nếu server chưa tích hợp ký response |

### 5.2 Chế độ tự động — CShieldDioInterceptor (Dio)

```dart
import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// Thêm AIP interceptor
dio.interceptors.add(const CShieldDioInterceptor());

// Kết hợp với SSL pinning:
dio.httpClientAdapter = IOHttpClientAdapter(
  createHttpClient: CShieldSSL.createHttpClient,
);
dio.interceptors.add(const CShieldDioInterceptor());

// Sử dụng bình thường
final response = await dio.post('/api/v1/login', data: {'user': 'alice'});
```

**Tham số `CShieldDioInterceptor`:**

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `verifyResponses` | `bool` | `true` | Xác thực chữ ký response; đặt `false` nếu server chưa ký response |

> Khi `verifyResponses: true`, interceptor tạm thời force `ResponseType.bytes` để đọc raw bytes xác thực, sau đó decode lại sang kiểu gốc trước khi trả về caller.

### 5.3 Chế độ thủ công — CShieldAIP

Dùng khi cần kiểm soát hoàn toàn — WebSocket, custom HTTP client, hoặc khi cần log chi tiết payload.

```dart
import 'package:c_shield_sdk/c_shield_sdk.dart';

// 1. Ký request thủ công
final aipHeaders = await CShieldAIP.signRequest(
  method: 'POST',
  path: '/api/v1/login',    // chỉ path, không có query string
  body: Uint8List.fromList(utf8.encode(jsonEncode({'user': 'alice'}))),
  contentType: 'application/json',
);
// aipHeaders = {'cs-timestamp': '...', 'cs-signature': '...'}
// Đính kèm vào request trước khi gửi

// 2. Xác thực response thủ công
await CShieldAIP.verifyResponse(
  statusCode: 200,
  path: '/api/v1/login',
  headers: response.headers,
  body: responseBytes,
);
// Không throw = hợp lệ; throw CShieldException nếu thất bại

// 3. Ký payload thô (nâng cao)
final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
final norm = await CShieldAIP.normalizeBody(
  body: bodyBytes,
  contentType: 'application/json',
);
final payload = 'POST./api/v1/login.$ts.${norm['hash']}';
final signature = await CShieldAIP.sign(payload);

// 4. Xác thực chữ ký thô
await CShieldAIP.verify(payload: payload, signature: signature);
```

**API `CShieldAIP`:**

| Phương thức | Mô tả |
|---|---|
| `signRequest(method, path, body, contentType)` | Ký request và trả về map `{'cs-timestamp', 'cs-signature'}` |
| `verifyResponse(statusCode, path, headers, body)` | Xác thực chữ ký response; throw `CShieldException` nếu thất bại |
| `sign(payload)` | Ký payload thô; caller tự xây dựng payload string |
| `verify(payload, signature)` | Xác thực chữ ký payload thô |
| `normalizeBody(body, contentType)` | Chuẩn hoá body và tính hash; trả về `{'normalizedString', 'sizeInBytes', 'hash'}` |

### 5.4 Giao thức ký số

**Request — client gửi lên server:**

Headers đính kèm:
```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

Payload được ký:
```
{METHOD}.{path}.{timestamp}.{SHA256(body)}
```

Ví dụ:
```
POST./api/v1/login.1746700000.e3b0c44298fc1c149afbf4c8996fb924...
```

**Response — server trả về:**

Headers mà server phải đính kèm:
```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

Payload server ký:
```
{statusCode}.{path}.{timestamp}.{SHA256(responseBody)}
```

**Quy tắc:**
- Timestamp phải nằm trong cửa sổ **+-30 giây** so với giờ thiết bị.
- `path` là URL path không bao gồm query string (`/api/v1/login`, không phải `/api/v1/login?token=abc`).
- SHA-256 của body là lowercase hex.

**Body normalization:**

| Content-Type | Cách xử lý |
|---|---|
| `application/json` / text | Body bytes dùng nguyên văn |
| `multipart/form-data` | Chỉ lấy text fields (bỏ qua file parts), sắp xếp theo tên field, serialize JSON |

---

## 6. SSL — Certificate Pinning

Certificate pinning đảm bảo app chỉ chấp nhận đúng chứng chỉ của server đã biết, ngăn chặn MITM kể cả khi thiết bị tin tưởng CA giả.

### 6.1 Lấy giá trị pin

Pin là SHA-256 của SPKI (Subject Public Key Info) của certificate, encode base64:

```bash
# Lấy pin từ server trực tiếp
openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl base64

# Thêm prefix "sha256/" vào kết quả
# Ví dụ: sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
```

**Khuyến nghị: luôn cung cấp tối thiểu 2 pin** (primary + backup) để tránh lockout khi rotate certificate.

#### Pin intermediate CA để sống sót qua rotation

Certificate leaf thường được **cấp lại định kỳ** (Let's Encrypt/Google Trust Services ~90 ngày) và **có thể đổi key mỗi lần** → pin leaf sẽ lệch và **app bị chặn kết nối** cho tới khi ra bản update. Để tránh, hãy pin **public key của một intermediate CA ổn định** (ít đổi trong nhiều năm) thay vì/bên cạnh leaf. `createDioAdapter()` khớp pin trên **toàn bộ chain**, nên chỉ cần một cert bất kỳ trong chain khớp là hợp lệ.

```bash
# Xem toàn bộ chain (leaf + intermediate + root)
openssl s_client -connect api.example.com:443 -servername api.example.com -showcerts </dev/null 2>/dev/null

# Với mỗi block "BEGIN CERTIFICATE" (cert #1 = intermediate), tính SPKI pin:
openssl x509 -in intermediate.pem -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary | openssl base64
```

> ⚠️ **Chỉ đường Dio (`createDioAdapter`) mới khớp cả chain.** Đường `http` và `verifyPin` chỉ so leaf (xem [6.6](#66-khả-năng-hạn-chế-và-khuyến-nghị)) — pin intermediate sẽ **không** khớp ở hai đường đó.

### 6.2 Cấu hình CShieldSSL

Gọi `configure()` sau `initialize()`, trước khi thực hiện bất kỳ network request nào:

```dart
await CShieldSSL.configure(
  pins: [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // primary
    'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // backup
  ],
  hostname: 'api.example.com',
);
```

**API `CShieldSSL`:**

| Phương thức | Mô tả |
|---|---|
| `configure(pins, hostname)` | Cấu hình pinning; throw `ArgumentError` nếu pin rỗng, hostname trống, hoặc pin không có prefix `sha256/` |
| `updatePins(pins, hostname)` | Cập nhật pin mới sau khi server rotate certificate (alias của `configure`) |
| `isConfigured()` | Trả về `true` nếu đã cấu hình |
| `createDioAdapter()` | **(Khuyến nghị)** Tạo `HttpClientAdapter` cho Dio. Request tới `hostname` được thực hiện ở **native** (OkHttp/URLSession) → pinning chạy ở tầng TLS với **full chain** (khớp leaf/intermediate/root). Host khác đi qua adapter mặc định. |
| `createHttpClient()` | Tạo `HttpClient` (dart:io) với SPKI pinning qua `badCertificateCallback`. **Leaf-only, thuần Dart** — xem cảnh báo [6.6](#66-khả-năng-hạn-chế-và-khuyến-nghị) |
| `createIOClient()` | Tạo `IOClient` (http package) — drop-in cho `http.Client()`. **Leaf-only, thuần Dart** |
| `verifyPin(certDerBase64, host)` | Xác minh thủ công một certificate DER base64. **Chỉ kiểm SPKI của leaf** (Dart chỉ truyền được leaf) |

### 6.3 Tích hợp với http package

> ⚠️ **Không khuyến nghị cho API nhạy cảm.** Đường `http` dùng `badCertificateCallback` — callback này **chỉ kích hoạt khi cert FAIL validation mặc định**. Một cert MITM chain hợp lệ tới CA được tin (kể cả CA do nạn nhân tự cài) sẽ **pass mà không bị kiểm pin**. Ngoài ra nó **chỉ so leaf**, không pin được intermediate. Với dữ liệu nhạy cảm hãy dùng **Dio + `createDioAdapter()`** ([6.4](#64-tích-hợp-với-dio)).

```dart
import 'package:c_shield_sdk/c_shield_sdk.dart';

// Setup (một lần trong main() hoặc khởi tạo app)
await CShieldSSL.configure(
  pins: ['sha256/...'],
  hostname: 'api.example.com',
);

// Tạo client (tái sử dụng, không tạo lại mỗi request)
final client = CShieldSSL.createIOClient();

// Sử dụng giống http.Client thông thường
final response = await client.get(
  Uri.parse('https://api.example.com/data'),
);
```

**Kết hợp SSL pinning + AIP:**

```dart
final client = CShieldInterceptor(
  inner: CShieldSSL.createIOClient(), // SSL pinning ở lớp trong
);
// client vừa có certificate pinning vừa ký/xác thực AIP tự động
```

### 6.4 Tích hợp với Dio

```dart
import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:dio/dio.dart';

await CShieldSSL.configure(
  pins: ['sha256/...'],
  hostname: 'api.example.com',
);

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// Gắn SSL pinning vào Dio. Với host đã configure, request được thực hiện
// ở NATIVE (OkHttp trên Android, URLSession trên iOS) — nơi thấy full
// certificate chain — nên pinning khớp được cả intermediate/root, đồng bộ
// với Android/iOS SDK gốc và chạy dưới bảo vệ RASP. Host khác đi qua
// adapter mặc định (không ảnh hưởng).
dio.httpClientAdapter = CShieldSSL.createDioAdapter();

// Kết hợp với AIP
dio.interceptors.add(const CShieldDioInterceptor());
```

> **Buffered (không streaming).** Request/response được truyền trọn gói qua native. Không hỗ trợ upload/download progress, `ResponseType.stream`, hay SSE trên host được pin — xem [6.6](#66-khả-năng-hạn-chế-và-khuyến-nghị).

### 6.5 Xác minh thủ công

> ⚠️ `verifyPin()` **chỉ kiểm SPKI của leaf certificate** (Dart chỉ truyền được leaf xuống native) và không thực hiện CA chain validation đầy đủ. Coi đây là tiện ích phụ, không phải cơ chế pinning chính. Cơ chế đầy đủ (full chain + CA validation) là `createDioAdapter()`.

Dùng `verifyPin()` trong interceptor tuỳ chỉnh hoặc WebSocket:

```dart
// Lấy DER bytes của leaf certificate từ kết nối TLS
final certDerBase64 = base64.encode(peerCertificateDerBytes);

final trusted = await CShieldSSL.verifyPin(
  certDerBase64: certDerBase64,
  host: 'api.example.com',
);

if (!trusted) {
  throw CShieldException(
    CShieldErrorCode.sslPinMismatch,
    'Certificate pin mismatch for api.example.com',
  );
}
```

### 6.6 Khả năng, hạn chế và khuyến nghị

Ràng buộc gốc của Flutter: `dart:io` **chỉ expose leaf certificate**, không có API thuần Dart nào lấy được full chain. Vì vậy SDK **uỷ quyền transport cho native** (OkHttp/URLSession) ở đường Dio để pinning chạy đúng nơi có full chain — đây là mô hình được xem là chuẩn nhất cho Flutter.

#### Đang làm được gì

| Năng lực | `createDioAdapter` (Dio) | `createIOClient` (http) | `verifyPin` |
|---|---|---|---|
| Khớp SPKI **full chain** (leaf/intermediate/root) | ✅ | ❌ chỉ leaf | ❌ chỉ leaf |
| Pin intermediate → chống rotation | ✅ | ❌ | ❌ |
| System CA validation (fail-closed) | ✅ (native) | một phần¹ | một phần |
| Chặn user-installed CA (Burp/Charles) | ✅ (native) | ❌² | — |
| Chạy dưới RASP (chống Frida/Xposed hook)³ | ✅ | ❌ (ở Dart) | ✅ |

¹ `badCertificateCallback` chỉ chạy khi validation mặc định thất bại.
² MITM có cert chain hợp lệ tới CA được tin sẽ lọt (callback không kích hoạt).
³ Chỉ có hiệu lực khi **RASP được bật và threat action đặt chặn/thoát app** (xem [mục 4](#4-rasp--runtime-application-self-protection)). RASP bảo vệ **logic kiểm tra pin** (nằm trong native SDK), không phải giá trị pin do app truyền vào.

#### Hạn chế khi sử dụng

**A. Bẩm sinh của Flutter — không cách nào trong SDK thoát được:**
- **Phạm vi phủ hẹp**: chỉ traffic đi qua đúng Dio instance có adapter, và chỉ tới `hostname` đã config. **KHÔNG** pin: WebView (`webview_flutter`), tải ảnh (`Image.network`, `CachedNetworkImage`), thư viện HTTP khác, plugin bên thứ ba. → Dồn API nhạy cảm về Dio instance đã gắn adapter.
- **Web build**: trình duyệt không cho app-level pinning.
- **Quản lý rotation/expiry**: cert hết hạn còn pin → app chết. Giảm nhẹ bằng pin **intermediate** ([6.1](#pin-intermediate-ca-để-sống-sót-qua-rotation)) + backup pin.

**B. Do cách hiện thực (đường Dio native transport):**
- **Buffered, không streaming**: no upload/download progress, no `ResponseType.stream`, no SSE. File lớn dễ tốn RAM → dùng Dio instance không-pin cho các ca này.
- **`CancelToken` chưa huỷ được request native**: Dio huỷ ở phía Dart nhưng request native vẫn chạy tới khi xong.
- **iOS gộp header đa giá trị**: `HTTPURLResponse` gộp nhiều header cùng tên (đặc biệt `Set-Cookie`) thành một chuỗi → interceptor cookie có thể parse sai. Android trả đúng list.
- **iOS `followRedirects=false` là best-effort**: URLSession mặc định vẫn follow redirect.
- **Fidelity khác**: cookie jar, HTTP/2, nén, proxy… theo client native chứ không theo Dio; `sendTimeout` không map.

**C. Đường `http` package và `verifyPin`**: leaf-only, không đảm bảo an toàn — **không dùng cho dữ liệu nhạy cảm** (xem cảnh báo [6.3](#63-tích-hợp-với-http-package), [6.5](#65-xác-minh-thủ-công)).

#### Cần cải thiện (roadmap)

- [ ] Nối `CancelToken` → huỷ request native (`Call.cancel()` / `URLSessionTask.cancel()`).
- [ ] Sửa gộp header đa giá trị trên iOS (đặc biệt `Set-Cookie`).
- [ ] Honor `followRedirects=false` trên iOS (task-level delegate).
- [ ] (Lớn) Streaming bridge cho upload/download lớn và SSE.
- [ ] Cân nhắc đưa pin vào native build-time / remote-config có chữ ký để giảm bề mặt tráo pin.

#### Khuyến nghị nhanh

- Dữ liệu nhạy cảm → **Dio + `createDioAdapter()`**, pin **intermediate + backup**.
- **Bật RASP** và đặt threat action chặn/thoát để lời hứa chống-hook có hiệu lực.
- Không dựa vào `createIOClient`/`verifyPin` như lớp bảo mật chính.

---

## 7. Exceptions

Tất cả lỗi từ SDK đều được throw dưới dạng `CShieldException`:

```dart
class CShieldException implements Exception {
  final CShieldErrorCode code;    // enum mã lỗi
  final String message;           // mô tả lỗi
  final Object? nativeCause;      // lỗi gốc từ native (nếu có)
}
```

**`CShieldErrorCode`:**

| Code | Nguyên nhân |
|---|---|
| `aipMissingHeader` | Response thiếu header `cs-timestamp` hoặc `cs-signature` |
| `aipTimestampExpired` | Timestamp nằm ngoài cửa sổ +-30 giây |
| `aipInvalidSignature` | Chữ ký response không hợp lệ (response bị tampering) |
| `aipSigningFailed` | Lỗi ký request (private key chưa sẵn sàng) |
| `aipDetectProxyCA` | Phát hiện proxy CA — AIP từ chối xử lý |
| `sslNotConfigured` | Gọi `createHttpClient()`/`createIOClient()` trước khi gọi `CShieldSSL.configure()` |
| `sslPinMismatch` | Certificate của server không khớp với pin đã cấu hình |
| `raspCheckerDisposed` | Gọi method trên `RASPChecker` đã bị `dispose()` |
| `notInitialized` | Gọi API trước khi gọi `CShieldSdk.initialize()` |
| `invalidArgument` | Tham số không hợp lệ |
| `nativeError` | Lỗi không xác định từ native SDK |

**Cách bắt lỗi:**

```dart
try {
  final response = await client.post(Uri.parse('https://api.example.com/login'), ...);
} on CShieldException catch (e) {
  switch (e.code) {
    case CShieldErrorCode.aipDetectProxyCA:
      // Có proxy CA đang active — không cho phép tiếp tục
      _logSecurityEvent('Proxy CA detected');
      break;
    case CShieldErrorCode.aipTimestampExpired:
      // Đồng hồ lệch hoặc bị replay attack
      _showError('Lỗi xác thực thời gian');
      break;
    case CShieldErrorCode.aipInvalidSignature:
      // Response bị can thiệp
      _logSecurityEvent('Response tampered');
      break;
    case CShieldErrorCode.sslPinMismatch:
      // Certificate không khớp — MITM hoặc cần rotate pin
      _logSecurityEvent('SSL pin mismatch');
      break;
    default:
      _showError('Lỗi bảo mật: ${e.message}');
  }
}
```

---

## Luồng tích hợp điển hình

```
main()
  +-- WidgetsFlutterBinding.ensureInitialized()
  +-- CShieldSdk.initialize(              // bắt buộc — trước runApp()
  |     loadAppThreatPopup: ...,          //   tuỳ chọn — override text popup load-app
  |     onLoadAppThreat: ...,             //   tuỳ chọn — nhận notify load-app (best-effort, log)
  |   )
  +-- CShieldSSL.configure(pins, host)   // nếu dùng certificate pinning
  +-- runApp()

Khởi tạo HTTP client (singleton)
  +-- CShieldInterceptor(inner: CShieldSSL.createIOClient())   // http package
      // hoặc Dio:
  +-- dio.httpClientAdapter = CShieldSSL.createDioAdapter()
  +-- dio.interceptors.add(CShieldDioInterceptor())

Tại màn hình splash / đăng nhập
  +-- RASPChecker.builder(...).quickCheck()   // kiểm tra nhanh một lần

Trong suốt phiên sử dụng
  +-- checker.subscribe(...).listen(...)      // giám sát liên tục
```
