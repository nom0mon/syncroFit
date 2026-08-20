import 'package:synchrofit/shared/models/models.dart';

/// Mock seed data used by all mock repository implementations.
/// All fields are non-null and non-empty to satisfy Requirement 14.4.
class MockData {
  MockData._();

  // --- Sample User ---

  static final user = User(
    id: 'user-001',
    firstName: 'Alex',
    lastName: 'Johnson',
    email: 'alex.johnson@example.com',
    createdAt: DateTime(2024, 1, 15),
  );

  // --- User Profile ---

  static const userProfile = UserProfile(
    userId: 'user-001',
    firstName: 'Alex',
    lastName: 'Johnson',
    age: 28,
    heightCm: 178.0,
    weightKg: 75.0,
    gender: Gender.male,
    fitnessGoal: FitnessGoal.buildMuscle,
    fitnessLevel: FitnessLevel.intermediate,
    workoutPreference: WorkoutPreference.gym,
    workoutAvailability: [
      DayOfWeek.monday,
      DayOfWeek.wednesday,
      DayOfWeek.friday,
    ],
  );

  // --- Exercises (12 exercises across 6 muscle groups) ---

  static const exercises = <Exercise>[
    Exercise(
      id: 'ex-001',
      name: 'Barbell Bench Press',
      muscleGroup: 'Chest',
      difficulty: DifficultyLevel.intermediate,
      instructions: [
        'Lie on a flat bench.',
        'Grip the barbell wider than shoulder-width.',
        'Lower the bar to mid-chest.',
        'Press bar back up.'
      ],
      equipment: 'Barbell, Bench',
      defaultDurationSeconds: 45,
      defaultSets: 4,
      defaultReps: 10,
      videoPath: 'assets/images/bench_press.png',
    ),
    Exercise(
      id: 'ex-002',
      name: 'Incline Dumbbell Press',
      muscleGroup: 'Chest',
      difficulty: DifficultyLevel.beginner,
      instructions: [
        'Set bench to 30-45 degrees.',
        'Hold dumbbells at shoulder height.',
        'Press up until arms extended.',
        'Lower with control.'
      ],
      equipment: 'Dumbbells, Incline Bench',
      defaultDurationSeconds: 40,
      defaultSets: 3,
      defaultReps: 12,
      videoPath: 'assets/images/incline_press.png',
    ),
    Exercise(
      id: 'ex-003',
      name: 'Pull-Ups',
      muscleGroup: 'Back',
      difficulty: DifficultyLevel.advanced,
      instructions: [
        'Hang from bar with overhand grip.',
        'Pull up until chin above bar.',
        'Lower with control.'
      ],
      equipment: 'Pull-up Bar',
      defaultDurationSeconds: 40,
      defaultSets: 3,
      defaultReps: 8,
      videoPath: 'assets/images/pull_ups.png',
    ),
    Exercise(
      id: 'ex-004',
      name: 'Barbell Row',
      muscleGroup: 'Back',
      difficulty: DifficultyLevel.intermediate,
      instructions: [
        'Bend at hips with feet shoulder-width.',
        'Grip barbell overhand.',
        'Pull bar to lower chest.',
        'Lower with control.'
      ],
      equipment: 'Barbell',
      defaultDurationSeconds: 45,
      defaultSets: 4,
      defaultReps: 10,
      videoPath: 'assets/images/barbell_row.png',
    ),
    Exercise(
      id: 'ex-005',
      name: 'Barbell Squat',
      muscleGroup: 'Legs',
      difficulty: DifficultyLevel.intermediate,
      instructions: [
        'Position bar on upper back.',
        'Stand feet shoulder-width apart.',
        'Lower until thighs parallel.',
        'Drive through heels.'
      ],
      equipment: 'Barbell, Squat Rack',
      defaultDurationSeconds: 50,
      defaultSets: 4,
      defaultReps: 8,
      videoPath: 'assets/images/squat.png',
    ),
    Exercise(
      id: 'ex-006',
      name: 'Lunges',
      muscleGroup: 'Legs',
      difficulty: DifficultyLevel.beginner,
      instructions: [
        'Stand with feet together.',
        'Step forward with one leg.',
        'Lower until both knees at 90 degrees.',
        'Push off to return.'
      ],
      defaultDurationSeconds: 40,
      defaultSets: 3,
      defaultReps: 12,
      videoPath: 'assets/images/lunges.png',
    ),
    Exercise(
      id: 'ex-007',
      name: 'Overhead Press',
      muscleGroup: 'Shoulders',
      difficulty: DifficultyLevel.intermediate,
      instructions: [
        'Stand with bar at shoulder height.',
        'Press overhead until arms extended.',
        'Lower back to shoulders.'
      ],
      equipment: 'Barbell',
      defaultDurationSeconds: 40,
      defaultSets: 4,
      defaultReps: 8,
      videoPath: 'assets/images/overhead_press.png',
    ),
    Exercise(
      id: 'ex-008',
      name: 'Lateral Raises',
      muscleGroup: 'Shoulders',
      difficulty: DifficultyLevel.beginner,
      instructions: [
        'Stand with dumbbells at sides.',
        'Raise arms to sides until parallel.',
        'Lower slowly.'
      ],
      equipment: 'Dumbbells',
      defaultDurationSeconds: 30,
      defaultSets: 3,
      defaultReps: 15,
      videoPath: 'assets/images/lateral_raises.png',
    ),
    Exercise(
      id: 'ex-009',
      name: 'Bicep Curls',
      muscleGroup: 'Arms',
      difficulty: DifficultyLevel.beginner,
      instructions: [
        'Stand with dumbbells at arm length.',
        'Curl weights toward shoulders.',
        'Squeeze at top then lower.'
      ],
      equipment: 'Dumbbells',
      defaultDurationSeconds: 30,
      defaultSets: 3,
      defaultReps: 12,
      videoPath: 'assets/images/bicep_curls.png',
    ),
    Exercise(
      id: 'ex-010',
      name: 'Tricep Dips',
      muscleGroup: 'Arms',
      difficulty: DifficultyLevel.intermediate,
      instructions: [
        'Grip parallel bars arms extended.',
        'Lower body bending elbows to 90.',
        'Push back up.'
      ],
      equipment: 'Dip Bars',
      defaultDurationSeconds: 35,
      defaultSets: 3,
      defaultReps: 10,
      videoPath: 'assets/images/tricep_dips.png',
    ),
    Exercise(
      id: 'ex-011',
      name: 'Plank',
      muscleGroup: 'Core',
      difficulty: DifficultyLevel.beginner,
      instructions: [
        'Forearms on ground in push-up position.',
        'Keep body straight head to heels.',
        'Hold position.'
      ],
      defaultDurationSeconds: 60,
      defaultSets: 3,
      defaultReps: 1,
      videoPath: 'assets/images/plank.png',
    ),
    Exercise(
      id: 'ex-012',
      name: 'Russian Twist',
      muscleGroup: 'Core',
      difficulty: DifficultyLevel.intermediate,
      instructions: [
        'Sit with knees bent lean back.',
        'Hold weight at chest height.',
        'Rotate torso side to side.'
      ],
      equipment: 'Medicine Ball',
      defaultDurationSeconds: 40,
      defaultSets: 3,
      defaultReps: 20,
      videoPath: 'assets/images/russian_twist.png',
    ),
  ];

