import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_snapchat/flutter_snapchat.dart';

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> implements SnapchatAuthStateListener {

  String _platformVersion = 'Unknown';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  SnapchatUser _snapchatUser;
  FlutterSnapchat _snapchat = FlutterSnapchat();

  @override
  void initState() {
    super.initState();

    _snapchat.addAuthStateListener(this);

    initPlatformState();
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
    print(_snapchatUser.toString());
    try {
      bool installed = await _snapchat.isSnapchatInstalled;
      if (installed) {
        final user = await _snapchat.login();
        setState(() {
          _snapchatUser = user;
        });
      } else {
        _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text('Snapchat is not installed')));
      }
    } on PlatformException catch (exception) {
      print(exception);
    }
  }

  Future<void> logoutUser() async {
    print(_snapchatUser.toString());

    try {
      await _snapchat.logout();
    } on PlatformException catch (exception) {
      print(exception);
    }

    setState(() {
      _snapchatUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Flutter Snapchat Example App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
        onPressed: () {
          _snapchat.share(SnapchatMediaType.photo,
              mediaUrl:
              'https://picsum.photos/${this.context.size.width.floor()}/${this.context.size.height.floor()}.jpg',
              // sticker: SnapchatSticker(
              //     'https://miro.medium.com/max/1000/1*ilC2Aqp5sZd1wi0CopD1Hw.png',
              //     false
              // ),
              caption: "Flutter snapchat caption",
              attachmentUrl: "https://smaplo.com");
        },
        child: Icon(Icons.camera),
      ),
    );
  }

  @override
  void onLogin(SnapchatUser user) {
    print('on login: user: ${user.toString()}');
    setState(() {
      _snapchatUser = user;
    });
  }

  @override
  void onLogout() {
    setState(() {
      _snapchatUser = null;
    });
  }
}
