import Flutter

/// Bridges `CShield` load-time threat notifications to Dart over the
/// `c_shield_sdk/threat_events` EventChannel. Mirrors Android's
/// `ThreatEventStreamHandler`.
///
/// Best-effort by design: the native SDK kills the process shortly after a
/// load-time threat, so Dart may or may not get to act. For logging only —
/// the popup is drawn natively.
///
/// A threat can also fire before Dart has subscribed (the `sdk.initialize`
/// method call and the EventChannel `onListen` arrive on different channels,
/// whose relative ordering is not guaranteed). Events emitted with no sink are
/// buffered and replayed on the next `onListen`.
final class ThreatEventStreamHandler: NSObject, FlutterStreamHandler {

    private var sink: FlutterEventSink?
    private var pending: [Int] = []

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        for threatType in pending { events(["threatType": threatType]) }
        pending.removeAll()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    /// May be called from any thread (the native listener runs on whichever
    /// thread invoked `CShield.initialize`); hops to main before touching the
    /// sink, which Flutter requires.
    func emit(_ threatType: Int) {
        if Thread.isMainThread {
            deliver(threatType)
        } else {
            DispatchQueue.main.async { [weak self] in self?.deliver(threatType) }
        }
    }

    private func deliver(_ threatType: Int) {
        if let sink = sink {
            sink(["threatType": threatType])
        } else {
            pending.append(threatType)
        }
    }
}
