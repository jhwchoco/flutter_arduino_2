import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// 운동 종류를 정의하는 열거형
enum ExerciseType {
  shoulderPress,
  unknown,
}

// 운동 정보를 담는 클래스
class Exercise {
  final ExerciseType type;
  final String name;
  final String description;
  final String imageUrl;

  const Exercise({
    required this.type,
    required this.name,
    this.description = '',
    this.imageUrl = '',
  });
}

// 운동 세션의 기록을 담는 클래스
class WorkoutSession {
  final String id;
  final ExerciseType exerciseType;
  final int targetReps;
  final int completedReps;
  final DateTime startTime;
  final DateTime endTime;
  final List<FeedbackEntry> feedbackLog;

  WorkoutSession({
    required this.id,
    required this.exerciseType,
    required this.targetReps,
    required this.completedReps,
    required this.startTime,
    required this.endTime,
    this.feedbackLog = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseType': exerciseType.name,
    'targetReps': targetReps,
    'completedReps': completedReps,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'feedbackLog': feedbackLog.map((e) => e.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'],
    exerciseType: ExerciseType.values.firstWhere(
            (e) => e.name == json['exerciseType'],
        orElse: () => ExerciseType.unknown),
    completedReps: json['completedReps'],
    targetReps: json['targetReps'],
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    feedbackLog: (json['feedbackLog'] as List)
        .map((e) => FeedbackEntry.fromJson(e))
        .toList(),
  );
}

// 특정 시점의 자세 피드백을 담는 클래스
class FeedbackEntry {
  final DateTime timestamp;
  final String message;
  final List<PostureRule> violatedRules;

  FeedbackEntry({
    required this.timestamp,
    required this.message,
    this.violatedRules = const [],
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    'violatedRules': violatedRules.map((e) => e.name).toList(),
  };

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
    timestamp: DateTime.parse(json['timestamp']),
    message: json['message'],
    violatedRules: (json['violatedRules'] as List)
        .map((e) => PostureRule.values.firstWhere((rule) => rule.name == e))
        .toList(),
  );
}

// 자세 분석 규칙을 정의하는 열거형
enum PostureRule {
  armNotFullyExtended,
  torsoTooLeaned,
  elbowTooFarBack,
  dumbbellHeightUneven,
  dumbbellNotHorizontal,
}

// 운동 횟수 카운팅 상태
enum RepetitionState {
  down,
  up,
  transition,
  initial,
}