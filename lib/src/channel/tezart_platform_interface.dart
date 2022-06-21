import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'tezart_method_channel.dart';

abstract class TezartPlatform extends PlatformInterface {
  /// Constructs a TezartPlatform.
  TezartPlatform() : super(token: _token);

  static final Object _token = Object();

  static TezartPlatform _instance = MethodChannelTezart();

  /// The default instance of [TezartPlatform] to use.
  ///
  /// Defaults to [MethodChannelTezart].
  static TezartPlatform get instance => _instance;
  
  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TezartPlatform] when
  /// they register themselves.
  static set instance(TezartPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> localForge(String operation) {
    throw UnimplementedError('localForge() has not been implemented.');
  }
}
