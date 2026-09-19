import 'package:flutter/material.dart';
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

    final controller = _isNetworkVideo(path)
        ? VideoPlayerController.networkUrl(Uri.parse(path))
        : VideoPlayerController.asset(path);

    try {
      await controller.initialize();
      await controller.setLooping(true);
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
    controller.value.isPlaying ? await controller.pause() : await controller.play();
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
    final semanticsBase = _hasVideo
        ? 'Exercise video available'
        : 'No video available';
    final semanticsLabel = widget.exerciseName == null
        ? semanticsBase
        : '$semanticsBase for ${widget.exerciseName}';

    return Semantics(
      label: semanticsLabel,
      container: true,
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
    final label = error ?? (canOpen ? 'Play video guide' : 'No video available');
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
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return Stack(
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
        Center(
          child: IconButton.filledTonal(
            tooltip: controller.value.isPlaying ? 'Pause video' : 'Play video',
            onPressed: onTogglePlayback,
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
