
import 'dart:async';

import 'package:flutter/services.dart';

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

  /// Opens Snapchat oauth screen in app (if installed) or in a browser
  /// Returns snapchat user or throws error if it fails
  Future<SnapchatUser> login() async {
    final loginResult = await _channel.invokeMethod('login');

    print('\n\n\n${loginResult.toString()}\n\n\n');

    final currentUser = await this.currentUser;
    onLogin?.call(currentUser);

    print('\nloginUser - Current user: $currentUser\n');

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
  Future share(SnapchatMediaType mediaType,
      {String mediaUrl,
        SnapchatSticker sticker,
        String caption,
        String attachmentUrl}) async {
    assert(mediaType != null && (caption != null ? caption.length <= 250 : true));

    if (mediaType != SnapchatMediaType.none) assert(mediaUrl != null);

    try {
      final result = await _channel.invokeMethod('send', <String, dynamic>{
        'mediaType': mediaType.toString().substring(mediaType.toString().indexOf('.') + 1),
        'mediaUrl': mediaUrl,
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

  /// [topPadding] is top padding in pixels
  /// [friendUserId] is the id of a user also connected with snapchat
  Future showBitmojiPicker(int topPadding, {String friendUserId}) async {
    try {
      final result = await _channel.invokeMethod('showBitmojiPicker',
          {
            'topPadding': topPadding,
            'friendUserId': friendUserId,
            'isDarkTheme': true
          }
      );

      return result;
    } catch (e) {
      return e;
    }
  }

  Future closeBitmojiPicker() async {
    try {
      final result = await _channel.invokeMethod('closeBitmojiPicker');
      return result;
    } catch (e) {
      return e;
    }
  }

  Future setBitmojiPickerQuery(String query) async {
    try {
      final result = await _channel.invokeMethod('setBitmojiPickerQuery', {
        'query': query
      });
      print('INFO (setBitmojiPickerQuery) > ${result.toString()}');
      return result;

    } catch (e) {
      print('ERROR (setBitmojiPickerQuery) > ${e.toString()}');
      return e;
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

  /// Sticker image url
  String imageUrl;

  /// True if sticker is animated
  bool isAnimated;

  double width;
  double height;
  double x;
  double y;
  double rotation;

  SnapchatSticker(this.imageUrl, this.isAnimated, {
    this.width,
    this.height,
    this.x,
    this.y,
    this.rotation,
  })
      : assert(imageUrl != null && isAnimated != null);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'imageUrl': this.imageUrl,
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
