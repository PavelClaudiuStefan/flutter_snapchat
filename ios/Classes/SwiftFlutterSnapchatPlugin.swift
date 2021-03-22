import Flutter
import UIKit

public class SwiftFlutterSnapchatPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_snapchat", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterSnapchatPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  var _snapApi: SCSDKSnapAPI?

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case "login":
          SCSDKLoginClient.login(from: (UIApplication.shared.keyWindow?.rootViewController)!) { (success: Bool, error: Error?) in
              if (!success) {
                  result(FlutterError(code: "LoginError", message: error.debugDescription, details: error.debugDescription))
              } else {
                  result("Login Success")
              }
          }
      case "getUser":
          let query = "{me{externalId, displayName, bitmoji{selfie}}}"
          let variables = ["page": "bitmoji"]

          SCSDKLoginClient.fetchUserData(withQuery: query, variables: variables, success: { (resources: [AnyHashable: Any]?) in
              guard let resources = resources,
                    let data = resources["data"] as? [String: Any],
                    let me = data["me"] as? [String: Any] else { return }

              let externalId = me["externalId"] as? String
              let displayName = me["displayName"] as? String
              var bitmojiAvatarUrl: String?
              if let bitmoji = me["bitmoji"] as? [String: Any] {
                  bitmojiAvatarUrl = bitmoji["selfie"] as? String
              }

              result([externalId, displayName, bitmojiAvatarUrl])
          }, failure: { (error: Error?, isUserLoggedOut: Bool) in
              if (isUserLoggedOut) {
                  result(FlutterError(code: "GetUserError", message: "User Not Logged In", details: nil))
              } else if (error != nil) {
                  result(FlutterError(code: "GetUserError", message: error.debugDescription, details: nil))
              } else {
                  result(FlutterError(code: "UnknownGetUserError", message: "Unknown", details: nil))
              }
          })
      case "logout":
          SCSDKLoginClient.clearToken()
          result("Logout Success")
      case "send":
          guard let arguments = call.arguments,
                let args = arguments as? [String: Any] else { return }

          let mediaType = args["mediaType"] as? String
          let mediaUrl = args["mediaUrl"] as? String

          var content: SCSDKSnapContent?

          switch (mediaType) {
          case "photo":
              let photo = SCSDKSnapPhoto(imageUrl: URL(string: mediaUrl!)!)
              content = SCSDKPhotoSnapContent(snapPhoto: photo)
          case "video":
              let video = SCSDKSnapVideo(videoUrl: URL(string: mediaUrl!)!)
              content = SCSDKVideoSnapContent(snapVideo: video)
          case "none":
              content = SCSDKNoSnapContent()
          default:
              result(FlutterError(code: "SendMediaArgsError", message: "Invalid Media Type", details: mediaType))
              return
          }

          let caption = args["caption"] as? String
          let attachmentUrl = args["attachment"] as? String

          content?.caption = caption
          content?.attachmentUrl = attachmentUrl

          if let sticker = args["sticker"] as? [String: Any] {
              let url = sticker["imageUrl"] as? String
              let isAnimated = sticker["animated"] as? Bool

              let snapSticker = SCSDKSnapSticker(stickerUrl: URL(string: url!)!, isAnimated: isAnimated!)

              content?.sticker = snapSticker
          }

          if (self._snapApi == nil) {
              self._snapApi = SCSDKSnapAPI()
          }

          self._snapApi?.startSending(content!, completionHandler: { (error: Error?) in
              if (error != nil) {
                  result(FlutterError(code: "SendMediaSendError", message: error.debugDescription, details: nil))
              } else {
                  result("SendMedia Success")
              }
          })
      case "isInstalled":
          let appScheme = "snapchat://app"
          let appUrl = URL(string: appScheme)
          result(UIApplication.shared.canOpenURL(appUrl! as URL))
      case "getPlatformVersion":
          result("iOS " + UIDevice.current.systemVersion)
      default:
          result(FlutterMethodNotImplemented)
      }
  }
}
