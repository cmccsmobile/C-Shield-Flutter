/// Load-time threats reported by the native loader.
///
/// Values are the cross-platform contract shared with Android and iOS native —
/// keep them in sync. Names are platform-neutral: e.g. [rooted] covers Android
/// Zygisk root and iOS jailbreak; [hookingFramework] covers Android ShadowHook
/// and iOS generic hooking.
enum LoadAppThreatType {
  frida(1),
  rooted(2),
  hookingFramework(3),
  tampering(4);

  const LoadAppThreatType(this.value);
  final int value;

  static LoadAppThreatType fromInt(int v) => switch (v) {
        1 => LoadAppThreatType.frida,
        2 => LoadAppThreatType.rooted,
        3 => LoadAppThreatType.hookingFramework,
        4 => LoadAppThreatType.tampering,
        _ => throw ArgumentError('Unknown LoadAppThreatType value: $v'),
      };
}
