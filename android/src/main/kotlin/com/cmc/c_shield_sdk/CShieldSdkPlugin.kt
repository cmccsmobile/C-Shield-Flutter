package com.cmc.c_shield_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.cmc.c_shield_sdk.bridges.AipBridge
import com.cmc.c_shield_sdk.bridges.RaspBridge
import com.cmc.c_shield_sdk.bridges.SslBridge
import com.cmc.c_shield_sdk.streams.RaspEventStreamHandler
import com.cmc.c_shield_sdk.streams.ThreatEventStreamHandler
import com.example.c_shield_sdk.CShieldSDK
import com.example.c_shield_sdk.loadAppThreat.LoadAppThreatListener
import com.example.c_shield_sdk.loadAppThreat.LoadAppThreatReaction
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class CShieldSdkPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var raspEventChannel: EventChannel
    private lateinit var threatEventChannel: EventChannel
    private lateinit var context: Context

    private lateinit var raspBridge: RaspBridge
    private lateinit var sslBridge: SslBridge
    private lateinit var aipBridge: AipBridge
    private lateinit var threatStreamHandler: ThreatEventStreamHandler

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        val raspStreamHandler = RaspEventStreamHandler()
        threatStreamHandler = ThreatEventStreamHandler()

        channel = MethodChannel(binding.binaryMessenger, "c_shield_sdk")
        raspEventChannel = EventChannel(binding.binaryMessenger, "c_shield_sdk/rasp_events")
        threatEventChannel = EventChannel(binding.binaryMessenger, "c_shield_sdk/threat_events")

        raspBridge = RaspBridge(context, raspStreamHandler)
        sslBridge = SslBridge()
        aipBridge = AipBridge(context)

        channel.setMethodCallHandler(this)
        raspEventChannel.setStreamHandler(raspStreamHandler)
        threatEventChannel.setStreamHandler(threatStreamHandler)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when {
            call.method == "sdk.initialize" -> {
                // Reaction = what shows on screen. Flutter can only reach the
                // built-in popup (with optional title/description) or None;
                // CustomActivity is a native-only branch that never crosses the
                // channel. The kill itself is not affected by any of this.
                val reaction = when (call.argument<String>("loadAppThreatReaction")) {
                    "none" -> LoadAppThreatReaction.None
                    else -> {
                        val popup = call.argument<Map<String, Any?>>("loadAppThreatPopup")
                        LoadAppThreatReaction.DefaultPopup(
                            popup?.get("title") as? String,
                            popup?.get("description") as? String,
                        )
                    }
                }

                // Dart can opt into being notified of load-time threats. The
                // notification is best-effort — the native loader kills the
                // process right after this returns — so it is for logging only.
                val notifyDart = call.argument<Boolean>("handleLoadAppThreat") ?: false
                val listener = if (notifyDart) {
                    object : LoadAppThreatListener {
                        override fun onLoadAppThreatDetected(threatType: Int) {
                            threatStreamHandler.emit(threatType)
                        }
                    }
                } else null

                Thread {
                    try {
                        CShieldSDK.initialize(context, reaction, listener)
                        mainHandler.post {
                            result.success(null)
                        }
                    } catch (e: Throwable) {
                        mainHandler.post {
                            result.error(
                                CShieldErrorCode.NATIVE_ERROR,
                                e.message, null
                            )
                        }
                    }
                }.start()
            }

            call.method.startsWith("rasp.") -> raspBridge.handle(call, result)
            call.method.startsWith("ssl.") -> sslBridge.handle(call, result)
            call.method.startsWith("aip.") -> aipBridge.handle(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        raspEventChannel.setStreamHandler(null)
        threatEventChannel.setStreamHandler(null)
        raspBridge.disposeAll()
    }
}
