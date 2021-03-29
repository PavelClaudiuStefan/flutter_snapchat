import Flutter
import UIKit
import SCSDKLoginKit
import SCSDKCreativeKit
import SCSDKBitmojiKit

public class SwiftFlutterSnapchatPlugin: NSObject, FlutterPlugin {
    
    let flutterRegistrar: FlutterPluginRegistrar
    var viewController: UIViewController
    
//    var delegate: SCSDKBitmojiStickerPickerViewControllerDelegate
    
    var _snapApi: SCSDKSnapAPI?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_snapchat", binaryMessenger: registrar.messenger())
        
        let viewController: UIViewController = (UIApplication.shared.delegate?.window??.rootViewController)!;
        
        let instance = SwiftFlutterSnapchatPlugin(pluginRegistrar: registrar, uiViewController: viewController)
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(pluginRegistrar: FlutterPluginRegistrar, uiViewController: UIViewController) {
        self.flutterRegistrar = pluginRegistrar
        self.viewController = uiViewController
//        delegate = SwiftFlutterSnapchatPluginDelegate(registrar: pluginRegistrar, viewController: uiViewController)
    }
    
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
            sendToSnapchat(call, result)
            
        case "showBitmojiPicker":
            showBitmojiPicker(call, result)
            
        case "closeBitmojiPicker":
            result("")
            
        case "setBitmojiPickerQuery":
            result("")
            
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
    
    private func sendToSnapchat(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments,
              let args = arguments as? [String: Any] else { return }
        
        let mediaType = args["mediaType"] as? String
        let mediaUrl = args["mediaUrl"] as? String
        
        var content: SCSDKSnapContent?
        
        switch (mediaType) {
        case "photo":
            //            let photo = SCSDKSnapPhoto(imageUrl: URL(string: mediaUrl!)!)
            let photo = SCSDKSnapPhoto(imageUrl: URL(fileURLWithPath: mediaUrl!))
            content = SCSDKPhotoSnapContent(snapPhoto: photo)
        case "video":
            let video = SCSDKSnapVideo(videoUrl: URL(fileURLWithPath: mediaUrl!))
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
            
            let width = sticker["width"] as? Float
            let height = sticker["height"] as? Float
            
            let x = sticker["x"] as? Float
            let y = sticker["y"] as? Float
            
            let snapSticker = SCSDKSnapSticker(stickerUrl: URL(fileURLWithPath: url!), isAnimated: isAnimated!)
            
            if (width != nil) { snapSticker.width = CGFloat(width!) }
            if (height != nil) { snapSticker.height = CGFloat(height!) }
            
            if (x != nil) { snapSticker.posX = CGFloat(x!) }
            if (y != nil) { snapSticker.posY = CGFloat(y!) }
            
            content?.sticker = snapSticker
        }
        
        if (self._snapApi == nil) {
            self._snapApi = SCSDKSnapAPI()
        }
        
        //        result(mediaType! + " " + mediaUrl!)
        
        self._snapApi!.startSending(content!, completionHandler: { (error: Error?) in
            if (error != nil) {
                result(FlutterError(code: "SendMediaSendError", message: error.debugDescription, details: error?.localizedDescription))
            } else {
                result("SendMedia Success")
            }
        })
    }
    
    private func showBitmojiPicker(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments,
              let args = arguments as? [String: Any] else { return }
        
        var isDarkTheme: Bool
        if let isDarkThemeArg = args["isDarkTheme"] as? Bool {
            isDarkTheme = isDarkThemeArg;
        } else {
            isDarkTheme = false;
        }
        
        let stickerPickerVC: SCSDKBitmojiStickerPickerViewController = SCSDKBitmojiStickerPickerViewController(
            config: SCSDKBitmojiStickerPickerConfigBuilder()
                .withShowSearchBar(true)
                .withShowSearchPills(true)
                .withTheme(isDarkTheme ? .light : .dark)
                .build()
        )
        stickerPickerVC.delegate = self
        
        if let friendUserId = args["friendUserId"] as? String {
            stickerPickerVC.setFriendUserId(friendUserId)
        }
        
//        addChildViewController(stickerPickerVC)
//        view.addSubview(stickerPickerVC.view)
//        stickerPickerVC.didMove(toParentViewController: self)
        
        viewController.addChild(stickerPickerVC)
        viewController.view.addSubview(stickerPickerVC.view)
        stickerPickerVC.didMove(toParent: viewController)
        
        result("Opened bitmoji picker")
        
        
//        if let navigationController = viewController.navigationController {
//            navigationController.pushViewController(stickerPickerVC, animated: true)
//        }
        
//        if let navigationController = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController {
//            navigationController.pushViewController(stickerPickerVC, animated: true)
//        }
//
//        result("2nd variant")
        
        let storyboard : UIStoryboard? = UIStoryboard.init(name: "Main", bundle: nil);
        let window: UIWindow = ((UIApplication.shared.delegate?.window)!)!

        let objVC: UIViewController? = storyboard!.instantiateViewController(withIdentifier: "FlutterViewController")
        let aObjNavi = UINavigationController(rootViewController: objVC!)
        window.rootViewController = aObjNavi
        aObjNavi.pushViewController(viewController, animated: true)
    }
    
    private func handleBitmojiSend(imageURL: String, image: UIImage?) {
        
    }
    
}

extension SwiftFlutterSnapchatPlugin: SCSDKBitmojiStickerPickerViewControllerDelegate {
    public func bitmojiStickerPickerViewController(_ stickerPickerViewController: SCSDKBitmojiStickerPickerViewController,
                                            didSelectBitmojiWithURL bitmojiURL: String,
                                            image: UIImage?) {
        handleBitmojiSend(imageURL: bitmojiURL, image: image)
    }
    
    public func bitmojiStickerPickerViewController(_ stickerPickerViewController: SCSDKBitmojiStickerPickerViewController, searchFieldFocusDidChangeWithFocus hasFocus: Bool) {
//        bitmojiSearchHasFocus = hasFocus
    }
}

