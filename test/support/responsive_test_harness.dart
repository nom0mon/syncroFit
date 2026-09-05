import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/shared/widgets/responsive_layout.dart';

/// A release viewport used by responsive widget and golden tests.
@immutable
class ResponsiveTestConfiguration {
  const ResponsiveTestConfiguration({
    required this.name,
    required this.size,
    this.textScaleFactor = 1,
  }) : assert(textScaleFactor > 0);

  final String name;
  final Size size;
  final double textScaleFactor;

  Orientation get orientation =>
      size.width > size.height ? Orientation.landscape : Orientation.portrait;

  static const compactPhone = ResponsiveTestConfiguration(
    name: 'compact-phone',
    size: Size(320, 640),
  );

  static const standardPhone = ResponsiveTestConfiguration(
    name: 'standard-phone',
    size: Size(412, 915),
  );

  static const tablet = ResponsiveTestConfiguration(
    name: 'tablet',
    size: Size(800, 1280),
  );

  static const landscape = ResponsiveTestConfiguration(
    name: 'phone-landscape',
    size: Size(915, 412),
  );

  static const largeText = ResponsiveTestConfiguration(
    name: 'standard-phone-200-percent-text',
    size: Size(412, 915),
    textScaleFactor: 2,
  );

  /// Minimum release matrix required by PRD section 2.
  static const requiredConfigurations = <ResponsiveTestConfiguration>[
    compactPhone,
    standardPhone,
    tablet,
    landscape,
    largeText,
  ];

  AppWidthClass get widthClass => ResponsiveStandards.widthClassFor(size.width);

  @override
  String toString() => '$name (${size.width}x${size.height}, '
      '${textScaleFactor * 100}% text)';
}

/// Stable visual defaults for screenshot/golden tests.
///
/// Flutter's test binding provides the Ahem font, so these themes never fetch
/// Google Fonts or depend on host fonts. Tests may override either theme while
/// retaining the deterministic viewport and network-image behavior.
abstract final class ResponsiveGoldenTheme {
  static ThemeData get light => _theme(Brightness.light);

  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF202124),
      onPrimary: isDark ? const Color(0xFF202124) : const Color(0xFFFFFFFF),
      secondary: const Color(0xFF5F6368),
      onSecondary: const Color(0xFFFFFFFF),
      error: const Color(0xFFB3261E),
      onError: const Color(0xFFFFFFFF),
      surface: isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
      onSurface: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF202124),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Ahem',
      platform: TargetPlatform.android,
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _NoTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Ahem'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Ahem'),
    );
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

/// Deterministic one-pixel image data for image and network-image placeholders.
abstract final class ResponsiveGoldenImages {
  // A valid 1x1 transparent PNG.
  static final Uint8List transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL1WQAAAABJRU5ErkJggg==',
  );

  static MemoryImage get transparentProvider => MemoryImage(transparentPng);
}

/// Installs deterministic responses for [NetworkImage] during golden tests.
///
/// Always call [restore] in `tearDown`/`tearDownAll`, or use [install] with
/// `addTearDown(environment.restore)`.
class ResponsiveGoldenNetworkEnvironment {
  HttpOverrides? _previousOverrides;
  bool _installed = false;

  void install() {
    if (_installed) return;
    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _GoldenHttpOverrides();
    _installed = true;
  }

  void restore() {
    if (!_installed) return;
    HttpOverrides.global = _previousOverrides;
    _previousOverrides = null;
    _installed = false;
  }
}

