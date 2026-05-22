package com.cmc.c_shield_sdk.streams

import io.flutter.plugin.common.EventChannel

class RaspEventStreamHandler : EventChannel.StreamHandler {

    @Volatile
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun sendResult(subscriptionId: String, checkType: String, vulnerable: Boolean, threatAction: String) {
        sink?.success(
            mapOf(
                "subscriptionId" to subscriptionId,
                "type" to "result",
                "data" to mapOf(
                    "checkType" to checkType,
                    "vulnerable" to vulnerable,
                    "threatAction" to threatAction,
                ),
            )
        )
    }

    fun sendComplete(subscriptionId: String) {
        sink?.success(
            mapOf(
                "subscriptionId" to subscriptionId,
                "type" to "complete",
            )
        )
    }

    fun sendError(subscriptionId: String, code: String, message: String) {
        // Use success() to keep the channel alive for other subscribers.
        sink?.success(
            mapOf(
                "subscriptionId" to subscriptionId,
                "type" to "error",
                "code" to code,
                "message" to message,
            )
        )
    }
}
