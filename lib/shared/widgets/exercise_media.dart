import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Supported video file extensions that can be played on the Android client.
const Set<String> _playableVideoExtensions = {
  'mp4',
  'm4v',
  'webm',
  'mkv',
  '3gp',
  'ts',
};

/// Network URI schemes that can be streamed by the Android client.
const Set<String> _playableUriSchemes = {'http', 'https'};

/// Returns `true` only when [videoPath] points to a video that the Android
/// client can actually play.
///
/// The check is intentionally conservative:
/// - `null`, empty, or whitespace-only paths are not playable.
/// - If the value parses as a URI *with* a scheme, only `http`/`https` are
///   allowed. Other schemes (e.g. `ftp`, `file`) are rejected.
/// - The candidate filename (last path segment) must carry a file extension
///   whose lowercased value is a supported video format.
bool hasPlayableExerciseVideo(String? videoPath) {
  final trimmed = videoPath?.trim() ?? '';
  if (trimmed.isEmpty) return false;

  final uri = Uri.tryParse(trimmed);

  String candidate = trimmed;
  if (uri != null && uri.hasScheme) {
    if (!_playableUriSchemes.contains(uri.scheme.toLowerCase())) {
      return false;
    }
    if (uri.pathSegments.isEmpty) return false;
    candidate = uri.pathSegments.last;
  }

  final dotIndex = candidate.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == candidate.length - 1) return false;

  final extension = candidate.substring(dotIndex + 1).toLowerCase();
  return _playableVideoExtensions.contains(extension);
}

/// Displays exercise media at a stable 16:9 aspect ratio.
///
/// When [videoPath] points to a playable video the widget surfaces a play
/// affordance. Otherwise it truthfully exposes a neutral "No video available"
/// state instead of a misleading placeholder.
class ExerciseMedia extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasVideo = hasPlayableExerciseVideo(videoPath);

    final icon =
        hasVideo ? Icons.play_circle_outline : Icons.videocam_off_outlined;
    final label = hasVideo ? 'Play video guide' : 'No video available';
    final semanticsBase =
        hasVideo ? 'Exercise video available' : 'No video available';
    final semanticsLabel = exerciseName != null
        ? '$semanticsBase for $exerciseName'
        : semanticsBase;

    return Semantics(
      label: semanticsLabel,
      image: true,
      container: true,
      child: ExcludeSemantics(
        child: AspectRatio(
          key: const Key('exercise-media'),
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
          ),
        ),
      ),
    );
  }
}
