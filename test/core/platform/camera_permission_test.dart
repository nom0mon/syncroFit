import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/platform/camera_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidCameraPermissionGateway', () {
    const channel = MethodChannel('camera-permission-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('maps native camera statuses and opens settings', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'checkCameraPermission' => 'denied',
          'requestCameraPermission' => 'granted',
          'openAppSettings' => true,
          _ => null,
        };
      });
      const gateway = AndroidCameraPermissionGateway(channel: channel);

      expect(await gateway.checkStatus(), CameraPermissionStatus.denied);
      expect(await gateway.request(), CameraPermissionStatus.granted);
      expect(await gateway.openAppSettings(), isTrue);
      expect(
        calls,
        [
          'checkCameraPermission',
          'requestCameraPermission',
          'openAppSettings',
        ],
      );
    });

    test('rejects an unknown native permission status', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => 'unexpected');
      const gateway = AndroidCameraPermissionGateway(channel: channel);

      await expectLater(
        gateway.checkStatus(),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('CameraPermissionCoordinator', () {
    testWidgets('returns immediately when camera access is already granted',
        (tester) async {
      final gateway = _FakeCameraPermissionGateway(
        initialStatus: CameraPermissionStatus.granted,
      );

      await tester.pumpWidget(_PermissionHost(gateway: gateway));
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();

      expect(find.text('Camera ready'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(gateway.requestCount, 0);
    });

    testWidgets('explains camera access and allows a non-blocking decline',
        (tester) async {
      final gateway = _FakeCameraPermissionGateway(
        initialStatus: CameraPermissionStatus.denied,
      );

      await tester.pumpWidget(_PermissionHost(gateway: gateway));
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();

      expect(find.text('Use your camera?'), findsOneWidget);
      expect(find.textContaining('select a photo'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Other features available'), findsOneWidget);
      expect(gateway.requestCount, 0);
    });

    testWidgets('requests permission only after the explanation is accepted',
        (tester) async {
      final gateway = _FakeCameraPermissionGateway(
        initialStatus: CameraPermissionStatus.denied,
        requestStatuses: [CameraPermissionStatus.granted],
      );

      await tester.pumpWidget(_PermissionHost(gateway: gateway));
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Camera ready'), findsOneWidget);
      expect(gateway.requestCount, 1);
    });

    testWidgets('offers one retry after a denial', (tester) async {
      final gateway = _FakeCameraPermissionGateway(
        initialStatus: CameraPermissionStatus.denied,
        requestStatuses: [
          CameraPermissionStatus.denied,
          CameraPermissionStatus.granted,
        ],
      );

      await tester.pumpWidget(_PermissionHost(gateway: gateway));
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Camera access denied'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Camera ready'), findsOneWidget);
      expect(gateway.requestCount, 2);
    });

    testWidgets('guides permanent denial to Android app settings',
        (tester) async {
      final gateway = _FakeCameraPermissionGateway(
        initialStatus: CameraPermissionStatus.permanentlyDenied,
      );

      await tester.pumpWidget(_PermissionHost(gateway: gateway));
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();

      expect(find.text('Allow camera in Settings'), findsOneWidget);
      expect(
          find.textContaining('Selecting an existing photo'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(gateway.openSettingsCount, 1);
      expect(find.text('Other features available'), findsOneWidget);
    });
  });
}

class _PermissionHost extends StatefulWidget {
  const _PermissionHost({required this.gateway});

  final CameraPermissionGateway gateway;

  @override
  State<_PermissionHost> createState() => _PermissionHostState();
}

class _PermissionHostState extends State<_PermissionHost> {
  bool? _allowed;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              FilledButton(
                onPressed: () async {
                  final allowed = await CameraPermissionCoordinator(
                    widget.gateway,
                  ).requestAtPointOfUse(context);
                  if (mounted) setState(() => _allowed = allowed);
                },
                child: const Text('Take photo'),
              ),
              if (_allowed != null)
                Text(
                  _allowed! ? 'Camera ready' : 'Other features available',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeCameraPermissionGateway implements CameraPermissionGateway {
  _FakeCameraPermissionGateway({
    required this.initialStatus,
    List<CameraPermissionStatus> requestStatuses = const [],
  }) : _requestStatuses = List.of(requestStatuses);

  final CameraPermissionStatus initialStatus;
  final List<CameraPermissionStatus> _requestStatuses;
  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<CameraPermissionStatus> checkStatus() async => initialStatus;

  @override
  Future<bool> openAppSettings() async {
    openSettingsCount++;
    return true;
  }

  @override
  Future<CameraPermissionStatus> request() async {
    final status = _requestStatuses[requestCount];
    requestCount++;
    return status;
  }
}
