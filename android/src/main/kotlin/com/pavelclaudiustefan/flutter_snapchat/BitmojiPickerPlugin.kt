package com.pavelclaudiustefan.flutter_snapchat

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** BitmojiPickerPlugin */
class BitmojiPickerPlugin: FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding
                .platformViewRegistry
                .registerViewFactory("com.pavelclaudiustefan.flutter_snapchat/bitmoji_picker",
                        BitmojiPickerFactory(binding.binaryMessenger))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}