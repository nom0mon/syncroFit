import 'package:flutter/services.dart';

/// Opens the operating system's notification controls for SyncroFit.
abstract final class NotificationSettingsLauncher {
  static const _channel = MethodChannel('com.synchrofit.app/media_permissions');

  static Future<bool> open() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
