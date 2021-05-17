
import 'dart:async';

import 'package:flutter/services.dart';

// TODO - Replace platform exceptions with detailed and formatted errors
class FlutterSnapchat {
  static const MethodChannel _channel = const MethodChannel('flutter_snapchat');

  Stream<SnapchatUser> onAuthStateChanged;

  void Function(SnapchatUser user) onLogin;
  void Function() onLogout;

  FlutterSnapchat({this.onLogin, this.onLogout}) {
    this.currentUser.then((user) {
      onLogin?.call(user);
    }).catchError((error, StackTrace stacktrace) {
      onLogout?.call();
    });
  }

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  Future<bool> isUserLoggedIn() async {
    final isUserLoggedIn = await _channel.invokeMethod('isUserLoggedIn');

    return isUserLoggedIn;
  }

  /// Opens Snapchat oauth screen in app (if installed) or in a browser
  /// Returns snapchat user or throws error if it fails
  Future<SnapchatUser> login() async {
    await _channel.invokeMethod('login');

    final currentUser = await this.currentUser;
    onLogin?.call(currentUser);

    return currentUser;
  }

  /// Close auth status listener, clears local session tokens
  /// Calling current user after logging out will result in an error
  Future<void> logout() async {
    await _channel.invokeMethod('logout');
    onLogout?.call();
  }

  /// Returns [SnapchatUser]
  /// Calling current user after logging out will result in an error
  Future<SnapchatUser> get currentUser async {
    try {
      final List<dynamic> userDetails = await _channel.invokeMethod('getUser');

      print('INFO (currentUser) > userDetails: ${userDetails.toString()}');

      return new SnapchatUser(
          userDetails[0] as String,
          userDetails[1] as String,
          userDetails[2] as String
      );
    } on PlatformException catch (e) {
      if (e.code == "GetUserError" || e.code == "NetworkGetUserError")
        return null;
      else
        throw e;
    }
  }

  /// Share photo/video/live camera content
  /// [mediaFilePath] needs to be the path of a platform (android, iOS) specific file. Flutter asset path is not supported
  Future share(SnapchatMediaType mediaType, {
        String mediaFilePath,
        SnapchatSticker sticker,
        String caption,
        String attachmentUrl
  }) async {

    assert(mediaType != null && (caption != null ? caption.length <= 250 : true));

    if (mediaType != SnapchatMediaType.none) assert(mediaFilePath != null);

    try {
      final result = await _channel.invokeMethod('share', <String, dynamic>{
        'mediaType': mediaType.toString().substring(mediaType.toString().indexOf('.') + 1),
        'mediaFilePath': mediaFilePath,
        'sticker': sticker != null ? sticker.toMap() : null,
        'caption': caption,
        'attachment': attachmentUrl
      });

      return result;
    } catch (e) {
      return e;
    }
  }

  /// Returns true if the Snapchat app is installed
  Future<bool> get isSnapchatInstalled async {
    bool isInstalled;
    isInstalled = await _channel.invokeMethod('isInstalled');
    return isInstalled;
  }

  /// [friendUserId] is the id of a user also connected with snapchat
  ///
  /// Returns void when bitmoji picker is closed by
  ///   - user selecting a bitmoji
  ///   - user closing it manually
  ///   - [closeBitmojiPicker] getting called
  Future<void> showBitmojiPicker({
    String friendUserId,
    bool isDarkTheme = false,
    bool hasSearchBar = true,
    bool hasSearchPills = true,
    void Function(String bitmojiUrl) onBitmojiSelected,
    void Function(dynamic bitmojiUrl) onError,
  }) async {
    try {
      final result = await _channel.invokeMethod('showBitmojiPicker',
          {
            'friendUserId': friendUserId,
            'isDarkTheme': isDarkTheme,
            'hasSearchBar': hasSearchBar,
            'hasSearchPills': hasSearchPills,
          }
      );

      if (result is Map && result['type'] == 'bitmoji_url') {
        onBitmojiSelected?.call(result["url"]);
      }

      return;

    } catch (e) {
      onError?.call(e);
      return;
    }
  }

  /// Returns
  ///   - true: if method closed bitmoji picker
  ///   - false: if bitmoji picker was not opened
  Future<bool> closeBitmojiPicker() async {
    try {
      await _channel.invokeMethod('closeBitmojiPicker');
      return true;

    } catch (e) {
      return false;
    }
  }

  /// Returns
  ///   - true: if search text has been set
  ///   - false: if bitmoji picker was not opened
  Future<bool> setBitmojiPickerSearchText(String searchText) async {
    try {
      await _channel.invokeMethod('setBitmojiPickerSearchText', {
        'searchText': searchText
      });
      return true;

    } catch (e) {
      return false;
    }
  }
}

class SnapchatUser {
  /// Snapchat user's unique ID
  final String externalId;

  /// Snapchat user's display name
  final String displayName;

  /// Snapchat user's Bitmoji url
  final String bitmojiUrl;

  SnapchatUser(this.externalId, this.displayName, this.bitmojiUrl);

  @override
  String toString() {
    return 'SnapchatUser (externalId: $externalId, displayName: $displayName, bitmojiUrl: $bitmojiUrl)';
  }
}

class SnapchatSticker {

  /// Sticker image file path
  /// [imageFilePath] needs to be the path of a platform (android, iOS) specific file. Flutter asset path is not supported
  String imageFilePath;

  /// True if sticker is animated
  bool isAnimated;

  double width;
  double height;
  double x;
  double y;
  double rotation;

  /// [width] valid range is from 0.0 to 300.0
  /// [height] valid range is from 0.0 to 300.0
  /// [x] valid range is from 0.0 to 1.0
  /// [y] valid range is from 0.0 to 1.0
  /// [rotation] valid range is from 0.0 to 360.0
  SnapchatSticker(this.imageFilePath, this.isAnimated, {
    this.width,
    this.height,
    this.x,
    this.y,
    this.rotation,
  }) {
    assert(imageFilePath != null && isAnimated != null);
    
    if (width != null) {
      assert(width >= 0.0 && width <= 300.0);
    }

    if (height != null) {
      assert(height >= 0.0 && height <= 300.0);
    }

    if (x != null) {
      assert(x >= 0.0 && x <= 1.0);
    }

    if (y != null) {
      assert(y >= 0.0 && y <= 1.0);
    }

    if (rotation != null) {
      assert(rotation >= 0.0 && rotation <= 360.0);
    }
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'imageFilePath': this.imageFilePath,
      'animated': this.isAnimated,
      'width': width,
      'height': height,
      'x': x,
      'y': y,
      'rotation': rotation,
    };
  }
}

enum SnapchatMediaType {
  photo,
  video,
  none
}
