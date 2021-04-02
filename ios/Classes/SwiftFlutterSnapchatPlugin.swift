import Flutter
import UIKit
import SCSDKLoginKit
import SCSDKCreativeKit
import SCSDKBitmojiKit

public class SwiftFlutterSnapchatPlugin: NSObject, FlutterPlugin {
    
    let flutterRegistrar: FlutterPluginRegistrar
    var viewController: UIViewController
    
    var result: FlutterResult?
    
    var _snapApi: SCSDKSnapAPI?
    
    var _stickerPickerVC: SCSDKBitmojiStickerPickerViewController?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = BitmojiPickerViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker")
                    
        
        let channel = FlutterMethodChannel(name: "flutter_snapchat", binaryMessenger: registrar.messenger())
        
        let viewController: UIViewController = (UIApplication.shared.delegate?.window??.rootViewController)!;
        
        let instance = SwiftFlutterSnapchatPlugin(pluginRegistrar: registrar, uiViewController: viewController)
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(pluginRegistrar: FlutterPluginRegistrar, uiViewController: UIViewController) {
        self.flutterRegistrar = pluginRegistrar
        self.viewController = uiViewController
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.result = result
        
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
            _sendToSnapchat(call, result)
            
        case "showBitmojiPicker":
            _showBitmojiPicker(call, result)
            
        case "closeBitmojiPicker":
            _closeBitmojiPicker(result)
            
        case "setBitmojiPickerSearchText":
            _setBitmojiPickerSearchText(call, result)
            
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
    
    private func _sendToSnapchat(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments,
              let args = arguments as? [String: Any] else { return }
        
        let mediaType = args["mediaType"] as? String
        let mediaFilePath = args["mediaFilePath"] as? String
        
        var content: SCSDKSnapContent?
        
        switch (mediaType) {
        case "photo":
            //            let photo = SCSDKSnapPhoto(imageUrl: URL(string: mediaFilePath!)!)
            let photo = SCSDKSnapPhoto(imageUrl: URL(fileURLWithPath: mediaFilePath!))
            content = SCSDKPhotoSnapContent(snapPhoto: photo)
        case "video":
            let video = SCSDKSnapVideo(videoUrl: URL(fileURLWithPath: mediaFilePath!))
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
            let stickerFilePath = sticker["imageFilePath"] as? String
            let isAnimated = sticker["animated"] as? Bool
            
            let width = sticker["width"] as? Float
            let height = sticker["height"] as? Float
            
            let x = sticker["x"] as? Float
            let y = sticker["y"] as? Float

            let rotation = sticker["rotation"] as? Float
            
            let snapSticker = SCSDKSnapSticker(stickerUrl: URL(fileURLWithPath: stickerFilePath!), isAnimated: isAnimated!)
            
            if (width != nil) { snapSticker.width = CGFloat(width!) }
            if (height != nil) { snapSticker.height = CGFloat(height!) }
            
            if (x != nil) { snapSticker.posX = CGFloat(x!) }
            if (y != nil) { snapSticker.posY = CGFloat(y!) }

            if (rotation != nil) { snapSticker.rotationDegreesClockwise = CGFloat(rotation!) }

            content?.sticker = snapSticker
        }
        
        if (self._snapApi == nil) {
            self._snapApi = SCSDKSnapAPI()
        }
        
        self._snapApi!.startSending(content!, completionHandler: { (error: Error?) in
            if (error != nil) {
                result(FlutterError(code: "SendMediaSendError", message: error.debugDescription, details: error?.localizedDescription))
            } else {
                result("SendMedia Success")
            }
        })
    }
    
    private func _showBitmojiPicker(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments,
              let args = arguments as? [String: Any] else { return }
        
        var isDarkTheme: Bool
        if let isDarkThemeArg = args["isDarkTheme"] as? Bool {
            isDarkTheme = isDarkThemeArg;
        } else {
            isDarkTheme = false;
        }
        
        if (_stickerPickerVC == nil) {
            _stickerPickerVC = SCSDKBitmojiStickerPickerViewController(
                config: SCSDKBitmojiStickerPickerConfigBuilder()
                    .withShowSearchBar(true)
                    .withShowSearchPills(true)
                    .withTheme(isDarkTheme ? .dark : .light)
                    .build()
            )
        }
        
        _stickerPickerVC?.presentationController?.delegate = self
        
        _stickerPickerVC?.delegate = self
        
        if let friendUserId = args["friendUserId"] as? String {
            _stickerPickerVC?.setFriendUserId(friendUserId)
        }
        
        let rootController = UIApplication.shared.delegate?.window??.rootViewController
        rootController?.present(_stickerPickerVC!, animated: true)
    }
    
    private func _closeBitmojiPicker(_ result: @escaping FlutterResult) {
        _stickerPickerVC?.dismiss(animated: true)
        // Result is sent back with the use of UIAdaptivePresentationControllerDelegate
    }
    
    private func _setBitmojiPickerSearchText(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments,
              let args = arguments as? [String: Any] else {
            result(FlutterError(code: "BitmojiPickerQueryError", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let searchText = args["searchText"] as? String else {
            result(FlutterError(code: "BitmojiPickerQueryError", message: "Invalid search text", details: nil))
            return
        }
        
        _stickerPickerVC?.setSearchTerm(searchText, searchMode: .searchResultOnly)
        result("Bitmoji picker search text updated")
    }
    
    private func handleBitmojiPickerClosed() {
        result?("Closed Bitmoji Picker")
//        _stickerPickerVC = nil
    }
    
    private func handleBitmojiSelected(imageURL: String, image: UIImage?) {
        result?([
            "type": "bitmoji_url",
            "url": imageURL
        ])
        
        _stickerPickerVC?.dismiss(animated: true)
    }
    
}

extension SwiftFlutterSnapchatPlugin: UIAdaptivePresentationControllerDelegate {
//    public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
//        handleBitmojiPickerClosed()
//    }
    
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        handleBitmojiPickerClosed()
    }
}

extension SwiftFlutterSnapchatPlugin: SCSDKBitmojiStickerPickerViewControllerDelegate {
    public func bitmojiStickerPickerViewController(_ stickerPickerViewController: SCSDKBitmojiStickerPickerViewController,
                                            didSelectBitmojiWithURL bitmojiURL: String,
                                            image: UIImage?) {
        handleBitmojiSelected(imageURL: bitmojiURL, image: image)
    }
    
    public func bitmojiStickerPickerViewController(_ stickerPickerViewController: SCSDKBitmojiStickerPickerViewController, searchFieldFocusDidChangeWithFocus hasFocus: Bool) {
//        bitmojiSearchHasFocus = hasFocus
    }
}

class BitmojiPickerViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return BitmojiPickerView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }
}

class BitmojiPickerView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var _stickerPickerVC: SCSDKBitmojiStickerPickerViewController

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _view = UIView()
        
