package com.cmc.c_shield_sdk.bridges

import android.util.Base64
import com.cmc.c_shield_sdk.CShieldErrorCode
import com.example.c_shield_sdk.aip.pinning.CShieldSSL
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayInputStream
import java.security.cert.CertificateException
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate

class SslBridge {

    fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "ssl.configure"          -> handleConfigure(call, result)
            "ssl.updatePins"         -> handleUpdatePins(call, result)
            "ssl.isConfigured"       -> result.success(CShieldSSL.isConfigured())
            "ssl.checkServerTrusted" -> handleCheckServerTrusted(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleConfigure(call: MethodCall, result: Result) {
        val pins = call.argument<List<String>>("pins")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "pins required", null)
        val hostname = call.argument<String>("hostname")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "hostname required", null)
        try {
            CShieldSSL.configure(pins = pins, hostname = hostname)
            result.success(null)
        } catch (e: Exception) {
            result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null)
        }
    }

    private fun handleUpdatePins(call: MethodCall, result: Result) {
        val pins = call.argument<List<String>>("pins")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "pins required", null)
        val hostname = call.argument<String>("hostname")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "hostname required", null)
        try {
            CShieldSSL.updatePins(pins = pins, hostname = hostname)
            result.success(null)
        } catch (e: IllegalStateException) {
            result.error(CShieldErrorCode.SSL_NOT_CONFIGURED, e.message, null)
        } catch (e: Exception) {
            result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null)
        }
    }

    /**
     * Verifies a DER-encoded certificate (base64) using [CShieldSSL.getTrustManager],
     * which performs system CA validation + SPKI pin check.
     *
     * Flutter equivalent of CShieldTrustManager.checkServerTrusted() on Android.
     */
    private fun handleCheckServerTrusted(call: MethodCall, result: Result) {
        val certDerBase64 = call.argument<String>("certDer")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "certDer required", null)
        val host = call.argument<String>("host") ?: ""

        if (!CShieldSSL.isConfigured()) {
            return result.error(CShieldErrorCode.SSL_NOT_CONFIGURED, "CShieldSSL not configured", null)
        }

        try {
            val certBytes = Base64.decode(certDerBase64, Base64.DEFAULT)
            val factory = CertificateFactory.getInstance("X.509")
            val cert = factory.generateCertificate(ByteArrayInputStream(certBytes)) as X509Certificate

            // CShieldTrustManager.checkServerTrusted performs:
            //   1. System CA validation via X509TrustManagerExtensions (blocks user-installed CAs)
            //   2. SPKI pin verification against configured pins
            CShieldSSL.getTrustManager().checkServerTrusted(arrayOf(cert), "RSA")
            result.success(true)
        } catch (e: CertificateException) {
            result.success(false)
        } catch (e: Exception) {
            result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null)
        }
    }
}
