import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_spacing.dart';
import 'exercise_video_catalog.dart';

const Set<String> _playableVideoExtensions = {
  'mp4',
  'm4v',
  'webm',
  'mkv',
  '3gp',
  'ts',
};

const Set<String> _playableUriSchemes = {'http', 'https'};

/// Returns whether [videoPath] has a video format supported by the client.
bool hasPlayableExerciseVideo(String? videoPath) {
  final trimmed = videoPath?.trim() ?? '';
  if (trimmed.isEmpty) return false;

  final uri = Uri.tryParse(trimmed);
  String candidate = trimmed;
  if (uri != null && uri.hasScheme) {
    if (!_playableUriSchemes.contains(uri.scheme.toLowerCase())) return false;
    if (uri.pathSegments.isEmpty) return false;
    candidate = uri.pathSegments.last;
  }

  final dotIndex = candidate.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == candidate.length - 1) return false;
  return _playableVideoExtensions
      .contains(candidate.substring(dotIndex + 1).toLowerCase());
}

bool _isNetworkVideo(String path) {
  final uri = Uri.tryParse(path);
  return uri != null &&
      uri.hasScheme &&
      _playableUriSchemes.contains(uri.scheme.toLowerCase());
}

bool _isAvailableVideo(String? path) {
  final value = path?.trim() ?? '';
  if (!hasPlayableExerciseVideo(value)) return false;
  return _isNetworkVideo(value) || isBundledExerciseVideo(value);
}

/// Plays an exercise demonstration on demand, or shows an honest fallback
/// while that exercise's demonstration is not yet bundled.
class ExerciseMedia extends StatefulWidget {
  const ExerciseMedia({
    super.key,
    required this.videoPath,
    this.exerciseName,
    this.borderRadius = 16,
  });

  final String? videoPath;
  final String? exerciseName;
  final double borderRadius;

  @override
  State<ExerciseMedia> createState() => _ExerciseMediaState();
}

class _ExerciseMediaState extends State<ExerciseMedia> {
  VideoPlayerController? _controller;
  bool _isLoading = false;
  String? _error;

  bool get _hasVideo => _isAvailableVideo(widget.videoPath);

  @override
  void didUpdateWidget(covariant ExerciseMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _disposeController();
      _error = null;
      _isLoading = false;
    }
  }

  Future<void> _openVideo() async {
    final path = widget.videoPath?.trim();
    if (path == null || !_hasVideo || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final playablePath = _isNetworkVideo(path)
        ? path
        : resolvedBundledExerciseVideoPath(path) ?? path;
    final controller = _isNetworkVideo(playablePath)
        ? VideoPlayerController.networkUrl(Uri.parse(playablePath))
        : VideoPlayerController.asset(playablePath);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Video could not be opened';
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    controller.value.isPlaying
        ? await controller.pause()
        : await controller.play();
    if (mounted) setState(() {});
  }

  /// Opens the current video in an immersive, landscape-capable fullscreen
  /// view. The existing [VideoPlayerController] is reused so playback position
  /// and buffering are preserved and a second decoder is never created.
  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenVideoPage(
          controller: controller,
          exerciseName: widget.exerciseName,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    // Returning from fullscreen: reflect any play/pause changes made there.
    if (mounted) setState(() {});
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;
    final semanticsBase =
        _hasVideo ? 'Exercise video available' : 'No video available';
    final semanticsLabel = widget.exerciseName == null
        ? semanticsBase
        : '$semanticsBase for ${widget.exerciseName}';

    return Semantics(
      label: semanticsLabel,
      container: true,
      explicitChildNodes: true,
      button: _hasVideo && controller == null,
      child: AspectRatio(
        key: const Key('exercise-media'),
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: controller != null && controller.value.isInitialized
                ? _VideoPlayback(
                    controller: controller,
                    onTogglePlayback: _togglePlayback,
                    onFullscreen: _openFullscreen,
                  )
                : _VideoPrompt(
                    hasVideo: _hasVideo,
                    isLoading: _isLoading,
                    error: _error,
                    onPressed: _openVideo,
                  ),
          ),
        ),
      ),
    );
  }
}

class _VideoPrompt extends StatelessWidget {
  const _VideoPrompt({
    required this.hasVideo,
    required this.isLoading,
    required this.error,
    required this.onPressed,
  });

  final bool hasVideo;
  final bool isLoading;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) return const Center(child: CircularProgressIndicator());

    final canOpen = hasVideo;
    final label =
        error ?? (canOpen ? 'Play video guide' : 'No video available');
    final icon = error != null
        ? Icons.refresh
        : canOpen
            ? Icons.play_circle_outline
            : Icons.videocam_off_outlined;

    return InkWell(
      onTap: canOpen ? onPressed : null,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPlayback extends StatelessWidget {
  const _VideoPlayback({
    required this.controller,
    required this.onTogglePlayback,
    required this.onFullscreen,
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlayback;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              const Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Tooltip(
                  message: 'Video is muted',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        Icons.volume_off,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ColoredBox(
          color: Colors.black87,
          child: Row(
            children: [
              IconButton(
                tooltip:
                    controller.value.isPlaying ? 'Pause video' : 'Play video',
                onPressed: onTogglePlayback,
                color: Colors.white,
                icon: Icon(controller.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow),
              ),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                key: const Key('exercise-media-fullscreen'),
                tooltip: 'Fullscreen',
                onPressed: onFullscreen,
                color: Colors.white,
                icon: const Icon(Icons.fullscreen),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ],
    );
  }
}

/// Immersive fullscreen playback for an exercise demonstration.
///
/// Reuses the caller's [VideoPlayerController] so playback state is shared and
/// no second decoder is created. Allows landscape while open and restores the
/// app's portrait orientation and system UI overlays on exit.
class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({
    required this.controller,
    this.exerciseName,
  });

  final VideoPlayerController controller;
  final String? exerciseName;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    // Restore the app's default chrome and release the fullscreen orientation
    // override. The app does not lock orientation globally, so we clear the
    // preference (empty list = system default) rather than forcing portrait.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  void _togglePlayback() {
    final controller = widget.controller;
    controller.value.isPlaying ? controller.pause() : controller.play();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final semanticsLabel = widget.exerciseName == null
        ? 'Fullscreen exercise video'
        : 'Fullscreen exercise video for ${widget.exerciseName}';

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: GestureDetector(
                  onTap: _togglePlayback,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            // Progress bar pinned to the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(
                color: Colors.black54,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            // Exit-fullscreen control, kept clear of the status-bar inset.
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: IconButton(
                    key: const Key('exercise-media-exit-fullscreen'),
                    tooltip: 'Exit fullscreen',
                    color: Colors.white,
                    icon: const Icon(Icons.fullscreen_exit),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