/// Pumps [widget] at a required responsive viewport and turns every framework
/// error raised during layout/paint into one actionable test failure.
extension ResponsiveWidgetTester on WidgetTester {
  Future<void> pumpResponsiveWidget(
    Widget widget, {
    required ResponsiveTestConfiguration configuration,
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode themeMode = ThemeMode.light,
    bool settle = false,
    List<Finder> mustRemainVisible = const <Finder>[],
  }) async {
    view.devicePixelRatio = 1;
    view.physicalSize = configuration.size;
    addTearDown(view.reset);

    final frameworkErrors = <Object>[];
    try {
      await pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme ?? ResponsiveGoldenTheme.light,
          darkTheme: darkTheme ?? ResponsiveGoldenTheme.dark,
          themeMode: themeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(configuration.textScaleFactor),
            ),
            child: child!,
          ),
          home: widget,
        ),
      );
      if (settle) await pumpAndSettle();
    } catch (error) {
      frameworkErrors.add(error);
    }

    Object? pendingError;
    while ((pendingError = takeException()) != null) {
      frameworkErrors.add(pendingError!);
    }
    if (frameworkErrors.isNotEmpty) {
      throw TestFailure(_formatFrameworkErrors(configuration, frameworkErrors));
    }

    for (final finder in mustRemainVisible) {
      expectFullyVisible(finder, configuration: configuration);
    }
  }

  /// Fails when a critical widget extends outside the viewport or an ancestor
  /// clip. Pass primary actions and other release-critical content here rather
  /// than rejecting intentional image/card clipping globally.
  void expectFullyVisible(
    Finder finder, {
    ResponsiveTestConfiguration? configuration,
  }) {
    expect(finder, findsOneWidget);
    final renderObject = this.renderObject(finder);
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      throw TestFailure('$finder does not resolve to a laid-out RenderBox.');
    }

    final widgetRect = MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      Offset.zero & renderObject.size,
    );
    final viewportRect = Offset.zero &
        Size(
          view.physicalSize.width / view.devicePixelRatio,
          view.physicalSize.height / view.devicePixelRatio,
        );
    if (!_containsRect(viewportRect, widgetRect)) {
      throw TestFailure(
        '$finder is clipped by the viewport at ${configuration ?? view}: '
        '$widgetRect is not inside $viewportRect.',
      );
    }

    RenderObject? ancestor = renderObject.parent;
    while (ancestor != null) {
      if (ancestor is RenderBox &&
          ancestor.hasSize &&
          _clipsDescendants(ancestor)) {
        final clipBounds = MatrixUtils.transformRect(
          ancestor.getTransformTo(null),
          Offset.zero & ancestor.size,
        );
        if (!_containsRect(clipBounds, widgetRect)) {
          throw TestFailure(
            '$finder is clipped by ${ancestor.runtimeType}: '
            '$widgetRect is not inside $clipBounds.',
          );
        }
      }
      ancestor = ancestor.parent;
    }
  }
}

String _formatFrameworkErrors(
  ResponsiveTestConfiguration configuration,
  List<Object> errors,
) {
  final buffer = StringBuffer(
    'Responsive layout failed for $configuration with '
    '${errors.length} framework error(s):',
  );
  for (var index = 0; index < errors.length; index++) {
    final message = errors[index].toString();
    final category = _layoutFailureCategory(message);
    buffer.write('\n\n${index + 1}. $category: $message');
  }
  return buffer.toString();
}

String _layoutFailureCategory(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('renderflex') && normalized.contains('overflow')) {
    return 'RenderFlex overflow';
  }
  if (normalized.contains('clip')) return 'clipping';
  return 'uncaught layout/paint exception';
}

bool _clipsDescendants(RenderBox renderBox) {
  return (renderBox is RenderClipRect && renderBox.clipBehavior != Clip.none) ||
      (renderBox is RenderClipRRect && renderBox.clipBehavior != Clip.none) ||
      (renderBox is RenderClipOval && renderBox.clipBehavior != Clip.none) ||
      (renderBox is RenderClipPath && renderBox.clipBehavior != Clip.none) ||
      (renderBox is RenderPhysicalModel && renderBox.clipBehavior != Clip.none);
}

bool _containsRect(Rect outer, Rect inner) {
  const tolerance = 0.01;
  return inner.left >= outer.left - tolerance &&
      inner.top >= outer.top - tolerance &&
      inner.right <= outer.right + tolerance &&
      inner.bottom <= outer.bottom + tolerance;
}

class _GoldenHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _GoldenHttpClient();
}

class _GoldenHttpClient implements HttpClient {
  bool _autoUncompress = true;

  @override
  bool get autoUncompress => _autoUncompress;

  @override
  set autoUncompress(bool value) => _autoUncompress = value;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _GoldenHttpClientRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GoldenHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _GoldenHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _GoldenHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GoldenHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => ResponsiveGoldenImages.transparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(
      ResponsiveGoldenImages.transparentPng,
    ).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GoldenHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
