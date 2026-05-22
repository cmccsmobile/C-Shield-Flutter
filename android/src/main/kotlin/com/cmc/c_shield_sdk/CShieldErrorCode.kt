package com.cmc.c_shield_sdk

internal object CShieldErrorCode {
    const val AIP_MISSING_HEADER    = "aip_missing_header"
    const val AIP_TIMESTAMP_EXPIRED = "aip_timestamp_expired"
    const val AIP_INVALID_SIGNATURE = "aip_invalid_signature"
    const val AIP_SIGNING_FAILED    = "aip_signing_failed"
    const val AIP_PROXY_CA          = "aip_proxy_ca"
    const val SSL_NOT_CONFIGURED    = "ssl_not_configured"
    const val SSL_PIN_MISMATCH      = "ssl_pin_mismatch"
    const val RASP_CHECKER_DISPOSED = "rasp_checker_disposed"
    const val NOT_INITIALIZED       = "not_initialized"
    const val INVALID_ARGUMENT      = "invalid_argument"
    const val NATIVE_ERROR          = "native_error"
}
