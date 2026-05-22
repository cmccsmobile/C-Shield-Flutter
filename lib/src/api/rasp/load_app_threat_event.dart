import 'load_app_threat_type.dart';

class LoadAppThreatEvent {
  final LoadAppThreatType threatType;

  const LoadAppThreatEvent({required this.threatType});

  @override
  String toString() => 'LoadAppThreatEvent(threatType: $threatType)';
}