  // --- Workouts (3 workouts, each with 4+ exercises) ---

  static const workouts = <Workout>[
    Workout(
      id: 'wk-001',
      name: 'Upper Body Power',
      estimatedDurationMinutes: 45,
      exercises: [
        WorkoutExercise(
            exerciseId: 1, sets: 4, reps: 10, durationSeconds: 45, order: 1),
        WorkoutExercise(
            exerciseId: 3, sets: 3, reps: 8, durationSeconds: 40, order: 2),
        WorkoutExercise(
            exerciseId: 7, sets: 4, reps: 8, durationSeconds: 40, order: 3),
        WorkoutExercise(
            exerciseId: 9, sets: 3, reps: 12, durationSeconds: 30, order: 4),
        WorkoutExercise(
            exerciseId: 10, sets: 3, reps: 10, durationSeconds: 35, order: 5),
      ],
    ),
    Workout(
      id: 'wk-002',
      name: 'Leg Day',
      estimatedDurationMinutes: 50,
      exercises: [
        WorkoutExercise(
            exerciseId: 5, sets: 4, reps: 8, durationSeconds: 50, order: 1),
        WorkoutExercise(
            exerciseId: 6, sets: 3, reps: 12, durationSeconds: 40, order: 2),
        WorkoutExercise(
            exerciseId: 11, sets: 3, reps: 1, durationSeconds: 60, order: 3),
        WorkoutExercise(
            exerciseId: 12, sets: 3, reps: 20, durationSeconds: 40, order: 4),
      ],
    ),
    Workout(
      id: 'wk-003',
      name: 'Full Body Circuit',
      estimatedDurationMinutes: 40,
      exercises: [
        WorkoutExercise(
            exerciseId: 2, sets: 3, reps: 12, durationSeconds: 40, order: 1),
        WorkoutExercise(
            exerciseId: 4, sets: 4, reps: 10, durationSeconds: 45, order: 2),
        WorkoutExercise(
            exerciseId: 8, sets: 3, reps: 15, durationSeconds: 30, order: 3),
        WorkoutExercise(
            exerciseId: 5, sets: 3, reps: 10, durationSeconds: 50, order: 4),
      ],
    ),
  ];

