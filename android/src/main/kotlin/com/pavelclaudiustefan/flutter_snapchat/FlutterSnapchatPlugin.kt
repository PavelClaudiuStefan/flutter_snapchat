package com.pavelclaudiustefan.flutter_snapchat

import android.app.Activity
import android.os.Build
import androidx.annotation.NonNull
import com.snapchat.kit.sdk.SnapCreative
import com.snapchat.kit.sdk.SnapLogin
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

//  private lateinit var context: Context
  private lateinit var _activity: Activity
  private lateinit var _result: Result

  private var creativeApi: SnapCreativeKitApi? = null
  private var mediaFactory: SnapMediaFactory? = null

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
//            mediaFactory!!.getSnapStickerFromFile(File(stickerPath!!))
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
      "getPlatformVersion" -> result.success("Android " + Build.VERSION.RELEASE)
      else -> result.notImplemented()
    }
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
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

  override fun onDetachedFromActivity() {}
}
