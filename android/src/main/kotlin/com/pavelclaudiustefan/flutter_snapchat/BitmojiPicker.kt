package com.pavelclaudiustefan.flutter_snapchat

import android.app.Activity
import android.content.Context
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragment
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragmentSearchMode
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView


class BitmojiPicker internal constructor(context: Context?, messenger: BinaryMessenger?, id: Int) : PlatformView, MethodCallHandler, ActivityAware {
    private val _id = id

    private var containerView: FrameLayout = FrameLayout(context!!)

    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker_$id")

    private lateinit var _activity: Activity
    private var _context: Context? = context

    private var bitmojiFragment: BitmojiFragment? = null

    init {
        val vParams: ViewGroup.LayoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        )

        containerView.layoutParams = vParams
        containerView.id = _id

        bitmojiFragment = BitmojiFragment
                .builder()
                .withShowSearchBar(false)
                .build();

        val fm = (_activity as FragmentActivity).supportFragmentManager

        fm.beginTransaction()
                .add(containerView.id, bitmojiFragment!!)
                .commit()


        methodChannel.setMethodCallHandler(this)
    }

    override fun getView(): View {
        return containerView
    }

    override fun onMethodCall(methodCall: MethodCall, result: MethodChannel.Result) {
        when (methodCall.method) {
            "setupBitmojisPicker" -> {
                return

                val id = 0x123456

                val topPadding = methodCall.argument<Int>("topPadding")
                val friendUserId: String? = methodCall.argument("friendUserId")

                val bitmojiPickerWidth: Int = _activity.window.decorView.width
                val bitmojiPickerHeight: Int = if (topPadding != null) {
                    _activity.window.decorView.height - topPadding
                } else {
                    (_activity.window.decorView.height * 0.8).toInt()
                }

                val vParams = FrameLayout.LayoutParams(
                        bitmojiPickerWidth,  // Width in pixels
                        bitmojiPickerHeight,  // Height in pixels
                        Gravity.BOTTOM
                )

                val container = FrameLayout(_activity)
                container.layoutParams = vParams
                container.id = id

                _activity.addContentView(container, vParams)

                if (bitmojiFragment == null) {
                    bitmojiFragment = BitmojiFragment.builder().withShowSearchBar(false).build()

                    bitmojiFragment!!.setOnBitmojiSelectedListener { s, _ ->
                        result.success(mapOf(
                                Pair("type", "bitmoji_url"),
                                Pair("url", s),
                        ))
                        val fm: FragmentManager = (_activity as FragmentActivity).supportFragmentManager
                        fm.popBackStack()
                    }

                    if (!friendUserId.isNullOrBlank()) {
                        bitmojiFragment!!.setFriend(friendUserId)
                    }
                }

                val fm: FragmentManager = (_activity as FragmentActivity).supportFragmentManager
                fm.beginTransaction()
                        .replace(id, bitmojiFragment!!)
                        .addToBackStack("BitmojiPicker")
                        .commitAllowingStateLoss()
            }
            "setSearchText" -> setSearchText(methodCall, result)
            else -> result.notImplemented()
        }
    }

    private fun setSearchText(methodCall: MethodCall, result: MethodChannel.Result) {
        if (bitmojiFragment != null) {
            val searchText = methodCall.arguments as String
            bitmojiFragment!!.setSearchText(searchText, BitmojiFragmentSearchMode.SEARCH_RESULT_ONLY)
            result.success("Search text updated")
        } else {
            result.error("BitmojiNotInitialized", "Search text cannot be updated when bitmoji picker is not open", null)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        _activity = binding.activity

//        print("\n\nonAttachedToActivity\n\n")
//
//        val vParams: ViewGroup.LayoutParams = ViewGroup.LayoutParams(
//                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
//        )
////                val container = FrameLayout(_activity)
//        containerView.layoutParams = vParams
//        containerView.id = _id
//        _activity.addContentView(containerView, vParams)
//
//        val fm: FragmentManager = (_activity as FragmentActivity).supportFragmentManager
//        fm.beginTransaction()
//                .replace(_id, BitmojiFragment())
//                .commitAllowingStateLoss()
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        _activity = binding.activity
    }

    override fun onDetachedFromActivity() {}

    override fun dispose() {}
}