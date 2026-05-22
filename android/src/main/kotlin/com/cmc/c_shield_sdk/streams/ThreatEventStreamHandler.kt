//package com.cmc.c_shield_sdk.streams
//
//import android.os.Handler
//import android.os.Looper
//import com.example.c_shield_sdk.CShieldSDK
//import com.example.c_shield_sdk.LoadAppThreatListener
//import io.flutter.plugin.common.EventChannel
//
//class ThreatEventStreamHandler : EventChannel.StreamHandler {
//
//    private val mainHandler = Handler(Looper.getMainLooper())
//
//    @Volatile
//    private var sink: EventChannel.EventSink? = null
//
//    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
//        sink = events
//        CShieldSDK.setThreatListener(object : LoadAppThreatListener {
//            override fun onLoadAppThreatDetected(threatType: Int) {
//                mainHandler.post {
//                    sink?.success(mapOf("threatType" to threatType))
//                }
//            }
//        })
//    }
//
//    override fun onCancel(arguments: Any?) {
//        CShieldSDK.setThreatListener(null)
//        sink = null
//    }
//}
