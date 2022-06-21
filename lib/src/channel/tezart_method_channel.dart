import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tezart_platform_interface.dart';

/// An implementation of [TezartPlatform] that uses method channels.
class MethodChannelTezart extends TezartPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('tezart');

  @override
  Future<String?> localForge(String operation) async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;

    try {
      return await methodChannel.invokeMethod<String>('localForge', {"data": operation});
    } catch (_) {
      return null;
    }
  }
}