        var isDarkTheme: Bool
        var friendUserId: String? = nil
        if let args = args as? [String: Any] {
            
            if let isDarkThemeArg = args["isDarkTheme"] as? Bool {
                isDarkTheme = isDarkThemeArg;
            } else {
                isDarkTheme = false;
            }
            
            friendUserId = args["friendUserId"] as? String
            
        } else {
            isDarkTheme = false;
        }
        
        _stickerPickerVC = SCSDKBitmojiStickerPickerViewController(
            config: SCSDKBitmojiStickerPickerConfigBuilder()
                .withShowSearchBar(true)
                .withShowSearchPills(true)
                .withTheme(isDarkTheme ? .light : .dark)
                .build()
        )
        
        if let friendUserId = friendUserId {
            _stickerPickerVC.setFriendUserId(friendUserId)
        }
        
        super.init()
        
        createNativeView(view: _view, args)
    }

    func view() -> UIView {
        return _view
    }

    func createNativeView(view _view: UIView, _ arguments: Any?) {
        _stickerPickerVC.delegate = self
        
        let rootController = UIApplication.shared.delegate?.window??.rootViewController
        rootController?.present(_stickerPickerVC, animated: true, completion: nil)
        
//        if let viewController = UIApplication.shared.delegate?.window??.rootViewController {
//            viewController.addChild(_stickerPickerVC)
//
//            _view.addSubview(_stickerPickerVC.view)
//            _stickerPickerVC.didMove(toParent: viewController)
//        }
        
//        if let navigationController = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController {
//            navigationController.pushViewController(_stickerPickerVC, animated: true)
//
//            _view.addSubview(_stickerPickerVC.view)
//            _stickerPickerVC.didMove(toParent: navigationController)
//
//        } else {
//            let storyboard : UIStoryboard? = UIStoryboard.init(name: "Main", bundle: nil);
//            let window: UIWindow = ((UIApplication.shared.delegate?.window)!)!
//
//            let objVC: UIViewController? = storyboard!.instantiateViewController(withIdentifier: "FlutterViewController")
//            let aObjNavi = UINavigationController(rootViewController: objVC!)
//            window.rootViewController = aObjNavi
//            aObjNavi.pushViewController(_stickerPickerVC, animated: true)
//
//            _view.addSubview(_stickerPickerVC.view)
//            _stickerPickerVC.didMove(toParent: aObjNavi)
//        }
    }
    
    private func handleBitmojiSend(imageURL: String, image: UIImage?) {
        
    }
}

extension BitmojiPickerView: SCSDKBitmojiStickerPickerViewControllerDelegate {
    public func bitmojiStickerPickerViewController(_ stickerPickerViewController: SCSDKBitmojiStickerPickerViewController,
                                            didSelectBitmojiWithURL bitmojiURL: String,
                                            image: UIImage?) {
        handleBitmojiSend(imageURL: bitmojiURL, image: image)
    }
    
    public func bitmojiStickerPickerViewController(_ stickerPickerViewController: SCSDKBitmojiStickerPickerViewController, searchFieldFocusDidChangeWithFocus hasFocus: Bool) {
//        bitmojiSearchHasFocus = hasFocus
    }
}

