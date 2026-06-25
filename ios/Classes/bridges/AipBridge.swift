import Flutter
import CShieldSDK

class AipBridge {

    // Only the cryptographic sign/verify are exposed to Flutter. Body
    // normalization, payload construction, hashing and the response
    // timestamp-window check are all done in Dart (AIPNormalizer / CShieldAIP),
    // so no fabricated URLRequest/URL is needed here.
    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "aip.sign":   sign(args: args, result: result)
        case "aip.verify": verify(args: args, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Sign / verify

    private func sign(args: [String: Any], result: FlutterResult) {
        guard let payload = args["payload"] as? String else { result(invalidArg()); return }
        do {
            let signature = try AIPCore.sign(payload)
            result(signature)
        } catch {
            result(mapError(error))
        }
    }

    private func verify(args: [String: Any], result: FlutterResult) {
        guard let payload   = args["payload"] as? String,
              let signature = args["signature"] as? String else { result(invalidArg()); return }
        do {
            let valid = try AIPCore.verifySign(payload, signature: signature)
            if valid {
                result(nil)
            } else {
                result(FlutterError(code: CShieldErrorCode.aipInvalidSignature,
                                    message: "Signature verification failed", details: nil))
            }
        } catch {
            result(mapError(error))
        }
    }

    // MARK: - Helpers

    private func invalidArg() -> FlutterError {
        FlutterError(code: CShieldErrorCode.invalidArgument, message: "Missing or invalid arguments", details: nil)
    }

    private func mapError(_ error: Error) -> FlutterError {
        if let e = error as? CShieldError {
            switch e {
            case .aipMissingHeader(let msg):    return FlutterError(code: CShieldErrorCode.aipMissingHeader,    message: msg, details: nil)
            case .aipTimestampExpired(let msg): return FlutterError(code: CShieldErrorCode.aipTimestampExpired, message: msg, details: nil)
            case .aipInvalidSignature(let msg): return FlutterError(code: CShieldErrorCode.aipInvalidSignature, message: msg, details: nil)
            case .aipSigningFailed(let msg):    return FlutterError(code: CShieldErrorCode.aipSigningFailed,    message: msg, details: nil)
            case .aipDetectProxyCA(let msg):    return FlutterError(code: CShieldErrorCode.aipProxyCA,          message: msg, details: nil)
            case .unimplement(let msg):         return FlutterError(code: CShieldErrorCode.nativeError,         message: msg, details: nil)
            }
        }
        return FlutterError(code: CShieldErrorCode.nativeError, message: error.localizedDescription, details: nil)
    }
}
