package com.pavelclaudiustefan.flutter_snapchat

import android.app.Activity
import android.content.Context
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import androidx.annotation.NonNull
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import com.snapchat.client.BuildConfig
import com.snapchat.kit.sdk.SnapCreative
import com.snapchat.kit.sdk.SnapLogin
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragment
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragmentSearchMode
import com.snapchat.kit.sdk.core.controller.LoginStateController
import com.snapchat.kit.sdk.creative.api.SnapCreativeKitApi
import com.snapchat.kit.sdk.creative.exceptions.SnapMediaSizeException
import com.snapchat.kit.sdk.creative.exceptions.SnapStickerSizeException
import com.snapchat.kit.sdk.creative.exceptions.SnapVideoLengthException
import com.snapchat.kit.sdk.creative.media.SnapMediaFactory
import com.snapchat.kit.sdk.creative.media.SnapPhotoFile
import com.snapchat.kit.sdk.creative.media.SnapSticker
import com.snapchat.kit.sdk.creative.media.SnapVideoFile
import com.snapchat.kit.sdk.creative.models.SnapContent
import com.snapchat.kit.sdk.creative.models.SnapLiveCameraContent
import com.snapchat.kit.sdk.creative.models.SnapPhotoContent
import com.snapchat.kit.sdk.creative.models.SnapVideoContent
import com.snapchat.kit.sdk.login.models.UserDataResponse
import com.snapchat.kit.sdk.login.networking.FetchUserDataCallback
import com.snapchat.kit.sdk.util.SnapUtils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.*


/** FlutterSnapchatPlugin */
class FlutterSnapchatPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {

  private lateinit var channel : MethodChannel

  private lateinit var _activity: Activity
  private lateinit var _context: Context
  private lateinit var _result: Result

  private var creativeApi: SnapCreativeKitApi? = null
  private var mediaFactory: SnapMediaFactory? = null

  private var bitmojiFragment: BitmojiFragment? = null

  private var onLoginStateChangedListener = object: LoginStateController.OnLoginStateChangedListener {
    override fun onLoginSucceeded() {
      _result.success("Login success")
    }

    override fun onLoginFailed() {
      _result.error("LoginError", "Error logging in", null)
    }

    override fun onLogout() {
      _result.success("Logout success")
    }
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    flutterPluginBinding
            .platformViewRegistry
            .registerViewFactory(
                    "com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker",
                    BitmojiPickerFactory(flutterPluginBinding.binaryMessenger))

    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_snapchat")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "login" -> {
        this._result = result
        SnapLogin.getLoginStateController(_activity).addOnLoginStateChangedListener(onLoginStateChangedListener)
        SnapLogin.getAuthTokenManager(_activity).startTokenGrant()
      }
      "getUser" -> {
        val query = "{me{externalId, displayName, bitmoji{selfie}}}"
        SnapLogin.fetchUserData(_activity, query, null, object : FetchUserDataCallback {
          override fun onSuccess(userDataResponse: UserDataResponse?) {
            if (userDataResponse == null || userDataResponse.data == null) {
              return
            }
            val meData = userDataResponse.data.me
            if (meData == null) {
              result.error("GetUserError", "Me data is null", null)
              return
            }
            val res: MutableList<String> = ArrayList()
            res.add(meData.externalId)
            res.add(meData.displayName)
            res.add(meData.bitmojiData.selfie)
            result.success(res)
          }

          override fun onFailure(isNetworkError: Boolean, statusCode: Int) {
            if (isNetworkError) {
              result.error("NetworkGetUserError", "Network Error", statusCode)
            } else {
              result.error("UnknownGetUserError", "Unknown Error", statusCode)
            }
          }
        })
      }
      "logout" -> {
        this._result = result
        SnapLogin.getAuthTokenManager(_activity).clearToken()
      }
      "send" -> {
        initCreativeApi()
        _result = result
        val type: String? = call.argument("mediaType")
        val path: String? = call.argument("mediaUrl")

        if (path == null) {
          _result.error("SendError", "Null path", null)
          return
        }

        val content: SnapContent =
                when (type) {
                  "photo" -> getImage(path)
                  "video" -> getVideo(path)
                  else -> getLive()
                } ?: return

        val caption: String? = call.argument("caption")
        if (caption != null) {
          content.captionText = caption
        }

        val attachment: String? = call.argument("attachment")
        if (attachment != null) {
          content.attachmentUrl = attachment
        }

        val stickerMap: Map<String, Any?>? = call.argument("sticker")
        if (stickerMap != null) {
          val stickerPath: String? = stickerMap["imageUrl"] as String?
          if (BuildConfig.DEBUG && stickerPath == null) {
            result.error("SendError", "Sticker path is null", null)
            error("Sticker path is null")
          }
          val sticker: SnapSticker = try {
            mediaFactory!!.getSnapStickerFromFile(File(stickerPath))
          } catch (e: SnapStickerSizeException) {
            _result.error("400", e.message, null)
            return
          }

          if (stickerMap["width"] != null) sticker.setWidthDp((stickerMap["width"] as Double?)!!.toFloat())
          if (stickerMap["height"] != null) sticker.setHeightDp((stickerMap["height"] as Double?)!!.toFloat())
          if (stickerMap["x"] != null) sticker.setPosX((stickerMap["x"] as Double?)!!.toFloat())
          if (stickerMap["y"] != null) sticker.setPosY((stickerMap["y"] as Double?)!!.toFloat())
          if (stickerMap["rotation"] != null) sticker.setRotationDegreesClockwise((stickerMap["rotation"] as Double?)!!.toFloat())

          content.snapSticker = sticker
        }
        creativeApi!!.send(content)
      }
      "isInstalled" -> result.success(SnapUtils.isSnapchatInstalled(_activity.packageManager, "com.snapchat.android"))
      "showBitmojisPicker" -> {
        val id = 0x123456

        val topPadding = call.argument<Int>("topPadding")
        val friendUserId: String? = call.argument("friendUserId")

//        val vParams: ViewGroup.LayoutParams = ViewGroup.LayoutParams(
//                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
//        )

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

//        val textView = TextView(_context)
//        textView.text = "Loading..."
//        container.addView(textView)

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

//        bitmojiFragment.setOnBitmojiSearchFocusChangeListener {
//          if (it) {
//            val toast = Toast(_context);
//            toast.setText("Focused")
//            Toast.makeText(_context, "", Toast.LENGTH_SHORT).show()
//            container.requestFocusFromTouch()
//            container.showSoftKeyboard()
//          } else {
//            container.hideSoftKeyboard()
//          }
//        }
        }

