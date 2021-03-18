package com.pavelclaudiustefan.flutter_snapchat

import android.app.Activity
import android.os.Build
import androidx.annotation.NonNull
import com.snapchat.kit.sdk.SnapLogin
import com.snapchat.kit.sdk.core.controller.LoginStateController
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
import java.util.*


/** FlutterSnapchatPlugin */
class FlutterSnapchatPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, LoginStateController.OnLoginStateChangedListener {

  private lateinit var channel : MethodChannel

//  private lateinit var context: Context
  private lateinit var _activity: Activity
  private lateinit var _result: Result

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_snapchat")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "callLogin" -> {
        SnapLogin.getLoginStateController(_activity).addOnLoginStateChangedListener(this)
        SnapLogin.getAuthTokenManager(_activity).startTokenGrant()
        this._result = result
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
      "callLogout" -> {
        SnapLogin.getAuthTokenManager(_activity).clearToken()
        this._result = result
      }
      "isInstalled" -> result.success(SnapUtils.isSnapchatInstalled(_activity.packageManager, "com.snapchat.android"))
      "getPlatformVersion" -> result.success("Android " + Build.VERSION.RELEASE)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onLoginSucceeded() {
    this._result.success("Login Success")
  }

  override fun onLoginFailed() {
    this._result.error("LoginError", "Error Logging In", null)
  }

  override fun onLogout() {
    this._result.success("Logout Success")
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    _activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

  override fun onDetachedFromActivity() {}
}
