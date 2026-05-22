// All subclasses must live in this file (sealed class constraint).
// Use RASPCheckType.fromKey() to convert native string keys to typed instances.
sealed class RASPCheckType {
  const RASPCheckType();

  String get key;

  static RASPCheckType fromKey(String k) => switch (k) {
        // Debugger
        'DebuggerOverviewCheck' => const DebuggerOverview(),
        'Debuggable' => const Debuggable(),
        'DebuggerConnected' => const DebuggerConnected(),
        // Root (Android)
        'RootCheckOverview' => const RootOverview(),
        'SuperSu' => const SuperSu(),
        'Magisk' => const Magisk(),
        'SysWritable' => const SysWritable(),
        'HasProperties' => const HasProperties(),
        'KernelSUorAPatch' => const KernelSUorAPatch(),
        // Emulator / Simulator
        'EmulatorOverviewCheck' => const EmulatorOverview(),
        'AvdDevice' => const AvdDevice(),
        'AvdHardware' => const AvdHardware(),
        'Genymotion' => const Genymotion(),
        'Nox' => const Nox(),
        'Memu' => const Memu(),
        'Bluestacks' => const Bluestacks(),
        'GoogleEmulator' => const GoogleEmulator(),
        'FingerprintFromEmulator' => const FingerprintFromEmulator(),
        'SensorsFromEmulator' => const SensorsFromEmulator(),
        'SuspiciousFiles' => const SuspiciousFiles(),
        'SuspiciousPackages' => const SuspiciousPackages(),
        'SuspiciousQemuProperties' => const SuspiciousQemuProperties(),
        'SuspiciousMounts' => const SuspiciousMounts(),
        'SuspiciousCpu' => const SuspiciousCpu(),
        'SuspiciousModules' => const SuspiciousModules(),
        'SuspiciousRadioVersion' => const SuspiciousRadioVersion(),
        'SimulatorCheck' => const SimulatorCheck(),
        // Tampering (Android)
        'TamperingCheckOverview' => const TamperingOverview(),
        'InvalidCertificateIntegrity' => const InvalidCertificateIntegrity(),
        'UntrustedStore' => const UntrustedStore(),
        // Device Security State
        'DeviceSecurityStateCheckOverview' => const DeviceSecurityStateOverview(),
        'DeviceUnlocked' => const DeviceUnlocked(),
        'HardwareBackedKeystoreUnavailable' =>
          const HardwareBackedKeystoreUnavailable(),
        'DeveloperModeOn' => const DeveloperModeOn(),
        'AdbEnabled' => const AdbEnabled(),
        'SystemVpnEnabled' => const SystemVpnEnabled(),
        'AccessibilityServiceOn' => const AccessibilityServiceOn(),
        // User CA
        'UserCACheckOverview' => const UserCAOverview(),
        'UserInstalledCA' => const UserInstalledCA(),
        'InjectedSystemCA' => const InjectedSystemCA(),
        'ProxyCA' => const ProxyCA(),
        _ => UnknownCheckType(k),
      };
}

// --- Debugger ---
final class DebuggerOverview extends RASPCheckType {
  const DebuggerOverview();
  @override
  String get key => 'DebuggerOverviewCheck';
}

final class Debuggable extends RASPCheckType {
  const Debuggable();
  @override
  String get key => 'Debuggable';
}

final class DebuggerConnected extends RASPCheckType {
  const DebuggerConnected();
  @override
  String get key => 'DebuggerConnected';
}

// --- Root (Android) ---
final class RootOverview extends RASPCheckType {
  const RootOverview();
  @override
  String get key => 'RootCheckOverview';
}

final class SuperSu extends RASPCheckType {
  const SuperSu();
  @override
  String get key => 'SuperSu';
}

final class Magisk extends RASPCheckType {
  const Magisk();
  @override
  String get key => 'Magisk';
}

final class SysWritable extends RASPCheckType {
  const SysWritable();
  @override
  String get key => 'SysWritable';
}

final class HasProperties extends RASPCheckType {
  const HasProperties();
  @override
  String get key => 'HasProperties';
}

final class KernelSUorAPatch extends RASPCheckType {
  const KernelSUorAPatch();
  @override
  String get key => 'KernelSUorAPatch';
}

// --- Emulator / Simulator ---
final class EmulatorOverview extends RASPCheckType {
  const EmulatorOverview();
  @override
  String get key => 'EmulatorOverviewCheck';
}

final class AvdDevice extends RASPCheckType {
  const AvdDevice();
  @override
  String get key => 'AvdDevice';
}

final class AvdHardware extends RASPCheckType {
  const AvdHardware();
  @override
  String get key => 'AvdHardware';
}

