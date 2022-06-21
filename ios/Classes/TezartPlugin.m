#import "TezartPlugin.h"
#if __has_include(<tezart/tezart-Swift.h>)
#import <tezart/tezart-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "tezart-Swift.h"
#endif

@implementation TezartPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftTezartPlugin registerWithRegistrar:registrar];
}
@end
