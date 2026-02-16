import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Resolves a human-readable device description used as `User-Agent` /
/// `X-Device-Info` when talking to the backend.
class DeviceInfoHelper {
  DeviceInfoHelper._();

  static Future<String> getDeviceDescription() async {
    String osVersion = 'Unknown OS';
    try {
      osVersion = Platform.operatingSystemVersion;
    } catch (_) {}

    String description = 'Device: ${Platform.operatingSystem} ($osVersion)';

    try {
      final plugin = DeviceInfoPlugin();

      if (kIsWeb) {
        return 'Tutorix-Web';
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = await plugin.androidInfo;
          description =
              '${android.manufacturer} ${android.model} (Android ${android.version.release})';
        case TargetPlatform.iOS:
          final ios = await plugin.iosInfo;
          description = '${ios.name} ${ios.model} (iOS ${ios.systemVersion})';
        default:
          description = 'Tutorix-${defaultTargetPlatform.name} ($osVersion)';
      }
    } catch (e) {
      // ignore
    }

    return description;
  }
}
