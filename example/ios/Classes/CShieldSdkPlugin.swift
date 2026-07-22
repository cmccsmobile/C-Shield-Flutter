import Flutter
import UIKit
import CShieldSDK

public class CShieldSdkPlugin: NSObject, FlutterPlugin {

    private var eventSink: FlutterEventSink?

    private lazy var raspBridge: RaspBridge = RaspBridge { [weak self] in self?.eventSink }
    private let sslBridge = SslBridge()
    private let aipBridge = AipBridge()
    private let threatStreamHandler = ThreatEventStreamHandler()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "c_shield_sdk",
            binaryMessenger: registrar.messenger()
        )
        let instance = CShieldSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "c_shield_sdk/rasp_events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)

        let threatChannel = FlutterEventChannel(
            name: "c_shield_sdk/threat_events",
            binaryMessenger: registrar.messenger()
        )
        threatChannel.setStreamHandler(instance.threatStreamHandler)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "sdk.initialize":
            let args = call.arguments as? [String: Any]
            let reaction = Self.parseReaction(args)
            // Best-effort notification; the popup itself is drawn natively.
            let notifyDart = args?["handleLoadAppThreat"] as? Bool ?? false
            let listener: ((CShieldThreatType) -> Void)? = notifyDart
                ? { [weak self] threatType in
                    self?.threatStreamHandler.emit(Int(threatType.rawValue))
                }
                : nil
            CShield.initialize(reaction: reaction, onLoadAppThreatDetected: listener)
            result(nil)
        case let m where m.hasPrefix("rasp."):
            raspBridge.handle(call: call, result: result)
        case let m where m.hasPrefix("ssl."):
            sslBridge.handle(call: call, result: result)
        case let m where m.hasPrefix("aip."):
            aipBridge.handle(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Maps the method-channel payload to a reaction. Flutter can only express
    /// the built-in popup (with optional title/description) or `.none`;
    /// `.customViewController` is native-only and never crosses the channel.
    private static func parseReaction(_ args: [String: Any]?) -> LoadAppThreatReaction {
        if (args?["loadAppThreatReaction"] as? String) == "none" {
            return .none
        }
        let popup = args?["loadAppThreatPopup"] as? [String: Any]
        return .defaultPopup(
            title: popup?["title"] as? String,
            description: popup?["description"] as? String
        )
    }
}

extension CShieldSdkPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
