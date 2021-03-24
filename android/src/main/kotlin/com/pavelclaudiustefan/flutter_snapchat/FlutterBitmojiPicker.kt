package com.pavelclaudiustefan.flutter_snapchat

import android.content.Context
import android.view.View
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView

class FlutterBitmojiPicker internal constructor(context: Context?, messenger: BinaryMessenger?, id: Int) : PlatformView, MethodCallHandler {
    private val textView: TextView
    private val methodChannel: MethodChannel

    override fun getView(): View {
        return textView
    }

    override fun onMethodCall(methodCall: MethodCall, result: MethodChannel.Result) {
        when (methodCall.method) {
            "setText" -> setText(methodCall, result)
            else -> result.notImplemented()
        }
    }

    private fun setText(methodCall: MethodCall, result: MethodChannel.Result) {
        val text = methodCall.arguments as String
        textView.text = text
        result.success(null)
    }

    override fun dispose() {}

    init {
        textView = TextView(context)
        methodChannel = MethodChannel(messenger, "com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker$id")
        methodChannel.setMethodCallHandler(this)
    }
}