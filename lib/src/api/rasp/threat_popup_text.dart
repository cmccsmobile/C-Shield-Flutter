/// Text for the SDK's built-in load-time threat popup.
///
/// Both fields are optional; a null field falls back to the native default
/// string (which may embed the threat name, e.g. "Frida detected"). This only
/// customizes the *default* popup — fully replacing the popup with your own UI
/// is a native-only capability (custom Activity on Android, custom
/// ViewController on iOS) and is not reachable from Dart, because the threat
/// fires before Flutter can render.
class ThreatPopupText {
  final String? title;
  final String? description;

  const ThreatPopupText({this.title, this.description});

  Map<String, Object?> toMap() => {
        'title': title,
        'description': description,
      };
}
