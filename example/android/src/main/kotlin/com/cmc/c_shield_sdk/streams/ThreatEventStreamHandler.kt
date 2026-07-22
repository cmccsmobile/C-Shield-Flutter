package com.cmc.c_shield_sdk.streams

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges [com.example.c_shield_sdk.LoadAppThreatListener] callbacks to Dart.
 *
 * Best-effort by design: the native loader tears the process down shortly after
 * the callback returns, so Dart may or may not get to act on the event. Use it
 * for local logging and diagnostics, never as the mechanism that displays the
 * threat popup — that is the native side's job precisely because it is the only
 * layer guaranteed to still be alive.
 *
 * Load-time threats can also fire before Dart has subscribed; events with no
 * sink are buffered and replayed on the next [onListen].
 */
class ThreatEventStreamHandler : EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())

    // Only touched on the main thread.
    private var sink: EventChannel.EventSink? = null
    private val pending = ArrayDeque<Int>()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        while (pending.isNotEmpty()) {
            events.success(mapOf("threatType" to pending.removeFirst()))
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /** Called from a native thread — hops to main before touching the sink. */
    fun emit(threatType: Int) {
        mainHandler.post {
            val s = sink
            if (s == null) pending.addLast(threatType) else s.success(
                mapOf("threatType" to threatType)
            )
        }
    }
}
