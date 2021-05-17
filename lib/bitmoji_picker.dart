import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef void BitmojiPickerCreatedCallback(BitmojiPickerController controller);

/// Android implementation of platform view is WIP
/// iOS implementation of platform view is WIP
@deprecated
class BitmojiPicker extends StatefulWidget {

  BitmojiPicker({
    Key key,
    this.creationParams,
    this.onBitmojiPickerCreated,
  }) : super(key: key) {
    assert (Platform.isIOS);
  }

  final Map<String, dynamic> creationParams;
  final BitmojiPickerCreatedCallback onBitmojiPickerCreated;

  @override
  _BitmojiPickerState createState() => _BitmojiPickerState();
}

class _BitmojiPickerState extends State<BitmojiPicker> {

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: widget.creationParams,
      );

    } else if(defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: widget.creationParams,
      );
    }

    return Text(
        '$defaultTargetPlatform is not yet supported by the snapchat plugin');
  }

  void _onPlatformViewCreated(int id) {
    widget.onBitmojiPickerCreated?.call(BitmojiPickerController._(id));
  }
}

class BitmojiPickerController {
  BitmojiPickerController._(int id)
      : _channel = new MethodChannel('com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker_$id');

  final MethodChannel _channel;

  Future<void> showBitmojis() async {
    return _channel.invokeMethod('setupBitmojisPicker');
  }

  // TODO - Android
  // TODO - iOS
  Future<void> setSearchText(String searchText) async {
    assert(searchText != null);
    return _channel.invokeMethod('setSearchText', searchText);
  }
}