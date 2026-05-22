package com.cmc.c_shield_sdk.bridges

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.cmc.c_shield_sdk.CShieldErrorCode
import com.cmc.c_shield_sdk.streams.RaspEventStreamHandler
import com.example.c_shield_sdk.rasp.api.RASPChecker
import com.example.c_shield_sdk.rasp.api.ThreatDetectedAction
import com.example.c_shield_sdk.rasp.api.config.RASPConfig
import com.example.c_shield_sdk.rasp.api.config.ThreatActionConfig
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ConcurrentHashMap

class RaspBridge(
    private val context: Context,
    val streamHandler: RaspEventStreamHandler,
) {
    private val checkers = ConcurrentHashMap<String, RASPChecker>()
    private val activeSubscriptions = ConcurrentHashMap<String, Boolean>()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "rasp.build" -> handleBuild(call, result)
            "rasp.setConfig" -> handleSetConfig(call, result)
            "rasp.quickCheck" -> handleQuickCheck(call, result)
            "rasp.subscribe" -> handleSubscribe(call, result)
            "rasp.cancelSubscribe" -> handleCancelSubscribe(call, result)
            "rasp.dispose" -> handleDispose(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleBuild(call: MethodCall, result: Result) {
        val flags = call.argument<Map<String, Boolean>>("flags") ?: emptyMap()
        Thread {
            try {
                val checkerId = java.util.UUID.randomUUID().toString()
                val checker = RASPChecker.Builder(
                    context = context,
                    checkDebugger = flags["checkDebugger"] ?: true,
                    rootDetector = flags["rootDetector"] ?: true,
                    tampering = flags["tampering"] ?: true,
                    emulator = flags["emulator"] ?: true,
                    deviceSecurityState = flags["deviceSecurityState"] ?: true,
                ).build()
                checkers[checkerId] = checker
                mainHandler.post { result.success(checkerId) }
            } catch (e: Exception) {
                mainHandler.post { result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null) }
            }
        }.start()
    }

    private fun handleSetConfig(call: MethodCall, result: Result) {
        val checkerId = call.argument<String>("checkerId")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "checkerId required", null)
        val checker = checkers[checkerId]
            ?: return result.error(CShieldErrorCode.RASP_CHECKER_DISPOSED, "RASPChecker not found", null)

        val configMap = call.argument<Map<String, Any>>("config") ?: emptyMap()
        val trustedStores = (configMap["trustedStores"] as? List<*>)
            ?.mapNotNull { it as? String }
            ?.toTypedArray()

        val actionConfig = (configMap["threatActionConfig"] as? Map<*, *>)?.let {
            buildActionConfig(it)
        }

        try {
            checker.setRASPConfig(
                RASPConfig(
                    trustedStores = trustedStores,
                    threatActionConfig = actionConfig,
                )
            )
            result.success(null)
        } catch (e: Exception) {
            result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null)
        }
    }

    private fun handleQuickCheck(call: MethodCall, result: Result) {
        val checkerId = call.argument<String>("checkerId")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "checkerId required", null)
        val checker = checkers[checkerId]
            ?: return result.error(CShieldErrorCode.RASP_CHECKER_DISPOSED, "RASPChecker not found", null)

        Thread {
            try {
                val raspResult = checker.quickCheck()
                // RASPResult is a sealed class of data objects — simpleName gives the object name.
                val key = raspResult::class.simpleName ?: "Unknown"
                mainHandler.post { result.success(key) }
            } catch (e: Exception) {
                mainHandler.post { result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null) }
            }
        }.start()
    }

    private fun handleSubscribe(call: MethodCall, result: Result) {
        val checkerId = call.argument<String>("checkerId")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "checkerId required", null)
        val subscriptionId = call.argument<String>("subscriptionId")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "subscriptionId required", null)
        val detail = call.argument<Boolean>("detail") ?: false
        val autoPopup = call.argument<Boolean>("automaticallyShowPopup") ?: true

        val checker = checkers[checkerId]
            ?: return result.error(CShieldErrorCode.RASP_CHECKER_DISPOSED, "RASPChecker not found", null)

        // Return immediately so Dart can start consuming EventChannel events.
        result.success(null)
        activeSubscriptions[subscriptionId] = true

        Thread {
            try {
                checker.subscribe(
                    detail = detail,
                    automaticallyShowPopup = autoPopup,
                ) { raspResult ->
                    if (activeSubscriptions[subscriptionId] != true) return@subscribe
                    // RASPCheckType is an interface; implementations are enums — use .name.
                    val checkTypeKey = (raspResult.checkType as? Enum<*>)?.name
                        ?: raspResult.checkType.toString()
                    val actionKey = when (raspResult.threatAction) {
                        ThreatDetectedAction.KillApp -> "KillApp"
                        ThreatDetectedAction.NotifyApp -> "NotifyApp"
                        else -> "NotifyApp"
                    }
                    mainHandler.post {
                        streamHandler.sendResult(
                            subscriptionId,
                            checkTypeKey,
                            raspResult.vulnerable,
                            actionKey,
                        )
                    }
                }
                mainHandler.post { streamHandler.sendComplete(subscriptionId) }
            } catch (e: Exception) {
                mainHandler.post {
                    streamHandler.sendError(subscriptionId, CShieldErrorCode.NATIVE_ERROR, e.message ?: "subscribe failed")
                }
            } finally {
                activeSubscriptions.remove(subscriptionId)
            }
        }.start()
    }

    private fun handleCancelSubscribe(call: MethodCall, result: Result) {
        val subscriptionId = call.argument<String>("subscriptionId")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "subscriptionId required", null)
        activeSubscriptions.remove(subscriptionId)
        result.success(null)
    }

    private fun handleDispose(call: MethodCall, result: Result) {
        val checkerId = call.argument<String>("checkerId")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "checkerId required", null)
        checkers.remove(checkerId)
        result.success(null)
    }

    fun disposeAll() {
        activeSubscriptions.clear()
        checkers.clear()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun buildActionConfig(map: Map<*, *>): ThreatActionConfig {
        fun action(key: String) = when (map[key] as? String) {
            "KillApp" -> ThreatDetectedAction.KillApp
            else -> ThreatDetectedAction.NotifyApp
        }
        return ThreatActionConfig(
            debuggerDetectedAction = action("debuggerDetectedAction"),
            rootDetectedAction = action("rootDetectedAction"),
            tamperingDetectedAction = action("tamperingDetectedAction"),
            emulatorDetectedAction = action("emulatorDetectedAction"),
            deviceSecurityStateUnsafeDetectedAction = action("deviceSecurityStateUnsafeDetectedAction"),
            userCADetectedAction = action("userCADetectedAction"),
        )
    }
}