final class Genymotion extends RASPCheckType {
  const Genymotion();
  @override
  String get key => 'Genymotion';
}

final class Nox extends RASPCheckType {
  const Nox();
  @override
  String get key => 'Nox';
}

final class Memu extends RASPCheckType {
  const Memu();
  @override
  String get key => 'Memu';
}

final class Bluestacks extends RASPCheckType {
  const Bluestacks();
  @override
  String get key => 'Bluestacks';
}

final class GoogleEmulator extends RASPCheckType {
  const GoogleEmulator();
  @override
  String get key => 'GoogleEmulator';
}

final class FingerprintFromEmulator extends RASPCheckType {
  const FingerprintFromEmulator();
  @override
  String get key => 'FingerprintFromEmulator';
}

final class SensorsFromEmulator extends RASPCheckType {
  const SensorsFromEmulator();
  @override
  String get key => 'SensorsFromEmulator';
}

final class SuspiciousFiles extends RASPCheckType {
  const SuspiciousFiles();
  @override
  String get key => 'SuspiciousFiles';
}

final class SuspiciousPackages extends RASPCheckType {
  const SuspiciousPackages();
  @override
  String get key => 'SuspiciousPackages';
}

final class SuspiciousQemuProperties extends RASPCheckType {
  const SuspiciousQemuProperties();
  @override
  String get key => 'SuspiciousQemuProperties';
}

final class SuspiciousMounts extends RASPCheckType {
  const SuspiciousMounts();
  @override
  String get key => 'SuspiciousMounts';
}

final class SuspiciousCpu extends RASPCheckType {
  const SuspiciousCpu();
  @override
  String get key => 'SuspiciousCpu';
}

final class SuspiciousModules extends RASPCheckType {
  const SuspiciousModules();
  @override
  String get key => 'SuspiciousModules';
}

final class SuspiciousRadioVersion extends RASPCheckType {
  const SuspiciousRadioVersion();
  @override
  String get key => 'SuspiciousRadioVersion';
}

final class SimulatorCheck extends RASPCheckType {
  const SimulatorCheck();
  @override
  String get key => 'SimulatorCheck';
}

// --- Tampering (Android) ---
final class TamperingOverview extends RASPCheckType {
  const TamperingOverview();
  @override
  String get key => 'TamperingCheckOverview';
}

final class InvalidCertificateIntegrity extends RASPCheckType {
  const InvalidCertificateIntegrity();
  @override
  String get key => 'InvalidCertificateIntegrity';
}

final class UntrustedStore extends RASPCheckType {
  const UntrustedStore();
  @override
  String get key => 'UntrustedStore';
}

// --- Device Security State ---
final class DeviceSecurityStateOverview extends RASPCheckType {
  const DeviceSecurityStateOverview();
  @override
  String get key => 'DeviceSecurityStateCheckOverview';
}

final class DeviceUnlocked extends RASPCheckType {
  const DeviceUnlocked();
  @override
  String get key => 'DeviceUnlocked';
}

final class HardwareBackedKeystoreUnavailable extends RASPCheckType {
  const HardwareBackedKeystoreUnavailable();
  @override
  String get key => 'HardwareBackedKeystoreUnavailable';
}

final class DeveloperModeOn extends RASPCheckType {
  const DeveloperModeOn();
  @override
  String get key => 'DeveloperModeOn';
}

final class AdbEnabled extends RASPCheckType {
  const AdbEnabled();
  @override
  String get key => 'AdbEnabled';
}

final class SystemVpnEnabled extends RASPCheckType {
  const SystemVpnEnabled();
  @override
  String get key => 'SystemVpnEnabled';
}

final class AccessibilityServiceOn extends RASPCheckType {
  const AccessibilityServiceOn();
  @override
  String get key => 'AccessibilityServiceOn';
}

// --- User CA ---
final class UserCAOverview extends RASPCheckType {
  const UserCAOverview();
  @override
  String get key => 'UserCACheckOverview';
}

final class UserInstalledCA extends RASPCheckType {
  const UserInstalledCA();
  @override
  String get key => 'UserInstalledCA';
}

final class InjectedSystemCA extends RASPCheckType {
  const InjectedSystemCA();
  @override
  String get key => 'InjectedSystemCA';
}

final class ProxyCA extends RASPCheckType {
  const ProxyCA();
  @override
  String get key => 'ProxyCA';
}

// --- Fallback for unknown keys from native ---
final class UnknownCheckType extends RASPCheckType {
  final String rawKey;
  const UnknownCheckType(this.rawKey);
  @override
  String get key => rawKey;
}
