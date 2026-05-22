import 'threat_action.dart';

class RASPConfig {
  final List<String>? trustedStores;
  final ThreatActionConfig? threatActionConfig;

  const RASPConfig({this.trustedStores, this.threatActionConfig});
}

class ThreatActionConfig {
  final ThreatDetectedAction debuggerDetectedAction;
  final ThreatDetectedAction rootDetectedAction;
  final ThreatDetectedAction tamperingDetectedAction;
  final ThreatDetectedAction emulatorDetectedAction;
  final ThreatDetectedAction deviceSecurityStateUnsafeDetectedAction;
  final ThreatDetectedAction userCADetectedAction;

  const ThreatActionConfig({
    this.debuggerDetectedAction = ThreatDetectedAction.notifyApp,
    this.rootDetectedAction = ThreatDetectedAction.notifyApp,
    this.tamperingDetectedAction = ThreatDetectedAction.notifyApp,
    this.emulatorDetectedAction = ThreatDetectedAction.notifyApp,
    this.deviceSecurityStateUnsafeDetectedAction = ThreatDetectedAction.notifyApp,
    this.userCADetectedAction = ThreatDetectedAction.notifyApp,
  });
}
