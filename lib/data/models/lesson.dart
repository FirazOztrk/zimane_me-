import 'word.dart';

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.icon,
    required this.words,
    this.narReward = 5,
  });

  final String id;
  final String title;
  final String icon;
  final List<Word> words;
  final int narReward;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final wordsJson = json['words'] as List<dynamic>? ?? <dynamic>[];

    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String,
      words: wordsJson
          .map((dynamic item) => Word.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      narReward: (json['narReward'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'narReward': narReward,
      'words': words.map((word) => word.toJson()).toList(growable: false),
    };
  }

  Lesson copyWith({
    String? id,
    String? title,
    String? icon,
    List<Word>? words,
    int? narReward,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      words: words ?? this.words,
      narReward: narReward ?? this.narReward,
    );
  }
}