        val fm: FragmentManager = (_activity as FragmentActivity).supportFragmentManager
        fm.beginTransaction()
                .replace(id, bitmojiFragment!!)
                .addToBackStack("BitmojiPicker")
                .commitAllowingStateLoss()
      }
      "closeBitmojisPicker" -> {
        bitmojiFragment = null
        val fm: FragmentManager = (_activity as FragmentActivity).supportFragmentManager
        fm.popBackStack()

        result.success("Closed bitmoji picker")
      }
      "setBitmojiPickerQuery" -> {
        if (bitmojiFragment != null) {
          bitmojiFragment!!.setSearchText(call.argument("query"), BitmojiFragmentSearchMode.SEARCH_RESULT_ONLY)
          result.success("Search text updated")
        } else {
          result.error("BitmojiNotInitialized", "Bitmoji picker is not open", null)
        }
      }
      "getPlatformVersion" -> result.success("Android " + Build.VERSION.RELEASE)
      else -> result.notImplemented()
    }
  }

  private fun View.showSoftKeyboard(force: Boolean = false) {
    val inputMethodManager =
            context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
    if (force) {
      inputMethodManager.toggleSoftInput(
              InputMethodManager.SHOW_FORCED,
              InputMethodManager.HIDE_IMPLICIT_ONLY
      )
    }

    inputMethodManager.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT)
  }

  private fun View.hideSoftKeyboard(force: Boolean = false) {
    val inputMethodManager =
            context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
    if (force) {
      inputMethodManager.toggleSoftInput(
              InputMethodManager.SHOW_FORCED,
              InputMethodManager.HIDE_IMPLICIT_ONLY
      )
    }
    
    inputMethodManager.hideSoftInputFromWindow(this.windowToken, InputMethodManager.HIDE_IMPLICIT_ONLY)
  }

  private fun initCreativeApi() {
    if (creativeApi == null) creativeApi = SnapCreative.getApi(_activity)
    if (mediaFactory == null) mediaFactory = SnapCreative.getMediaFactory(_activity)
  }

  private fun getImage(path: String): SnapPhotoContent? {
    val photoFile: SnapPhotoFile = try {
      mediaFactory!!.getSnapPhotoFromFile(File(path))
    } catch (e: SnapMediaSizeException) {
      _result.error("400", e.message, null)
      return null
    }
    return SnapPhotoContent(photoFile)
  }

  private fun getVideo(path: String): SnapVideoContent? {
    val videoFile: SnapVideoFile = try {
      mediaFactory!!.getSnapVideoFromFile(File(path))
    } catch (e: SnapMediaSizeException) {
      _result.error("400", e.message, null)
      return null
    } catch (e: SnapVideoLengthException) {
      _result.error("400", e.message, null)
      return null
    }
    return SnapVideoContent(videoFile)
  }

  private fun getLive(): SnapLiveCameraContent {
    return SnapLiveCameraContent()
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    _activity = binding.activity
    _context = binding.activity.applicationContext
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    _activity = binding.activity
    _context = binding.activity.applicationContext
  }

  override fun onDetachedFromActivity() {}
}
