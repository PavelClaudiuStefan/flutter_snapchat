#import "FlutterSnapchatPlugin.h"
#if __has_include(<flutter_snapchat/flutter_snapchat-Swift.h>)
#import <flutter_snapchat/flutter_snapchat-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_snapchat-Swift.h"
#endif

@implementation FlutterSnapchatPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterSnapchatPlugin registerWithRegistrar:registrar];
}
@end
