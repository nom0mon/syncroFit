/// Exercise demonstration videos currently bundled with the Android app.
///
/// The backend assigns a predictable video path to every exercise, including
/// demonstrations that have not been produced yet. Keeping this manifest
/// prevents those future paths from being presented as playable assets.
const Set<String> bundledExerciseVideos = {
  'assets/videos/barbell_back_squat.mp4',
  'assets/videos/barbell_bent_over_row.mp4',
  'assets/videos/barbell_curl.mp4',
  'assets/videos/barbell_deadlift.mp4',
  'assets/videos/chin_up.mp4',
  'assets/videos/dumbbell_bicep_curl.mp4',
  'assets/videos/dumbbell_overhead_press.mp4',
  'assets/videos/dumbbell_overhead_tricep_extension.mp4',
  'assets/videos/dumbbell_romanian_deadlift.mp4',
  'assets/videos/dumbbell_single_arm_row.mp4',
  'assets/videos/hanging_leg_raise.mp4',
  'assets/videos/leg_press.mp4',
  'assets/videos/pull_up.mp4',
  'assets/videos/tricep_dips.mp4',
};

bool isBundledExerciseVideo(String? path) {
  return bundledExerciseVideos.contains(path?.trim());
}
