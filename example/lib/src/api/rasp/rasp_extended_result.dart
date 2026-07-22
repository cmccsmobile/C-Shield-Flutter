import 'rasp_check_type.dart';
import 'threat_action.dart';

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
