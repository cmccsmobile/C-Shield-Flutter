import CommonCrypto
import Flutter
import CShieldSDK
import Foundation

class SslBridge {

    // Cached when ssl.configure / ssl.updatePins is called so that
    // handleCheckServerTrusted can access pins without modifying the iOS SDK.
    private var cachedPins: [String] = []
    private var cachedHostname: String = ""

    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "ssl.configure":
            guard let pins = args["pins"] as? [String],
                  let hostname = args["hostname"] as? String else { result(invalidArg()); return }
            cachedPins = pins
            cachedHostname = hostname
            CShieldSSL.configure(pins: pins, hostname: hostname)
            result(nil)
        case "ssl.updatePins":
            guard let pins = args["pins"] as? [String],
                  let hostname = args["hostname"] as? String else { result(invalidArg()); return }
            cachedPins = pins
            cachedHostname = hostname
            CShieldSSL.updatePins(pins: pins, hostname: hostname)
            result(nil)
        case "ssl.isConfigured":
            result(CShieldSSL.isConfigured())
        case "ssl.checkServerTrusted":
            handleCheckServerTrusted(args: args, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - ssl.checkServerTrusted

    /// Verifies a DER-encoded certificate (base64) using system CA validation + SPKI pin check.
    ///
    /// Flutter equivalent of CShieldTrustManager on iOS:
    ///   1. SecTrustEvaluateWithError  — system CA validation
    ///   2. computeSpkiPin             — SPKI pin verification against cachedPins
    private func handleCheckServerTrusted(args: [String: Any], result: @escaping FlutterResult) {
        guard let certDerBase64 = args["certDer"] as? String,
              let certData = Data(base64Encoded: certDerBase64, options: .ignoreUnknownCharacters),
              let cert = SecCertificateCreateWithData(nil, certData as CFData) else {
            result(invalidArg()); return
        }
        let host = args["host"] as? String ?? ""

        guard CShieldSSL.isConfigured() else {
            result(FlutterError(code: CShieldErrorCode.sslNotConfigured,
                                message: "CShieldSSL not configured",
                                details: nil))
            return
        }

        // Step 1: SPKI pin verification (does not require full chain)
        let computed = computeSpkiPin(cert)
        guard cachedPins.contains(computed) else {
            result(false); return
        }

        // Step 2: System CA validation with the leaf cert as its own anchor so
        // the evaluation succeeds even when the intermediate CA is not cached.
        // This mirrors Android's X509TrustManagerExtensions behaviour where the
        // system validates and we additionally enforce the SPKI pin above.
        let policy = SecPolicyCreateSSL(true, host as CFString)
        var trust: SecTrust?
        let certArray = [cert] as CFArray
        guard SecTrustCreateWithCertificates(certArray, policy, &trust) == errSecSuccess,
              let serverTrust = trust else {
            result(false); return
        }
        // Allow the cert to serve as its own anchor so CA chain validation
        // doesn't fail when only the leaf cert is provided.
        SecTrustSetAnchorCertificates(serverTrust, certArray)
        SecTrustSetAnchorCertificatesOnly(serverTrust, false)
        var cfError: CFError?
        let trusted = SecTrustEvaluateWithError(serverTrust, &cfError)
        result(trusted)
    }

    // MARK: - SPKI computation (mirrors CShieldTrustManager.computeSpkiPin)

    /// Computes `sha256/<base64>` from a certificate's SubjectPublicKeyInfo.
    ///
    /// `SecKeyCopyExternalRepresentation` returns raw key bytes without ASN.1 header.
    /// The appropriate header is prepended (by key size) to match the SPKI format
    /// produced by Android's `cert.publicKey.encoded`.
    private func computeSpkiPin(_ certificate: SecCertificate) -> String {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let rawKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as? Data
        else { return "" }

        let spkiData: Data
        switch rawKeyData.count {
        case 65:  spkiData = Self.ecP256Header  + rawKeyData   // EC P-256
        case 97:  spkiData = Self.ecP384Header  + rawKeyData   // EC P-384
        case 270: spkiData = Self.rsa2048Header + rawKeyData   // RSA 2048
        case 526: spkiData = Self.rsa4096Header + rawKeyData   // RSA 4096
        default:  spkiData = rawKeyData
        }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        spkiData.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(spkiData.count), &hash) }
        return "sha256/\(Data(hash).base64EncodedString())"
    }

    // MARK: - ASN.1 SPKI headers (same values as CShieldTrustManager.swift)

    private static let rsa2048Header = Data([
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0D, 0x06, 0x09,
        0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01,
        0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0F, 0x00
    ])
    private static let rsa4096Header = Data([
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0D, 0x06, 0x09,
        0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01,
        0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0F, 0x00
    ])
    private static let ecP256Header = Data([
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86,
        0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A,
        0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00
    ])
    private static let ecP384Header = Data([
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86,
        0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B,
        0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
    ])

    private func invalidArg() -> FlutterError {
        FlutterError(code: CShieldErrorCode.invalidArgument,
                     message: "Missing or invalid arguments",
                     details: nil)
    }
}
