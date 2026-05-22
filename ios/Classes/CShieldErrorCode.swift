import Foundation

internal enum CShieldErrorCode {
    static let aipMissingHeader    = "aip_missing_header"
    static let aipTimestampExpired = "aip_timestamp_expired"
    static let aipInvalidSignature = "aip_invalid_signature"
    static let aipSigningFailed    = "aip_signing_failed"
    static let aipProxyCA          = "aip_proxy_ca"
    static let sslNotConfigured    = "ssl_not_configured"
    static let sslPinMismatch      = "ssl_pin_mismatch"
    static let raspCheckerDisposed = "rasp_checker_disposed"
    static let notInitialized      = "not_initialized"
    static let invalidArgument     = "invalid_argument"
    static let nativeError         = "native_error"
}
