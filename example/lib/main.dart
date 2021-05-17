import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_snapchat/flutter_snapchat.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  String _platformVersion = 'Unknown';

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  SnapchatUser _snapchatUser;
  FlutterSnapchat _snapchat;

  String _bitmojiUrl;

  bool _isLoading = true;
  bool _isBitmojisPickerVisible = false;

  @override
  void initState() {
    super.initState();

    _snapchat = FlutterSnapchat(
        onLogin: (user) {
          setState(() {
            _snapchatUser = user;
          });
        },
        onLogout: () {
          setState(() {
            _snapchatUser = null;
          });
        }
    );

    initSnapchatUser();

    initPlatformState();
  }

  void initSnapchatUser() async {
    try {
      final isUserLoggedIn = await _snapchat.isUserLoggedIn();

      if (isUserLoggedIn) {
        _snapchatUser = await _snapchat.currentUser;
      } else {
        _snapchatUser = null;
      }

      setState(() {
        _isLoading = false;
      });

    } catch(e) {
      print('main - ERROR (initSnapchatUser) > error: ${e.toString()}');
      setState(() {
        _snapchatUser = null;
        _isLoading = false;
      });
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await FlutterSnapchat.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> loginUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool installed = await _snapchat.isSnapchatInstalled;
      if (installed) {
        final user = await _snapchat.login();
        setState(() {
          _snapchatUser = user;
          _isLoading = false;
        });
      } else {
        showMessage('Snapchat is not installed');
      }
    } catch (exception) {
      print(exception);
    }
  }

  Future<void> logoutUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _snapchat.logout();
    } catch (exception) {
      print(exception);
    }

    setState(() {
      _snapchatUser = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Snapchat Example App'),
          actions: [
            if (!_isBitmojisPickerVisible) IconButton(icon: Icon(Icons.image), onPressed: () {
              showBitmojiPicker();
            }),
            if (_isBitmojisPickerVisible) IconButton(icon: Icon(Icons.search), onPressed: () {
              _snapchat.setBitmojiPickerSearchText('test');
            })
          ],
        ),
        body: Center(
          child: _isLoading ? CircularProgressIndicator() : SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 92,
                    height: 92,
                    margin: EdgeInsets.all(16),
                    child: (_bitmojiUrl?.isEmpty ?? true)
                        ? Icon(Icons.image)
                        : Image(image: NetworkImage(_bitmojiUrl))
                ),

                if (_snapchatUser != null)
                  Container(
                      width: 64,
                      height: 64,
                      margin: EdgeInsets.all(16),
                      child: Image(
                        image: NetworkImage(_snapchatUser.bitmojiUrl),
                      )
                  ),

                if (_snapchatUser != null) Text(_snapchatUser.displayName),

                if (_snapchatUser != null) Text(
                    _snapchatUser.externalId,
                    style: TextStyle(color: Colors.grey, fontSize: 9.0)
                ),

                Text('Running on: $_platformVersion\n'),

                if (_snapchatUser == null) ElevatedButton(
                    onPressed: () => loginUser(),
                    child: Text('Login with Snapchat')
                ),

                if (_snapchatUser != null) TextButton(
                    onPressed: () => logoutUser(), child: Text("Logout")
                )
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final bool isUserLoggedIn = await _snapchat.isUserLoggedIn();
            if (!isUserLoggedIn) {
              showMessage('Login to share to snapchat');
              return;
            }

            /// [background_image.jpg] and [sticker.png] are flutter assets
            /// These assets are stored as a platform specific file, to be then used when sharing to snapchat
            final backgroundFilename = 'background_image.jpg';
            final stickerFilename = 'sticker.png';

            final String dir = (await getApplicationDocumentsDirectory()).path;

            final String backgroundFilePath = '$dir/$backgroundFilename';
            final String stickerFilePath = '$dir/$stickerFilename';

            if (!(await File(backgroundFilePath).exists())) {
              var bytes = await rootBundle.load("assets/images/$backgroundFilename");
              await writeToFile(bytes, backgroundFilePath);
            }

            if (!(await File(stickerFilePath).exists())) {
              var bytes = await rootBundle.load("assets/images/$stickerFilename");
              await writeToFile(bytes, stickerFilePath);
            }

            final result = await _snapchat.share(SnapchatMediaType.photo,
                mediaFilePath: backgroundFilePath,
                sticker: SnapchatSticker(
                    stickerFilePath,
                    false,
                    width: 128,
                    height: 128,
                    x: 0.5,
                    y: 0.5
                ),
                // attachmentUrl: "https://example.com"
                attachmentUrl: "smaplo://app/users/CGsTJIzlyscRdMPzgkLHdCrsdVQ2"
            );

            print('INFO (build) > result: ${result.toString()}');
          },
          child: Icon(Icons.camera),
        ),
      ),
    );
  }

  /// Opens a bitmoji picker
  void showBitmojiPicker() async {
    final bool isUserLoggedIn = await _snapchat.isUserLoggedIn();
    if (!isUserLoggedIn) {
      showMessage('Login to use bitmojis');
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      setState(() {
        _isBitmojisPickerVisible = true;
      });

      await _snapchat.showBitmojiPicker(
        isDarkTheme: false,
        onBitmojiSelected: (String bitmojiUrl) {
          print('onBitmojiSelected: $bitmojiUrl');
          setState(() {
            _bitmojiUrl = bitmojiUrl;
          });
        },
        onError: (dynamic e) {
          print('showBitmojiPicker error: runtimeType: ${e.runtimeType}, error: ${e.toString()}');

          if (e is PlatformException) {
            showMessage(e.message);
          } else {
            showMessage(e.toString());
          }
        }
      );

      if (_isBitmojisPickerVisible) {
        setState(() {
          _isBitmojisPickerVisible = false;
        });
      }

    } else {
      throw UnimplementedError('Bitmoji picker is only implemented for Android and iOS');
    }
  }

  /// Return true (after closing picker) if bitmoji picker is visible
  /// Else return false if bitmoji picker is not visible
  Future<bool> tryCloseBitmojisPicker() async {
    if (_isBitmojisPickerVisible) {
      await _snapchat.closeBitmojiPicker();

      if (_isBitmojisPickerVisible) {
        setState(() {
          _isBitmojisPickerVisible = false;
        });
      }
      return true;
    } else {
      return false;
    }
  }

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return File(path).writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  void showMessage(String message) {
    _scaffoldMessengerKey
        ?.currentState
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}
