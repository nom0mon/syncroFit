import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The Android camera permission states relevant to point-of-use handling.
enum CameraPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}

/// Platform operations used by [CameraPermissionCoordinator].
abstract interface class CameraPermissionGateway {
  Future<CameraPermissionStatus> checkStatus();

  Future<CameraPermissionStatus> request();

  Future<bool> openAppSettings();
}

/// Android implementation backed by the app's native permission channel.
class AndroidCameraPermissionGateway implements CameraPermissionGateway {
  const AndroidCameraPermissionGateway({
    MethodChannel channel = _defaultChannel,
  }) : _channel = channel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.synchrofit.app/media_permissions',
  );

  final MethodChannel _channel;

  @override
  Future<CameraPermissionStatus> checkStatus() async {
    final value = await _channel.invokeMethod<String>('checkCameraPermission');
    return _parseStatus(value);
  }

  @override
  Future<CameraPermissionStatus> request() async {
    final value =
        await _channel.invokeMethod<String>('requestCameraPermission');
    return _parseStatus(value);
  }

  @override
  Future<bool> openAppSettings() async {
    return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
  }

  CameraPermissionStatus _parseStatus(String? value) {
    return switch (value) {
      'granted' => CameraPermissionStatus.granted,
      'denied' => CameraPermissionStatus.denied,
      'permanentlyDenied' => CameraPermissionStatus.permanentlyDenied,
      _ => throw PlatformException(
          code: 'invalid_permission_status',
          message: 'Android returned an unknown camera permission status.',
        ),
    };
  }
}

/// Runs the camera permission flow only when a camera action is requested.
///
/// The coordinator explains why access is needed before showing Android's
/// permission prompt. A refusal simply returns `false`; it never prevents the
/// caller from keeping the rest of the feature available.
class CameraPermissionCoordinator {
  const CameraPermissionCoordinator(this._gateway);

  final CameraPermissionGateway _gateway;

  Future<bool> requestAtPointOfUse(BuildContext context) async {
    try {
      final currentStatus = await _gateway.checkStatus();
      if (!context.mounted) return false;

      if (currentStatus == CameraPermissionStatus.granted) return true;
      if (currentStatus == CameraPermissionStatus.permanentlyDenied) {
        await _showSettingsGuidance(context);
        return false;
      }

      final shouldContinue = await _showExplanation(context);
      if (!context.mounted || !shouldContinue) return false;

      var requestedStatus = await _gateway.request();
      if (!context.mounted) return false;
      if (requestedStatus == CameraPermissionStatus.granted) return true;
      if (requestedStatus == CameraPermissionStatus.permanentlyDenied) {
        await _showSettingsGuidance(context);
        return false;
      }

      final shouldRetry = await _showRetryGuidance(context);
      if (!context.mounted || !shouldRetry) return false;

      requestedStatus = await _gateway.request();
      if (!context.mounted) return false;
      if (requestedStatus == CameraPermissionStatus.granted) return true;
      if (requestedStatus == CameraPermissionStatus.permanentlyDenied) {
        await _showSettingsGuidance(context);
        return false;
      }

      await _showStillDeniedMessage(context);
      return false;
    } on PlatformException {
      if (context.mounted) await _showUnavailableMessage(context);
      return false;
    }
  }

  Future<bool> _showExplanation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Use your camera?'),
            content: const Text(
              'Camera access is used only when you choose to take a progress '
              'photo. You can still select a photo and use the rest of '
              'SyncroFit without allowing it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showRetryGuidance(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera access denied'),
            content: const Text(
              'Allow camera access to take a new photo, or cancel and choose '
              'an existing photo instead.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Try again'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showSettingsGuidance(BuildContext context) async {
    final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Allow camera in Settings'),
            content: const Text(
              'Camera access is turned off for SyncroFit. Open Android '
              'Settings, allow Camera, then return and try again. Selecting '
              'an existing photo remains available.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        ) ??
        false;

    if (openSettings) await _gateway.openAppSettings();
  }

  Future<void> _showStillDeniedMessage(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera is still unavailable'),
        content: const Text(
          'You can try the camera again later or select an existing photo '
          'without camera access.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnavailableMessage(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera permission unavailable'),
        content: const Text(
          'SyncroFit could not check camera access. Try again, or select an '
          'existing photo instead.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
