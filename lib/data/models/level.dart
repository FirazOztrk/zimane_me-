import 'lesson.dart';

enum LevelStatus { locked, unlocked, completed }

class Level {
  const Level({
    required this.id,
    required this.lessonId,
    required this.order,
    this.status = LevelStatus.locked,
    this.starsEarned = 0,
  });

  final String id;
  final String lessonId;
  final int order;
  final LevelStatus status;
  final int starsEarned;

  bool get isLocked => status == LevelStatus.locked;
  bool get isCompleted => status == LevelStatus.completed;

  factory Level.fromLesson(
    Lesson lesson, {
    required int order,
    LevelStatus status = LevelStatus.locked,
  }) {
    return Level(
      id: 'level_${order + 1}_${lesson.id}',
      lessonId: lesson.id,
      order: order,
      status: status,
    );
  }

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'] as String,
      lessonId: json['lessonId'] as String,
      order: (json['order'] as num).toInt(),
      status: _parseLevelStatus(json['status'] as String?),
      starsEarned: (json['starsEarned'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lessonId': lessonId,
      'order': order,
      'status': status.name,
      'starsEarned': starsEarned,
    };
  }

  Level copyWith({
    String? id,
    String? lessonId,
    int? order,
    LevelStatus? status,
    int? starsEarned,
  }) {
    return Level(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      order: order ?? this.order,
      status: status ?? this.status,
      starsEarned: starsEarned ?? this.starsEarned,
    );
  }
}

LevelStatus _parseLevelStatus(String? value) {
  switch (value) {
    case 'unlocked':
      return LevelStatus.unlocked;
    case 'completed':
      return LevelStatus.completed;
    case 'locked':
    default:
      return LevelStatus.locked;
  }
}