  // --- Posts (5 posts, each with 2+ comments) ---

  static final posts = <Post>[
    Post(
        id: 'post-001',
        authorName: 'Sarah Connor',
        content:
            'Just finished my first 5K run in under 25 minutes! The training plan really works. Consistency is key.',
        timestamp: DateTime(2024, 6, 10, 14, 30),
        likeCount: 24,
        isLikedByCurrentUser: false,
        comments: [
          Comment(
              id: 'cmt-001',
              postId: 'post-001',
              authorName: 'Mike Ross',
              text: 'Amazing progress! Keep it up!',
              timestamp: DateTime(2024, 6, 10, 15, 0)),
          Comment(
              id: 'cmt-002',
              postId: 'post-001',
              authorName: 'Alex Johnson',
              text: 'Inspiring! What plan did you follow?',
              timestamp: DateTime(2024, 6, 10, 15, 30)),
        ]),
    Post(
        id: 'post-002',
        authorName: 'Mike Ross',
        content:
            'New personal record on deadlift today - 180kg! Been working toward this for months. Remember to keep your form tight and progress gradually.',
        timestamp: DateTime(2024, 6, 9, 18, 0),
        likeCount: 42,
        isLikedByCurrentUser: true,
        comments: [
          Comment(
              id: 'cmt-003',
              postId: 'post-002',
              authorName: 'Sarah Connor',
              text: 'Beast mode! That is impressive.',
              timestamp: DateTime(2024, 6, 9, 19, 0)),
          Comment(
              id: 'cmt-004',
              postId: 'post-002',
              authorName: 'Alex Kim',
              text: 'Goals! Working toward 140kg.',
              timestamp: DateTime(2024, 6, 9, 20, 0)),
        ]),
    Post(
        id: 'post-003',
        authorName: 'Alex Kim',
        content:
            'Anyone else find that morning workouts boost their productivity? I have been waking up at 5:30 AM for the past month and it has been a game changer for my energy levels and focus throughout the day at work.',
        timestamp: DateTime(2024, 6, 8, 7, 0),
        likeCount: 18,
        isLikedByCurrentUser: false,
        comments: [
          Comment(
              id: 'cmt-005',
              postId: 'post-003',
              authorName: 'Alex Johnson',
              text: 'Totally agree! Morning workouts are the best.',
              timestamp: DateTime(2024, 6, 8, 8, 0)),
          Comment(
              id: 'cmt-006',
              postId: 'post-003',
              authorName: 'Emma Wilson',
              text: 'I wish I could wake up that early!',
              timestamp: DateTime(2024, 6, 8, 9, 30)),
        ]),
    Post(
        id: 'post-004',
        authorName: 'Emma Wilson',
        content:
            'Rest days are just as important as training days. Your muscles grow during recovery, not during the workout. Make sure you are getting enough sleep and nutrition!',
        timestamp: DateTime(2024, 6, 7, 12, 0),
        likeCount: 31,
        isLikedByCurrentUser: true,
        comments: [
          Comment(
              id: 'cmt-007',
              postId: 'post-004',
              authorName: 'Mike Ross',
              text: 'So true! Recovery is underrated.',
              timestamp: DateTime(2024, 6, 7, 14, 0)),
          Comment(
              id: 'cmt-008',
              postId: 'post-004',
              authorName: 'Alex Kim',
              text: 'Needed this reminder. Thanks!',
              timestamp: DateTime(2024, 6, 7, 15, 0)),
        ]),
    Post(
        id: 'post-005',
        authorName: 'David Park',
        content:
            'Started incorporating yoga into my routine twice a week. The flexibility gains have helped my lifting form significantly.',
        timestamp: DateTime(2024, 6, 6, 10, 0),
        likeCount: 15,
        isLikedByCurrentUser: false,
        comments: [
          Comment(
              id: 'cmt-009',
              postId: 'post-005',
              authorName: 'Emma Wilson',
              text: 'Yoga is amazing for recovery too!',
              timestamp: DateTime(2024, 6, 6, 11, 0)),
          Comment(
              id: 'cmt-010',
              postId: 'post-005',
              authorName: 'Alex Johnson',
              text: 'Which yoga style do you recommend?',
              timestamp: DateTime(2024, 6, 6, 12, 30)),
        ]),
  ];

