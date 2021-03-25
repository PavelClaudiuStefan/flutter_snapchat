import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_snapchat/flutter_snapchat.dart';
import 'package:flutter_snapchat/bitmoji_picker.dart';
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
  // FlutterSnapchat _snapchat = FlutterSnapchat(authStateListener: this);
  FlutterSnapchat _snapchat;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // print('\n\n\ninitState\n\n\n');

    // _snapchat.addAuthStateListener(this);

    // _snapchat = FlutterSnapchat(authStateListener: this);
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

    // print('\nloginUser - Started\n');
    try {
      bool installed = await _snapchat.isSnapchatInstalled;
      // print('\nloginUser - installed: $installed\n');
      if (installed) {
        // print('\nloginUser - Requested user\n');
        final user = await _snapchat.login();
        // print('\nloginUser - Received user: ${user.toString()}\n');
        setState(() {
          _snapchatUser = user;
          _isLoading = false;
        });
        // print('\nloginUser - Updated user state\n');
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
    // print('\nbuild - isLoading: $_isLoading, user: $_snapchatUser\n');

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Flutter Snapchat Example App'),
        actions: [
          IconButton(icon: Icon(Icons.image), onPressed: () {
            showBitmojis();
          })
        ],
      ),
      body: Center(
        child: _isLoading ? CircularProgressIndicator() : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
                child: Container(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    width: 128.0,
                    height: 320.0,
                    child: BitmojiPicker(
                      onBitmojiPickerCreated: (controller) {
                        controller.showBitmojis();
                      },
                    )
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
          //read and write
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
              // mediaUrl: 'https://picsum.photos/${this.context.size.width.floor()}/${this.context.size.height.floor()}.jpg',
              // sticker: SnapchatSticker(
              //     'https://miro.medium.com/max/1000/1*ilC2Aqp5sZd1wi0CopD1Hw.png',
              //     false
              // ),
              // caption: "Flutter snapchat caption",
              attachmentUrl: "https://smaplo.com");
        },
        child: Icon(Icons.camera),
      ),
    );
  }

  void showBitmojis() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return TextButton(
            onPressed: () {
              _snapchat.showBitmojis();
            },
            child: Text('Bitmojis')
        );
      }
    );

    // _snapchat.showBitmojis();
  }

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }
}
