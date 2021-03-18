
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterSnapchat {
  static const MethodChannel _channel =
      const MethodChannel('flutter_snapchat');

  // ignore: close_sinks
  StreamController<SnapchatUser> _authStatusController;
  Stream<SnapchatUser> onAuthStateChanged;

  SnapchatAuthStateListener authStateListener;

  FlutterSnapchat() {
    this._authStatusController = StreamController<SnapchatUser>();
    this.onAuthStateChanged = _authStatusController.stream;
    this._authStatusController.add(null);

    this.currentUser.then((user) {
      this._authStatusController.add(user);
      this.authStateListener.onLogin(user);
    }).catchError((error, StackTrace stacktrace) {
      this._authStatusController.add(null);
      this.authStateListener.onLogout();
    });
  }

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  void addAuthStateListener(SnapchatAuthStateListener authStateListener) {
    this.authStateListener = authStateListener;
  }

  /// Opens Snapchat oauth screen in app (if installed) or in a browser
  /// Returns snapchat user or throws error if it fails
  Future<SnapchatUser> login() async {
    await _channel.invokeMethod('callLogin');
    final currentUser = await this.currentUser;
    this._authStatusController.add(currentUser);
    this.authStateListener.onLogin(currentUser);
    return currentUser;
  }

  /// Close auth status listener, clears local session tokens
  /// Calling current user after logging out will result in an error
  Future<void> logout() async {
    await _channel.invokeMethod('callLogout');
    this._authStatusController.add(null);
    this.authStateListener.onLogout();
    this._authStatusController.close();
  }

  /// Returns `SnapchatUser`
  /// Calling current user after logging out will result in an error
  Future<SnapchatUser> get currentUser async {
    try {
      final List<dynamic> userDetails = await _channel.invokeMethod('getUser');
      return new SnapchatUser(userDetails[0] as String,
          userDetails[1] as String, userDetails[2] as String);
    } on PlatformException catch (e) {
      if (e.code == "GetUserError" || e.code == "NetworkGetUserError")
        return null;
      else
        throw e;
    }
  }

  /// TODO
  Future<void> share(SnapchatMediaType mediaType,
      {String mediaUrl,
        SnapchatSticker sticker,
        String caption,
        String attachmentUrl}) async {
    assert(
    mediaType != null && (caption != null ? caption.length <= 250 : true));
    if (mediaType != SnapchatMediaType.none) assert(mediaUrl != null);
    await _channel.invokeMethod('sendMedia', <String, dynamic>{
      'mediaType':
      mediaType.toString().substring(mediaType.toString().indexOf('.') + 1),
      'mediaUrl': mediaUrl,
      'sticker': sticker != null ? sticker.toMap() : null,
      'caption': caption,
      'attachmentUrl': attachmentUrl
    });
  }

  /// Returns true if the Snapchat app is installed
  Future<bool> get isSnapchatInstalled async {
    bool isInstalled;
    isInstalled = await _channel.invokeMethod('isInstalled');
    return isInstalled;
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
}

class SnapchatSticker {

  /// Sticker image url
  String imageUrl;

  /// True if sticker is animated
  bool isAnimated;

  SnapchatSticker(this.imageUrl, this.isAnimated)
      : assert(imageUrl != null && isAnimated != null);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      "imageUrl": this.imageUrl,
      "animated": this.isAnimated
    };
  }
}

abstract class SnapchatAuthStateListener {
  void onLogin(SnapchatUser user);
  void onLogout();
}

enum SnapchatMediaType {
  photo,
  video,
  none
}
