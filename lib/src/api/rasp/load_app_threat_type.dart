enum LoadAppThreatType {
  frida(1),
  zygisk(2),
  shadow(3),
  tampering(4);

  const LoadAppThreatType(this.value);
  final int value;

  static LoadAppThreatType fromInt(int v) => switch (v) {
        1 => LoadAppThreatType.frida,
        2 => LoadAppThreatType.zygisk,
        3 => LoadAppThreatType.shadow,
        4 => LoadAppThreatType.tampering,
        _ => throw ArgumentError('Unknown LoadAppThreatType value: $v'),
      };
}
