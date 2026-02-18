import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/constants/app_assets.dart';
import '../models/lesson.dart';
import '../models/word.dart';

class LessonRepository {
  const LessonRepository({this.assetPath = AppAssets.lessonJson});

  final String assetPath;

  Future<List<Lesson>> loadLessons() async {
    final rawJson = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(rawJson);

    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'lesson.json must be a JSON array at the top level.',
      );
    }

    return decoded
        .map((dynamic item) => Lesson.fromJson(item as Map<String, dynamic>))
        .map(_normalizeLessonAssets)
        .toList(growable: false);
  }

  Lesson _normalizeLessonAssets(Lesson lesson) {
    return lesson.copyWith(
      icon: _normalizeIconPath(lesson.icon),
      words: lesson.words
          .map((word) => _normalizeWordAssets(word))
          .toList(growable: false),
    );
  }

  Word _normalizeWordAssets(Word word) {
    return word.copyWith(
      image: _normalizeIconPath(word.image),
      audio: _normalizeAudioPath(word.audio),
    );
  }

  String _normalizeIconPath(String rawPath) {
    final String trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (trimmed.startsWith('assets/icons/')) {
      return trimmed;
    }
    if (trimmed.startsWith('icons/')) {
      return 'assets/$trimmed';
    }
    if (trimmed.startsWith('assets/')) {
      return trimmed;
    }
    return 'assets/icons/$trimmed';
  }

  String _normalizeAudioPath(String rawPath) {
    final String trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (trimmed.startsWith('assets/audio/')) {
      return trimmed;
    }
    if (trimmed.startsWith('audio/')) {
      return 'assets/$trimmed';
    }
    if (trimmed.startsWith('assets/')) {
      return trimmed;
    }
    return 'assets/audio/$trimmed';
  }
}