  // --- Trainers (3 trainers with available time slots) ---

  static final trainers = <Trainer>[
    Trainer(
        id: 'trainer-001',
        name: 'Chris Martinez',
        bio:
            'Certified personal trainer with 8 years of experience in strength and conditioning.',
        specialization: 'Strength & Conditioning',
        rating: 4.8,
        experienceYears: 8,
        availableSlots: [
          TimeSlot(
              id: 'ts-001',
              date: DateTime(2024, 6, 15),
              time: '09:00 AM',
              isBooked: false),
          TimeSlot(
              id: 'ts-002',
              date: DateTime(2024, 6, 15),
              time: '11:00 AM',
              isBooked: false),
          TimeSlot(
              id: 'ts-003',
              date: DateTime(2024, 6, 16),
              time: '02:00 PM',
              isBooked: true),
        ],
        avatarPlaceholder: 'assets/images/trainer_chris.png'),
    Trainer(
        id: 'trainer-002',
        name: 'Jessica Lee',
        bio:
            'Yoga instructor and wellness coach focusing on flexibility and functional movement.',
        specialization: 'Yoga & Wellness',
        rating: 4.9,
        experienceYears: 6,
        availableSlots: [
          TimeSlot(
              id: 'ts-004',
              date: DateTime(2024, 6, 15),
              time: '08:00 AM',
              isBooked: false),
          TimeSlot(
              id: 'ts-005',
              date: DateTime(2024, 6, 16),
              time: '10:00 AM',
              isBooked: false),
          TimeSlot(
              id: 'ts-006',
              date: DateTime(2024, 6, 17),
              time: '04:00 PM',
              isBooked: false),
        ],
        avatarPlaceholder: 'assets/images/trainer_jessica.png'),
    Trainer(
        id: 'trainer-003',
        name: 'Marcus Johnson',
        bio:
            'Former bodybuilder turned nutrition and training coach specializing in body recomposition.',
        specialization: 'Bodybuilding & Nutrition',
        rating: 4.7,
        experienceYears: 10,
        availableSlots: [
          TimeSlot(
              id: 'ts-007',
              date: DateTime(2024, 6, 15),
              time: '03:00 PM',
              isBooked: false),
          TimeSlot(
              id: 'ts-008',
              date: DateTime(2024, 6, 17),
              time: '09:00 AM',
              isBooked: true),
          TimeSlot(
              id: 'ts-009',
              date: DateTime(2024, 6, 18),
              time: '01:00 PM',
              isBooked: false),
        ],
        avatarPlaceholder: 'assets/images/trainer_marcus.png'),
  ];

  // --- Notifications (5 notifications, 3 unread) ---

  static final notifications = <NotificationItem>[
    NotificationItem(
        id: 'notif-001',
        title: 'Time for your workout!',
        description: 'Your Upper Body Power workout is scheduled for today.',
        timestamp: DateTime(2024, 6, 10, 8, 0),
        type: NotificationType.workoutReminder,
        isRead: false),
    NotificationItem(
        id: 'notif-002',
        title: 'New achievement unlocked!',
        description:
            'Congratulations! You completed 7 consecutive workout days.',
        timestamp: DateTime(2024, 6, 9, 20, 0),
        type: NotificationType.achievement,
        isRead: false),
    NotificationItem(
        id: 'notif-003',
        title: 'Sarah liked your post',
        description:
            'Sarah Connor liked your community post about morning workouts.',
        timestamp: DateTime(2024, 6, 9, 15, 0),
        type: NotificationType.communityInteraction,
        isRead: true),
    NotificationItem(
        id: 'notif-004',
        title: 'App update available',
        description:
            'A new version of SyncroFit is available with improved features.',
        timestamp: DateTime(2024, 6, 8, 10, 0),
        type: NotificationType.systemUpdate,
        isRead: true),
    NotificationItem(
        id: 'notif-005',
        title: 'Weekly progress report',
        description:
            'You completed 4 out of 5 planned workouts this week. Great job!',
        timestamp: DateTime(2024, 6, 7, 18, 0),
        type: NotificationType.achievement,
        isRead: false),
  ];

  // --- Progress Records removed (derived from workout_history now) ---

  // --- Workout Sessions removed (replaced by WorkoutHistory) ---
}
