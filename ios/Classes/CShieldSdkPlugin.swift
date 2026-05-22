import Flutter
import UIKit
import CShieldSDK

public class CShieldSdkPlugin: NSObject, FlutterPlugin {

    private var eventSink: FlutterEventSink?

    private lazy var raspBridge: RaspBridge = RaspBridge { [weak self] in self?.eventSink }
    private let sslBridge = SslBridge()
    private let aipBridge = AipBridge()

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
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "sdk.initialize":
            CShield.initialize()
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
