package com.pavelclaudiustefan.flutter_snapchat

import android.app.Activity
import android.content.Context
import android.os.Build
import androidx.annotation.NonNull
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import com.snapchat.client.BuildConfig
import com.snapchat.kit.sdk.SnapCreative
import com.snapchat.kit.sdk.SnapLogin
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
import java.util.ArrayList


/** FlutterSnapchatPlugin */
class FlutterSnapchatPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {

  private lateinit var _channel : MethodChannel

  private lateinit var _activity: Activity
  private lateinit var _context: Context
  private lateinit var _result: Result

  private var _creativeApi: SnapCreativeKitApi? = null
  private var _mediaFactory: SnapMediaFactory? = null

  private var _bitmojiPickerBottomSheet: BitmojiPickerBottomSheet? = null

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
    _channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_snapchat")
    _channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    this._result = result

    when (call.method) {
      "isUserLoggedIn" -> isUserLoggedIn(result)
      "login" -> login()
      "getUser" -> getUser(result)
      "logout" -> logout()
      "share" -> share(call, result)
      "isInstalled" -> isSnapchatInstalled(result)
      "showBitmojiPicker" -> showBitmojiPicker(call, result)
      "closeBitmojiPicker" -> closeBitmojiPicker(result)
      "setBitmojiPickerSearchText" -> setBitmojiPickerSearchText(call, result)
      "getPlatformVersion" -> result.success("Android " + Build.VERSION.RELEASE)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    _channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    _activity = binding.activity
    _context = binding.activity.applicationContext
    SnapLogin.getLoginStateController(_activity).addOnLoginStateChangedListener(onLoginStateChangedListener)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    SnapLogin.getLoginStateController(_activity).removeOnLoginStateChangedListener(onLoginStateChangedListener)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    _activity = binding.activity
    _context = binding.activity.applicationContext
    SnapLogin.getLoginStateController(_activity).addOnLoginStateChangedListener(onLoginStateChangedListener)
  }

  override fun onDetachedFromActivity() {
    SnapLogin.getLoginStateController(_activity).removeOnLoginStateChangedListener(onLoginStateChangedListener)
  }

  private fun isUserLoggedIn(@NonNull result: Result) {
    val isUserLoggedIn = SnapLogin.isUserLoggedIn(_activity)
    result.success(isUserLoggedIn)
  }

  private fun login() {
    SnapLogin.getAuthTokenManager(_activity).startTokenGrant()

    // result is sent using onLoginStateChangedListener callbacks
  }

  private fun getUser(@NonNull result: Result) {
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

  private fun logout() {
    SnapLogin.getAuthTokenManager(_activity).clearToken()

    // result is sent using onLoginStateChangedListener callbacks
  }

  private fun share(@NonNull call: MethodCall, @NonNull result: Result) {
    if (!SnapLogin.isUserLoggedIn(_activity)) {
      result.error("UserNotLoggedIn", "Cannot share to snapchat if user is not logged in", null)
      return
    }

    initCreativeApi()
    val type: String? = call.argument("mediaType")
    val mediaPath: String? = call.argument("mediaFilePath")

    if (mediaPath == null) {
      result.error("SendError", "Null media file path", null)
      return
    }

    val content: SnapContent =
            when (type) {
              "photo" -> getImage(mediaPath)
              "video" -> getVideo(mediaPath)
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
      val stickerPath: String? = stickerMap["imageFilePath"] as String?
      if (BuildConfig.DEBUG && stickerPath == null) {
        result.error("SendError", "Sticker image file path is null", null)
        return
      }
      val sticker: SnapSticker = try {
        _mediaFactory!!.getSnapStickerFromFile(File(stickerPath!!))
      } catch (e: SnapStickerSizeException) {
        result.error("400", e.message, null)
        return
      }

      if (stickerMap["width"] != null) sticker.setWidthDp((stickerMap["width"] as Double?)!!.toFloat())
      if (stickerMap["height"] != null) sticker.setHeightDp((stickerMap["height"] as Double?)!!.toFloat())
      if (stickerMap["x"] != null) sticker.setPosX((stickerMap["x"] as Double?)!!.toFloat())
      if (stickerMap["y"] != null) sticker.setPosY((stickerMap["y"] as Double?)!!.toFloat())
      if (stickerMap["rotation"] != null) sticker.setRotationDegreesClockwise((stickerMap["rotation"] as Double?)!!.toFloat())

      content.snapSticker = sticker
    }
    _creativeApi!!.send(content)
  }

  private fun isSnapchatInstalled(@NonNull result: Result) {
    result.success(SnapUtils.isSnapchatInstalled(_activity.packageManager, "com.snapchat.android"))
  }

  private fun showBitmojiPicker(@NonNull call: MethodCall, @NonNull result: Result) {
    if (!SnapLogin.isUserLoggedIn(_activity)) {
      result.error("UserNotLoggedIn", "Cannot show bitmoji picker if user is not logged in", null)
      return
    }

    val friendUserId: String? = call.argument("friendUserId")
    val isDarkTheme: Boolean = call.argument("isDarkTheme") ?: false
    val hasSearchBar: Boolean = call.argument("hasSearchBar") ?: true
    val hasSearchPills: Boolean = call.argument("hasSearchPills") ?: true

    _bitmojiPickerBottomSheet = BitmojiPickerBottomSheet.newInstance(
            hasSearchBar = hasSearchBar,
            hasSearchPills = hasSearchPills,
            isDarkTheme = isDarkTheme,
            friendUserId = friendUserId,
            onBitmojiClickedListener = {
              result.success(mapOf(
                      Pair("type", "bitmoji_url"),
                      Pair("url", it)
              ))
            }
    ) {
      _bitmojiPickerBottomSheet = null
      if (!it) {
        result.success("Closed bitmoji picker")
      }
    }

    val fragmentManager: FragmentManager = (_activity as FragmentActivity).supportFragmentManager
    _bitmojiPickerBottomSheet!!.show(fragmentManager, "bitmoji_picker_bottom_sheet")
  }

  private fun closeBitmojiPicker(@NonNull result: Result) {
    if (_bitmojiPickerBottomSheet != null) {
      _bitmojiPickerBottomSheet!!.dismiss()
      _bitmojiPickerBottomSheet = null
      result.success("Closed bitmoji picker")
    } else {
      result.error("NullBitmojiPicker", "Bitmoji picker is not opened", null)
    }
  }

  private fun setBitmojiPickerSearchText(@NonNull call: MethodCall, @NonNull result: Result) {
    if (_bitmojiPickerBottomSheet != null) {
      _bitmojiPickerBottomSheet!!.setSearchText(call.argument("searchText"), BitmojiFragmentSearchMode.SEARCH_RESULT_ONLY)
      result.success("Search text updated")
    } else {
      result.error("NullBitmojiPicker", "Cannot set search text when bitmoji picker is not opened", null)
    }
  }

  private fun initCreativeApi() {
    if (_creativeApi == null) _creativeApi = SnapCreative.getApi(_activity)
    if (_mediaFactory == null) _mediaFactory = SnapCreative.getMediaFactory(_activity)
  }

  private fun getImage(path: String): SnapPhotoContent? {
    val photoFile: SnapPhotoFile = try {
      _mediaFactory!!.getSnapPhotoFromFile(File(path))
    } catch (e: SnapMediaSizeException) {
      _result.error("400", e.message, null)
      return null
    }
    return SnapPhotoContent(photoFile)
  }

  private fun getVideo(path: String): SnapVideoContent? {
    val videoFile: SnapVideoFile = try {
      _mediaFactory!!.getSnapVideoFromFile(File(path))
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
}