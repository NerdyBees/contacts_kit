import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'contacts_kit_platform_interface.dart';

/// An implementation of [ContactsKitPlatform] that uses method channels.
class MethodChannelContactsKit extends ContactsKitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('contacts_kit');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
