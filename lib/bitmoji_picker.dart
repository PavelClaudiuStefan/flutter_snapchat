import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef void BitmojiPickerCreatedCallback(BitmojiPickerController controller);

class BitmojiPicker extends StatefulWidget {

  const BitmojiPicker({
    Key key,
    this.onBitmojiPickerCreated,
  }) : super(key: key);

  final BitmojiPickerCreatedCallback onBitmojiPickerCreated;

  @override
  _BitmojiPickerState createState() => _BitmojiPickerState();
}

class _BitmojiPickerState extends State<BitmojiPicker> {

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return Text(
        '$defaultTargetPlatform is not yet supported by the snapchat plugin');
  }

  void _onPlatformViewCreated(int id) {
    if (widget.onBitmojiPickerCreated == null) {
      return;
    }
    widget.onBitmojiPickerCreated(new BitmojiPickerController._(id));
  }
}

class BitmojiPickerController {
  BitmojiPickerController._(int id)
      : _channel = new MethodChannel('com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker_$id');

  final MethodChannel _channel;

  Future<void> showBitmojis() async {
    return _channel.invokeMethod('showBitmojis');
  }

  // Future<void> setQuery(String query) async {
  //   assert(query != null);
  //   return _channel.invokeMethod('setQuery', query);
  // }
}