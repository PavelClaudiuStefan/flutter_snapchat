package com.pavelclaudiustefan.flutter_snapchat

import android.app.Activity
import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragment
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView


class BitmojiPicker internal constructor(context: Context?, messenger: BinaryMessenger?, id: Int) : PlatformView, MethodCallHandler, ActivityAware {
    private val _id = id

    private val containerView: FrameLayout = FrameLayout(context!!)

    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker_$id")

    private lateinit var _activity: Activity

    init {
//        containerView = TextView(context)
        methodChannel.setMethodCallHandler(this)
    }

    override fun getView(): View {
        return containerView
    }

    override fun onMethodCall(methodCall: MethodCall, result: MethodChannel.Result) {
        when (methodCall.method) {
            "showBitmojis" -> {
//                val id = 0x123456
//                val vParams: ViewGroup.LayoutParams = ViewGroup.LayoutParams(
//                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
//                )
////                val container = FrameLayout(_activity)
//                containerView.layoutParams = vParams
//                containerView.id = _id
//                _activity.addContentView(containerView, vParams)
//
//                val fm: FragmentManager = (_activity as FragmentActivity).supportFragmentManager
//                fm.beginTransaction()
//                        .replace(_id, BitmojiFragment())
//                        .commitAllowingStateLoss()
            }
//            "setQuery" -> setText(methodCall, result)
            else -> result.notImplemented()
        }
    }

//    private fun setText(methodCall: MethodCall, result: MethodChannel.Result) {
//        val text = methodCall.arguments as String
//        containerView.text = text
//        result.success(null)
//    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        _activity = binding.activity

        print("\n\nonAttachedToActivity\n\n")

        val vParams: ViewGroup.LayoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        )
//                val container = FrameLayout(_activity)
        containerView.layoutParams = vParams
        containerView.id = _id
        _activity.addContentView(containerView, vParams)

        val fm: FragmentManager = (_activity as FragmentActivity).supportFragmentManager
        fm.beginTransaction()
                .replace(_id, BitmojiFragment())
                .commitAllowingStateLoss()
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        _activity = binding.activity
    }

    override fun onDetachedFromActivity() {}

    override fun dispose() {}
}