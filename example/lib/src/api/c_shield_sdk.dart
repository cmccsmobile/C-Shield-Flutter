import 'dart:async';

import '../internal/platform/c_shield_sdk_platform_interface.dart';
import 'rasp/load_app_threat_event.dart';
import 'rasp/threat_popup_text.dart';

class CShieldSdk {
  CShieldSdk._();

  static Stream<LoadAppThreatEvent>? _threatEvents;
  static StreamSubscription<LoadAppThreatEvent>? _threatSub;

  /// Load-time threat events (Frida, root/jailbreak, hooking frameworks,
  /// tampering) reported by the native loader.
  ///
  /// Only emits when the SDK was initialized with [initialize]'s
  /// `onLoadAppThreat` — see the warning there.
  static Stream<LoadAppThreatEvent> get loadAppThreatEvents =>
      _threatEvents ??= CShieldSdkPlatform.instance.threatEvents();

  /// Loads the native library and starts the SDK. Call once, as early as
  /// possible in `main()`.
  ///
  /// When a load-time threat is detected the native side shows its built-in
  /// popup and then terminates the process — that kill is not negotiable from
  /// Dart. You can only influence *what the popup says* and *whether it shows*:
  ///
  /// - [loadAppThreatPopup] overrides the popup's title/description. A null
  ///   field keeps the native default string.
  /// - [showLoadAppThreatPopup] `false` suppresses the popup entirely (the app
  ///   is still killed silently).
  ///
  /// [onLoadAppThreat] is a **best-effort notification**, not a UI hook. The
  /// threat fires before Flutter has rendered anything and the process is torn
  /// down right after, so there is no guarantee this callback runs or that any
  /// work it starts (a network call, a dialog) completes. Use it for local
  /// logging/diagnostics only. To fully replace the popup with your own UI you
  /// must go through the native SDK (custom Activity / ViewController).
  static Future<void> initialize({
    ThreatPopupText? loadAppThreatPopup,
    bool showLoadAppThreatPopup = true,
    void Function(LoadAppThreatEvent event)? onLoadAppThreat,
  }) async {
    if (onLoadAppThreat != null) {
      await _threatSub?.cancel();
      _threatSub = loadAppThreatEvents.listen(onLoadAppThreat);
    }
    await CShieldSdkPlatform.instance.initialize(
      handleLoadAppThreat: onLoadAppThreat != null,
      showLoadAppThreatPopup: showLoadAppThreatPopup,
      loadAppThreatPopup: loadAppThreatPopup,
    );
  }
}
