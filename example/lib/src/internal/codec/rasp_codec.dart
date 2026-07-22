import '../../api/rasp/rasp_check_type.dart';
import '../../api/rasp/rasp_config.dart';
import '../../api/rasp/rasp_extended_result.dart';
import '../../api/rasp/rasp_result.dart';
import '../../api/rasp/threat_action.dart';

class RaspCodec {
  static RASPResult resultFromKey(String key) => switch (key) {
    'Secure' => RASPResult.secure,
    'DebuggerFound' => RASPResult.debuggerFound,
    'DeviceRooted' => RASPResult.deviceRooted,
    'DeviceTampered' => RASPResult.deviceTampered,
    'EmulatorFound' => RASPResult.emulatorFound,
    'SimulatorFound' => RASPResult.simulatorFound,
    'DeviceSecurityStateUnsafe' => RASPResult.deviceSecurityStateUnsafe,
    _ => RASPResult.secure,
  };

  static ThreatDetectedAction actionFromKey(String key) => switch (key) {
    'KillApp' => ThreatDetectedAction.killApp,
    'NotifyApp' => ThreatDetectedAction.notifyApp,
    _ => ThreatDetectedAction.notifyApp,
  };

  static String actionToKey(ThreatDetectedAction action) => switch (action) {
    ThreatDetectedAction.killApp => 'KillApp',
    ThreatDetectedAction.notifyApp => 'NotifyApp',
  };

  static RASPExtendedResult extendedResultFromMap(Map<dynamic, dynamic> data) {
    return RASPExtendedResult(checkType: RASPCheckType.fromKey(data['checkType'] as String), vulnerable: data['vulnerable'] as bool, threatAction: actionFromKey(data['threatAction'] as String));
  }

  static Map<String, dynamic> configToMap(RASPConfig config) {
    return {if (config.trustedStores != null) 'trustedStores': config.trustedStores, if (config.threatActionConfig != null) 'threatActionConfig': _actionConfigToMap(config.threatActionConfig!)};
  }

  static Map<String, String> _actionConfigToMap(ThreatActionConfig c) => {
    'debuggerDetectedAction': actionToKey(c.debuggerDetectedAction),
    'rootDetectedAction': actionToKey(c.rootDetectedAction),
    'tamperingDetectedAction': actionToKey(c.tamperingDetectedAction),
    'emulatorDetectedAction': actionToKey(c.emulatorDetectedAction),
    'deviceSecurityStateUnsafeDetectedAction': actionToKey(c.deviceSecurityStateUnsafeDetectedAction),
  };
}
