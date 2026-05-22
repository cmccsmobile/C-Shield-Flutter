import Flutter
import CShieldSDK

class AipBridge {

    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {

        // ── Standalone sign/verify ──────────────────────────────────────────
        case "aip.sign":          sign(args: args, result: result)
        case "aip.verify":        verify(args: args, result: result)
        case "aip.normalizeBody": normalizeBody(args: args, result: result)

        // ── Interceptor-style helpers ───────────────────────────────────────
        case "aip.signRequest":   signRequest(args: args, result: result)
        case "aip.verifyResponse": verifyResponse(args: args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Standalone

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

    private func normalizeBody(args: [String: Any], result: FlutterResult) {
        guard let bodyData    = args["body"] as? FlutterStandardTypedData,
              let contentType = args["contentType"] as? String else { result(invalidArg()); return }

        var req = URLRequest(url: URL(string: "https://placeholder.com/")!)
        req.httpBody = bodyData.data
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let bodyResult = AIPCore.normalizeBodyForSigning(req)
        result([
            "normalizedString": bodyResult.normalizedString,
            "sizeInBytes":      bodyResult.sizeInBytes,
            "hash":             bodyResult.hash,
        ])
    }

    // MARK: - Interceptor-style

    private func signRequest(args: [String: Any], result: FlutterResult) {
        guard let method      = args["method"] as? String,
              let path        = args["path"] as? String,
              let headers     = args["headers"] as? [String: String],
              let bodyData    = args["body"] as? FlutterStandardTypedData,
              let contentType = args["contentType"] as? String else { result(invalidArg()); return }

        var comps = URLComponents()
        comps.scheme = "https"; comps.host = "placeholder"
        comps.path = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = comps.url else { result(invalidArg()); return }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = bodyData.data
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        do {
            let interceptor = CShieldInterceptor()
            try interceptor.intercept(request: &req)
            let allHeaders = req.allHTTPHeaderFields ?? [:]
            let timestamp  = allHeaders.first { $0.key.lowercased() == "cs-timestamp" }?.value ?? ""
            let signature  = allHeaders.first { $0.key.lowercased() == "cs-signature" }?.value ?? ""
            result(["cs-timestamp": timestamp, "cs-signature": signature])
        } catch {
            result(mapError(error))
        }
    }

    private func verifyResponse(args: [String: Any], result: FlutterResult) {
        guard let statusCode = args["statusCode"] as? Int,
              let path       = args["path"] as? String,
              let headers    = args["headers"] as? [String: String],
              let bodyData   = args["body"] as? FlutterStandardTypedData else { result(invalidArg()); return }

        var comps = URLComponents()
        comps.scheme = "https"; comps.host = "placeholder"
        comps.path = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = comps.url,
              let httpResp = HTTPURLResponse(url: url, statusCode: statusCode,
                                             httpVersion: "HTTP/1.1", headerFields: headers)
        else { result(invalidArg()); return }

        do {
            let interceptor = CShieldInterceptor()
            _ = try interceptor.interceptResponse(response: httpResp, data: bodyData.data)
            result(nil)
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
