import Flutter
import CShieldSDK

class RaspBridge {
    private var checkers: [String: RASPChecker] = [:]
    private let getSink: () -> FlutterEventSink?

    init(getSink: @escaping () -> FlutterEventSink?) {
        self.getSink = getSink
    }

    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "rasp.build":          build(args: args, result: result)
        case "rasp.setConfig":      setConfig(args: args, result: result)
        case "rasp.quickCheck":     quickCheck(args: args, result: result)
        case "rasp.subscribe":      subscribe(args: args, result: result)
        case "rasp.cancelSubscribe": result(nil)
        case "rasp.dispose":
            guard let id = args["checkerId"] as? String else { result(invalidArg()); return }
            checkers.removeValue(forKey: id)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Handlers

    private func build(args: [String: Any], result: FlutterResult) {
        let flags = args["flags"] as? [String: Bool] ?? [:]
        // Dart flag keys: checkDebugger, emulator (→ iOS "simulator"),
        // deviceSecurityState, userCA.
        // rootDetector and tampering are Android-only; ignored on iOS.
        let checker = RASPChecker.Builder(
            checkDebugger:       flags["checkDebugger"] ?? true,
            simulator:           flags["emulator"] ?? true,
            deviceSecurityState: flags["deviceSecurityState"] ?? true,
            userCA:              flags["userCA"] ?? true
        ).build()
        let id = UUID().uuidString
        checkers[id] = checker
        result(id)
    }

    private func setConfig(args: [String: Any], result: FlutterResult) {
        guard let id = args["checkerId"] as? String, let checker = checkers[id] else {
            result(FlutterError(code: CShieldErrorCode.raspCheckerDisposed, message: "Checker not found", details: nil))
            return
        }
        let config = args["config"] as? [String: Any] ?? [:]
        let actionMap = config["threatActionConfig"] as? [String: String]
        checker.setRASPConfig(RASPConfig(threatActionConfig: parseActionConfig(actionMap)))
        result(nil)
    }

    private func quickCheck(args: [String: Any], result: FlutterResult) {
        guard let id = args["checkerId"] as? String, let checker = checkers[id] else {
            result(FlutterError(code: CShieldErrorCode.raspCheckerDisposed, message: "Checker not found", details: nil))
            return
        }
        result(checker.quickCheck().flutterKey)
    }

    private func subscribe(args: [String: Any], result: @escaping FlutterResult) {
        guard let id = args["checkerId"] as? String,
              let subscriptionId = args["subscriptionId"] as? String,
              let popup = args["automaticallyShowPopup"] as? Bool,
              let checker = checkers[id] else {
            result(FlutterError(code: CShieldErrorCode.raspCheckerDisposed, message: "Checker not found", details: nil))
            return
        }

        // Return immediately so Dart can start consuming EventChannel events.
        result(nil)

        DispatchQueue.global(qos: .default).async { [weak self] in
            checker.subscribe(automaticallyShowPopup: popup) { [weak self] extResult in
                let event: [String: Any] = [
                    "subscriptionId": subscriptionId,
                    "type": "result",
                    "data": [
                        "checkType":    extResult.checkType.flutterKey,
                        "vulnerable":   extResult.vulnerable,
                        "threatAction": extResult.threatAction.flutterKey
                    ]
                ]
                DispatchQueue.main.async { self?.getSink()?(event) }
            }
            DispatchQueue.main.async { [weak self] in
                self?.getSink()?([
                    "subscriptionId": subscriptionId,
                    "type": "complete"
                ] as [String: Any])
            }
        }
    }

    // MARK: - Helpers

    private func parseActionConfig(_ map: [String: String]?) -> ThreatActionConfig? {
        guard let map else { return nil }
        func action(_ key: String) -> ThreatDetectedAction {
            map[key] == "KillApp" ? .killApp : .notifyApp
        }
        return ThreatActionConfig(
            debuggerDetectedAction:                  action("debuggerDetectedAction"),
            simulatorDetectedAction:                 action("emulatorDetectedAction"),
            deviceSecurityStateUnsafeDetectedAction: action("deviceSecurityStateUnsafeDetectedAction"),
            userCADetectedAction:                    action("userCADetectedAction")
        )
    }

    private func invalidArg() -> FlutterError {
        FlutterError(code: CShieldErrorCode.invalidArgument, message: "Missing or invalid arguments", details: nil)
    }
}

// MARK: - Flutter ↔ native key mapping

extension RASPResult {
    var flutterKey: String {
        switch self {
        case .secure:                    return "Secure"
        case .debuggerFound:             return "DebuggerFound"
        case .simulatorFound:            return "SimulatorFound"
        case .deviceSecurityStateUnsafe: return "DeviceSecurityStateUnsafe"
        case .userCADetected:            return "UserCADetected"
        }
    }
}

extension RASPCheckType {
    var flutterKey: String {
        switch self {
        case .debuggerCheck:            return "DebuggerOverviewCheck"
        case .simulatorCheck:           return "SimulatorCheck"
        case .deviceSecurityStateCheck: return "DeviceSecurityStateCheckOverview"
        case .userCACheck:              return "UserCACheckOverview"
        }
    }
}

extension ThreatDetectedAction {
    var flutterKey: String { self == .killApp ? "KillApp" : "NotifyApp" }
}
