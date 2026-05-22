package com.cmc.c_shield_sdk.bridges

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.cmc.c_shield_sdk.CShieldErrorCode
import com.example.c_shield_sdk.aip.api.AIPCore
import com.example.c_shield_sdk.utils.CShieldException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.security.MessageDigest

class AipBridge(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            // Standalone
            "aip.sign"          -> handleSign(call, result)
            "aip.verify"        -> handleVerify(call, result)
            "aip.normalizeBody" -> handleNormalizeBody(call, result)
            // Interceptor-style
            "aip.signRequest"   -> handleSignRequest(call, result)
            "aip.verifyResponse" -> handleVerifyResponse(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleSign(call: MethodCall, result: Result) {
        val payload = call.argument<String>("payload")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "payload required", null)

        Thread {
            try {
                val signature = AIPCore.sign(context, payload)
                mainHandler.post { result.success(signature) }
            } catch (e: CShieldException) {
                mainHandler.post { result.error(CShieldErrorCode.AIP_PROXY_CA, e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error(CShieldErrorCode.AIP_SIGNING_FAILED, e.message, null) }
            }
        }.start()
    }

    private fun handleVerify(call: MethodCall, result: Result) {
        val payload = call.argument<String>("payload")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "payload required", null)
        val signature = call.argument<String>("signature")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "signature required", null)

        Thread {
            try {
                val valid = AIPCore.verifySign(context, payload, signature)
                mainHandler.post {
                    if (valid) result.success(null)
                    else result.error(CShieldErrorCode.AIP_INVALID_SIGNATURE, "Signature verification failed", null)
                }
            } catch (e: CShieldException) {
                mainHandler.post { result.error(CShieldErrorCode.AIP_PROXY_CA, e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null) }
            }
        }.start()
    }

    private fun handleSignRequest(call: MethodCall, result: Result) {
        val method = call.argument<String>("method")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "method required", null)
        val path = call.argument<String>("path")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "path required", null)
        val body = call.argument<ByteArray>("body") ?: ByteArray(0)
        val contentType = call.argument<String>("contentType") ?: "application/json"

        Thread {
            try {
                val request = Request.Builder()
                    .url("https://placeholder.com$path")
                    .method(method, body.toRequestBody(contentType.toMediaTypeOrNull()))
                    .build()
                val bodyResult = AIPCore.normalizeBodyForSigning(request)
                val timestamp = System.currentTimeMillis() / 1000
                val payload = "$method.$path.$timestamp.${bodyResult.hash}"
                val signature = AIPCore.sign(context, payload)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "cs-timestamp" to timestamp.toString(),
                            "cs-signature" to signature,
                        )
                    )
                }
            } catch (e: CShieldException) {
                mainHandler.post { result.error(CShieldErrorCode.AIP_PROXY_CA, e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error(CShieldErrorCode.AIP_SIGNING_FAILED, e.message, null) }
            }
        }.start()
    }

    private fun handleVerifyResponse(call: MethodCall, result: Result) {
        val statusCode = call.argument<Int>("statusCode")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "statusCode required", null)
        val path = call.argument<String>("path")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "path required", null)
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        val body = call.argument<ByteArray>("body") ?: ByteArray(0)

        val timestamp = headers["cs-timestamp"]
            ?: return result.error(CShieldErrorCode.AIP_MISSING_HEADER, "cs-timestamp missing", null)
        val signature = headers["cs-signature"]
            ?: return result.error(CShieldErrorCode.AIP_MISSING_HEADER, "cs-signature missing", null)

        Thread {
            try {
                val bodyHash = body.sha256Hex()
                val payload = "$statusCode.$path.$timestamp.$bodyHash"
                val valid = AIPCore.verifySign(context, payload, signature)
                mainHandler.post {
                    if (valid) result.success(null)
                    else result.error(CShieldErrorCode.AIP_INVALID_SIGNATURE, "Response signature verification failed", null)
                }
            } catch (e: CShieldException) {
                mainHandler.post { result.error(CShieldErrorCode.AIP_PROXY_CA, e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null) }
            }
        }.start()
    }

    private fun handleNormalizeBody(call: MethodCall, result: Result) {
        val contentType = call.argument<String>("contentType") ?: "application/json"
        val body = call.argument<ByteArray>("body") ?: ByteArray(0)

        Thread {
            try {
                val request = Request.Builder()
                    .url("https://placeholder.com/")
                    .post(body.toRequestBody(contentType.toMediaTypeOrNull()))
                    .build()
                val bodyResult = AIPCore.normalizeBodyForSigning(request)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "normalizedString" to bodyResult.normalizedString,
                            "sizeInBytes" to bodyResult.sizeInBytes,
                            "hash" to bodyResult.hash,
                        )
                    )
                }
            } catch (e: Exception) {
                mainHandler.post { result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null) }
            }
        }.start()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun ByteArray.sha256Hex(): String {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(this).joinToString("") { "%02x".format(it) }
    }
}
