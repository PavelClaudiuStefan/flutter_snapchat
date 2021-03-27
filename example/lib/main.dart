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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

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
      _snapchatUser = await _snapchat.currentUser;

    } catch(e) {
      setState(() {
        _snapchatUser = null;
      });
    }

    setState(() {
      _isLoading = false;
    });
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
        _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text('Snapchat is not installed')));
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Flutter Snapchat Example App'),
          actions: [
            if (!_isBitmojisPickerVisible) IconButton(icon: Icon(Icons.image), onPressed: () {
              showBitmojisPicker();
            }),
            if (_isBitmojisPickerVisible) IconButton(icon: Icon(Icons.search), onPressed: () {
              _snapchat.setBitmojiPickerQuery('haha');
            })
          ],
        ),
        body: Center(
          child: _isLoading ? CircularProgressIndicator() : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_bitmojiUrl?.isNotEmpty ?? false)
                Container(
                    width: 64,
                    height: 64,
                    margin: EdgeInsets.all(16),
                    child: Image(
                      image: NetworkImage(_bitmojiUrl),
                    )
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
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            print('\n\nINFO (build) > step 1\n\n');
            //read and write
            final backgroundFilename = 'background_image.jpg';
            final stickerFilename = 'sticker.png';
            final String dir = (await getApplicationDocumentsDirectory()).path;

            final String backgroundFilePath = '$dir/$backgroundFilename';
            final String stickerFilePath = '$dir/$stickerFilename';

            print('\n\nINFO (build) > step 2\n\n');

            if (!(await File(backgroundFilePath).exists())) {
              print('\n\nINFO (build) > background not saved\n\n');
              var bytes = await rootBundle.load("assets/images/$backgroundFilename");
              await writeToFile(bytes, backgroundFilePath);
            }

            print('\n\nINFO (build) > step 3\n\n');

            if (!(await File(stickerFilePath).exists())) {
              print('\n\nINFO (build) > sticker not saved\n\n');
              var bytes = await rootBundle.load("assets/images/$stickerFilename");
              await writeToFile(bytes, stickerFilePath);
            }

            print('\n\nINFO (build) > snapchat share\n\n');

            _snapchat.share(SnapchatMediaType.photo,
                mediaUrl: backgroundFilePath,
                sticker: SnapchatSticker(
                    stickerFilePath,
                    false,
                    width: 200,
                    height: 200,
                    x: 0.5,
                    y: 0.5
                ),
                attachmentUrl: "https://example.com"
                );
          },
          child: Icon(Icons.camera),
        ),
      ),
    );
  }

  /// Opens a bitmoji picker
  void showBitmojisPicker() async {
    setState(() {
      _isBitmojisPickerVisible = true;
    });
    final int topPadding = ((MediaQuery.of(context).padding.top + kToolbarHeight) * MediaQuery.of(context).devicePixelRatio).toInt();
    final result = await _snapchat.showBitmojisPicker(topPadding);
    if (result['type'] == 'bitmoji_url') {
      setState(() {
        _bitmojiUrl = result['url'];
      });
    }
    print('INFO (showBitmojisPicker) > result: ${result.toString()}');
    setState(() {
      _isBitmojisPickerVisible = false;
    });
  }

  /// Return true (after closing picker) if bitmoji picker is visible
  /// Else return false if bitmoji picker is not visible
  Future<bool> tryCloseBitmojisPicker() async {
    if (_isBitmojisPickerVisible) {
      final result = await _snapchat.closeBitmojisPicker();
      print('INFO (closeBitmojisPicker) > result: ${result.toString()}');
      setState(() {
        _isBitmojisPickerVisible = false;
      });
      return true;
    } else {
      return false;
    }
  }

  Future<bool> _onWillPop() async {
    return !(await tryCloseBitmojisPicker());
  }

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return File(path).writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }
}
