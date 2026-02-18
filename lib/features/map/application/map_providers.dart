import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_assets.dart';
import '../../../data/models/lesson.dart';
import '../../../data/models/level.dart';
import '../../../data/repositories/lesson_repository.dart';

const String _kPrefsNars = 'ziman_nars';
const String _kPrefsHighestUnlockedIndex = 'ziman_highest_unlocked_index';
const String _kPrefsCompletedLessonIds = 'ziman_completed_lesson_ids';
const String _kPrefsSelectedAvatar = 'ziman_selected_avatar';
const String _kPrefsCityCompletedSlots = 'ziman_city_completed_slots';
const String _kPrefsCurrentCityIndex = 'ziman_current_city_index';
const String _kPrefsCurrentLevelIndex = 'ziman_current_level_index';
const bool _kDebugUnlockAllCities = true;

const String kDefaultAvatarPath = 'assets/avatars/kewe.png';

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return const LessonRepository();
});

final lessonProvider =
    AsyncNotifierProvider<LessonNotifier, LessonProgressState>(
      LessonNotifier.new,
    );

final mapProvider = AsyncNotifierProvider<MapNotifier, MapProgressState>(
  MapNotifier.new,
);

class LessonProgressState {
  const LessonProgressState({
    required this.lessons,
    required this.highestUnlockedIndex,
    required this.completedLessonIds,
    required this.nars,
    required this.selectedAvatarPath,
  });

  final List<Lesson> lessons;
  final int highestUnlockedIndex;
  final Set<String> completedLessonIds;
  final int nars;
  final String selectedAvatarPath;

  List<Level> get levels {
    return List<Level>.generate(lessons.length, (index) {
      final Lesson lesson = lessons[index];
      final bool completed = completedLessonIds.contains(lesson.id);
      final bool unlocked = index <= highestUnlockedIndex;
      return Level.fromLesson(
        lesson,
        order: index,
        status: completed
            ? LevelStatus.completed
            : unlocked
            ? LevelStatus.unlocked
            : LevelStatus.locked,
      );
    });
  }

  int get activeLevelIndex {
    if (lessons.isEmpty) {
      return 0;
    }
    for (int index = 0; index < lessons.length; index++) {
      final bool unlocked = index <= highestUnlockedIndex;
      final bool completed = completedLessonIds.contains(lessons[index].id);
      if (unlocked && !completed) {
        return index;
      }
    }
    return highestUnlockedIndex.clamp(0, lessons.length - 1);
  }

  LessonProgressState copyWith({
    List<Lesson>? lessons,
    int? highestUnlockedIndex,
    Set<String>? completedLessonIds,
    int? nars,
    String? selectedAvatarPath,
  }) {
    return LessonProgressState(
      lessons: lessons ?? this.lessons,
      highestUnlockedIndex: highestUnlockedIndex ?? this.highestUnlockedIndex,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      nars: nars ?? this.nars,
      selectedAvatarPath: selectedAvatarPath ?? this.selectedAvatarPath,
    );
  }
}

class LessonNotifier extends AsyncNotifier<LessonProgressState> {
  SharedPreferences? _prefs;

  @override
  Future<LessonProgressState> build() async {
    final LessonRepository repository = ref.read(lessonRepositoryProvider);
    final List<Lesson> lessons = await repository.loadLessons();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final int fallbackUnlocked = lessons.isEmpty ? 0 : 0;
    final int persistedUnlocked =
        prefs.getInt(_kPrefsHighestUnlockedIndex) ?? fallbackUnlocked;
    final int clampedUnlocked = lessons.isEmpty
        ? 0
        : persistedUnlocked.clamp(0, lessons.length - 1);

    final List<String> completedList =
        prefs.getStringList(_kPrefsCompletedLessonIds) ?? <String>[];
    final Set<String> completedLessonIds = completedList.toSet();
    final int nars = prefs.getInt(_kPrefsNars) ?? 0;
    final String selectedAvatarPath =
        prefs.getString(_kPrefsSelectedAvatar) ?? kDefaultAvatarPath;

    final LessonProgressState initial = LessonProgressState(
      lessons: lessons,
      highestUnlockedIndex: clampedUnlocked,
      completedLessonIds: completedLessonIds,
      nars: nars,
      selectedAvatarPath: selectedAvatarPath,
    );

    if (lessons.isNotEmpty &&
        !completedLessonIds.contains(lessons.first.id) &&
        clampedUnlocked == 0) {
      await _persistProgress(initial);
    }

    return initial;
  }

  Future<void> selectAvatar(String avatarPath) async {
    final LessonProgressState? current = state.valueOrNull;
    if (current == null) {
      final SharedPreferences prefs =
          _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setString(_kPrefsSelectedAvatar, avatarPath);
      return;
    }
    final LessonProgressState next = current.copyWith(
      selectedAvatarPath: avatarPath,
    );
    state = AsyncData(next);
    await _persistProgress(next);
  }

  Future<void> awardNar([int amount = 1]) async {
    final LessonProgressState? current = state.valueOrNull;
    if (current == null || amount <= 0) {
      return;
    }
    final LessonProgressState next = current.copyWith(
      nars: current.nars + amount,
    );
    state = AsyncData(next);
    await _persistProgress(next);
  }

  Future<void> completeLevel({
    required int levelIndex,
    required int earnedNars,
  }) async {
    final LessonProgressState? current = state.valueOrNull;
    if (current == null ||
        levelIndex < 0 ||
        levelIndex >= current.lessons.length) {
      return;
    }

    final Lesson lesson = current.lessons[levelIndex];
    final Set<String> completed = <String>{
      ...current.completedLessonIds,
      lesson.id,
    };
    final int unlocked = (levelIndex + 1).clamp(0, current.lessons.length - 1);
    final int highestUnlocked = unlocked > current.highestUnlockedIndex
        ? unlocked
        : current.highestUnlockedIndex;

    final LessonProgressState next = current.copyWith(
      completedLessonIds: completed,
      highestUnlockedIndex: highestUnlocked,
      nars: current.nars + (earnedNars > 0 ? earnedNars : 0),
    );
    state = AsyncData(next);
    await _persistProgress(next);
  }

  Future<void> resetProgress() async {
    final LessonProgressState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final LessonProgressState next = current.copyWith(
      highestUnlockedIndex: current.lessons.isEmpty ? 0 : 0,
      completedLessonIds: <String>{},
      nars: 0,
    );
    state = AsyncData(next);
    await _persistProgress(next);
  }

  Future<void> _persistProgress(LessonProgressState progress) async {
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_kPrefsNars, progress.nars);
    await prefs.setInt(
      _kPrefsHighestUnlockedIndex,
      progress.highestUnlockedIndex,
    );
    await prefs.setStringList(
      _kPrefsCompletedLessonIds,
      progress.completedLessonIds.toList(growable: false),
    );
    await prefs.setString(_kPrefsSelectedAvatar, progress.selectedAvatarPath);
  }
}

class CityMapDefinition {
  const CityMapDefinition({
    required this.id,
    required this.name,
    required this.background,
    required this.levelIds,
    required this.nodeAnchors,
  });

  static const int levelsPerCity = 6;
  static const List<Offset> defaultAnchors = <Offset>[
    Offset(0.22, 0.80),
    Offset(0.50, 0.68),
    Offset(0.74, 0.56),
    Offset(0.48, 0.45),
    Offset(0.24, 0.34),
    Offset(0.52, 0.22),
  ];

  final String id;
  final String name;
  final String background;
  final List<String> levelIds;
  final List<Offset> nodeAnchors;

  factory CityMapDefinition.fromJson(
    Map<String, dynamic> json, {
    required List<String> fallbackLevelIds,
  }) {
    final String id = (json['id'] as String? ?? '').trim();
    final String name = (json['name'] as String? ?? '').trim();
    final String background = (json['background'] as String? ?? '').trim();

    final List<String> parsedIds =
        (json['levels'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);

    final List<Offset> parsedAnchors = _parseAnchors(json['nodeAnchors']);

    return CityMapDefinition(
      id: id.isEmpty ? 'city_${name.toLowerCase()}' : id,
      name: name.isEmpty ? 'City' : name,
      background: background.isEmpty ? AppAssets.mapReference : background,
      levelIds: _normalizeLevelIds(parsedIds, fallbackLevelIds),
      nodeAnchors: _normalizeAnchors(parsedAnchors),
    );
  }

  static List<String> _normalizeLevelIds(
    List<String> requested,
    List<String> fallback,
  ) {
    List<String> source = requested;
    if (source.isEmpty) {
      source = fallback;
    }
    if (source.isEmpty) {
      source = List<String>.generate(
        levelsPerCity,
        (index) => 'missing_lesson_$index',
      );
    }

    return List<String>.generate(levelsPerCity, (index) {
      if (index < source.length) {
        return source[index];
      }
      return source[index % source.length];
    }, growable: false);
  }

  static List<Offset> _normalizeAnchors(List<Offset> parsed) {
    final List<Offset> source = parsed.isEmpty ? defaultAnchors : parsed;
    return List<Offset>.generate(levelsPerCity, (index) {
      final Offset offset = index < source.length
          ? source[index]
          : source[index % source.length];
      return Offset(
        offset.dx.clamp(0.12, 0.88).toDouble(),
        offset.dy.clamp(0.12, 0.88).toDouble(),
      );
    }, growable: false);
  }

  static List<Offset> _parseAnchors(dynamic raw) {
    if (raw is! List<dynamic>) {
      return const <Offset>[];
    }
    final List<Offset> parsed = <Offset>[];
    for (final dynamic item in raw) {
      if (item is Map<String, dynamic>) {
        final num? x = item['x'] as num?;
        final num? y = item['y'] as num?;
        if (x != null && y != null) {
          parsed.add(Offset(x.toDouble(), y.toDouble()));
        }
      } else if (item is List<dynamic> && item.length >= 2) {
        final num? x = item[0] as num?;
        final num? y = item[1] as num?;
        if (x != null && y != null) {
          parsed.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
    return parsed;
  }
}

class MapProgressState {
  const MapProgressState({
    required this.lessons,
    required this.cities,
    required this.completedLevelIndexesByCity,
    required this.nars,
    required this.selectedAvatarPath,
    required this.currentCityIndex,
    required this.currentLevelIndex,
  });

  final List<Lesson> lessons;
  final List<CityMapDefinition> cities;
  final Map<String, Set<int>> completedLevelIndexesByCity;
  final int nars;
  final String selectedAvatarPath;
  final int currentCityIndex;
  final int currentLevelIndex;

  int get totalLevels =>
      cities.fold<int>(0, (sum, city) => sum + city.levelIds.length);

  int get totalCompletedLevels => completedLevelIndexesByCity.values.fold<int>(
    0,
    (sum, completed) => sum + completed.length,
  );

  int get highestUnlockedCityIndex {
    if (cities.isEmpty) {
      return 0;
    }
    if (kDebugMode && _kDebugUnlockAllCities) {
      return cities.length - 1;
    }
    int unlocked = 0;
    for (int index = 0; index < cities.length - 1; index++) {
      if (isCityCompleted(index)) {
        unlocked = index + 1;
      } else {
        break;
      }
    }
    return unlocked;
  }

  // TODO: Test modu - tüm şehirler açık. Testi bitince eski haline getir.
  bool isCityUnlocked(int cityIndex) {
    if (cityIndex < 0 || cityIndex >= cities.length) {
      return false;
    }
    return true; // was: cityIndex <= highestUnlockedCityIndex
  }

  bool isCityCompleted(int cityIndex) {
    if (cityIndex < 0 || cityIndex >= cities.length) {
      return false;
    }
    final String cityId = cities[cityIndex].id;
    final int completed = completedLevelIndexesByCity[cityId]?.length ?? 0;
    return completed >= cities[cityIndex].levelIds.length;
  }

  bool isLevelCompleted(int cityIndex, int levelIndex) {
    if (cityIndex < 0 || cityIndex >= cities.length) {
      return false;
    }
    final String cityId = cities[cityIndex].id;
    return completedLevelIndexesByCity[cityId]?.contains(levelIndex) ?? false;
  }

  // TODO: Test modu - tüm seviyeler açık. Testi bitince eski haline getir.
  bool isLevelUnlocked(int cityIndex, int levelIndex) {
    if (!isCityUnlocked(cityIndex)) {
      return false;
    }
    return true; // was: levelIndex <= 0 || isLevelCompleted(cityIndex, levelIndex - 1)
  }

  int firstIncompleteLevelInCity(int cityIndex) {
    if (cityIndex < 0 || cityIndex >= cities.length) {
      return 0;
    }
    final int levelCount = cities[cityIndex].levelIds.length;
    for (int levelIndex = 0; levelIndex < levelCount; levelIndex++) {
      if (!isLevelCompleted(cityIndex, levelIndex)) {
        return levelIndex;
      }
    }
    return math.max(0, levelCount - 1);
  }

  Lesson lessonForSlot(int cityIndex, int levelIndex) {
    final int lessonIndex = lessonIndexForSlot(cityIndex, levelIndex);
    return lessons[lessonIndex];
  }

  int lessonIndexForSlot(int cityIndex, int levelIndex) {
    if (lessons.isEmpty) {
      return -1;
    }
    if (cityIndex < 0 || cityIndex >= cities.length) {
      return 0;
    }
    final List<String> cityLevelIds = cities[cityIndex].levelIds;
    final int safeLevel = levelIndex.clamp(0, cityLevelIds.length - 1);
    final String wantedLessonId = cityLevelIds[safeLevel];
    final int exactIndex = lessons.indexWhere(
      (lesson) => lesson.id == wantedLessonId,
    );
    if (exactIndex != -1) {
      return exactIndex;
    }
    return (cityIndex * CityMapDefinition.levelsPerCity + safeLevel) %
        lessons.length;
  }

  MapProgressState copyWith({
    List<Lesson>? lessons,
    List<CityMapDefinition>? cities,
    Map<String, Set<int>>? completedLevelIndexesByCity,
    int? nars,
    String? selectedAvatarPath,
    int? currentCityIndex,
    int? currentLevelIndex,
  }) {
    return MapProgressState(
      lessons: lessons ?? this.lessons,
      cities: cities ?? this.cities,
      completedLevelIndexesByCity:
          completedLevelIndexesByCity ?? this.completedLevelIndexesByCity,
      nars: nars ?? this.nars,
      selectedAvatarPath: selectedAvatarPath ?? this.selectedAvatarPath,
      currentCityIndex: currentCityIndex ?? this.currentCityIndex,
      currentLevelIndex: currentLevelIndex ?? this.currentLevelIndex,
    );
  }
}

class MapCursor {
  const MapCursor({required this.cityIndex, required this.levelIndex});

  final int cityIndex;
  final int levelIndex;
}

class MapNotifier extends AsyncNotifier<MapProgressState> {
  SharedPreferences? _prefs;

  @override
  Future<MapProgressState> build() async {
    final LessonRepository repository = ref.read(lessonRepositoryProvider);
    final List<Lesson> lessons = await repository.loadLessons();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final List<CityMapDefinition> cities = await _loadCities(lessons);
    final List<String> rawCompleted =
        prefs.getStringList(_kPrefsCityCompletedSlots) ?? <String>[];

    final Map<String, Set<int>> completedByCity = _parseCompletedSlots(
      rawCompleted,
      cities,
    );
    final int nars = prefs.getInt(_kPrefsNars) ?? 0;
    final String selectedAvatarPath =
        prefs.getString(_kPrefsSelectedAvatar) ?? kDefaultAvatarPath;

    final MapProgressState baseState = MapProgressState(
      lessons: lessons,
      cities: cities,
      completedLevelIndexesByCity: completedByCity,
      nars: nars,
      selectedAvatarPath: selectedAvatarPath,
      currentCityIndex: 0,
      currentLevelIndex: 0,
    );

    if (cities.isEmpty) {
      return baseState;
    }

    final int rawCity = prefs.getInt(_kPrefsCurrentCityIndex) ?? 0;
    final int rawLevel = prefs.getInt(_kPrefsCurrentLevelIndex) ?? 0;
    final MapCursor cursor = _sanitizeCursor(
      baseState,
      cityIndex: rawCity,
      levelIndex: rawLevel,
    );

    return baseState.copyWith(
      currentCityIndex: cursor.cityIndex,
      currentLevelIndex: cursor.levelIndex,
    );
  }

  Future<void> setCityPage(int cityIndex) async {
    final MapProgressState? current = state.valueOrNull;
    if (current == null || current.cities.isEmpty) {
      return;
    }
    if (!current.isCityUnlocked(cityIndex)) {
      return;
    }
    final MapCursor cursor = _sanitizeCursor(
      current,
      cityIndex: cityIndex,
      levelIndex: current.firstIncompleteLevelInCity(cityIndex),
    );
    final MapProgressState next = current.copyWith(
      currentCityIndex: cursor.cityIndex,
      currentLevelIndex: cursor.levelIndex,
    );
    state = AsyncData(next);
    await _persistMapState(next);
  }

  Future<void> completeCityLevel({
    required int cityIndex,
    required int levelIndex,
    int earnedNars = 0,
  }) async {
    final MapProgressState? current = state.valueOrNull;
    if (current == null || current.cities.isEmpty) {
      return;
    }
    if (!current.isLevelUnlocked(cityIndex, levelIndex)) {
      return;
    }

    final String cityId = current.cities[cityIndex].id;
    final Map<String, Set<int>> completed = <String, Set<int>>{
      for (final MapEntry<String, Set<int>> entry
          in current.completedLevelIndexesByCity.entries)
        entry.key: <int>{...entry.value},
    };
    completed.putIfAbsent(cityId, () => <int>{}).add(levelIndex);

    MapProgressState next = current.copyWith(
      completedLevelIndexesByCity: completed,
      nars: current.nars + math.max(0, earnedNars),
    );

    if (next.isCityCompleted(cityIndex) &&
        cityIndex < next.cities.length - 1 &&
        next.isCityUnlocked(cityIndex + 1)) {
      next = next.copyWith(
        currentCityIndex: cityIndex + 1,
        currentLevelIndex: 0,
      );
    } else {
      final MapCursor cursor = _sanitizeCursor(
        next,
        cityIndex: cityIndex,
        levelIndex: next.firstIncompleteLevelInCity(cityIndex),
      );
      next = next.copyWith(
        currentCityIndex: cursor.cityIndex,
        currentLevelIndex: cursor.levelIndex,
      );
    }

    state = AsyncData(next);
    await _persistMapState(next);
  }

  Future<void> selectAvatar(String avatarPath) async {
    final MapProgressState? current = state.valueOrNull;
    if (current == null) {
      final SharedPreferences prefs =
          _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setString(_kPrefsSelectedAvatar, avatarPath);
      return;
    }
    final MapProgressState next = current.copyWith(
      selectedAvatarPath: avatarPath,
    );
    state = AsyncData(next);
    await _persistMapState(next);
  }

  Future<void> resetCityProgress() async {
    final MapProgressState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final MapProgressState next = current.copyWith(
      completedLevelIndexesByCity: const <String, Set<int>>{},
      currentCityIndex: 0,
      currentLevelIndex: 0,
      nars: 0,
    );
    state = AsyncData(next);
    await _persistMapState(next);
  }

  MapCursor _sanitizeCursor(
    MapProgressState state, {
    required int cityIndex,
    required int levelIndex,
  }) {
    if (state.cities.isEmpty) {
      return const MapCursor(cityIndex: 0, levelIndex: 0);
    }
    final int safeCity = cityIndex.clamp(0, state.cities.length - 1).toInt();
    if (!state.isCityUnlocked(safeCity)) {
      final int fallback = state.highestUnlockedCityIndex.clamp(
        0,
        state.cities.length - 1,
      );
      return MapCursor(
        cityIndex: fallback,
        levelIndex: state.firstIncompleteLevelInCity(fallback),
      );
    }
    final int maxLevel = state.cities[safeCity].levelIds.length - 1;
    int safeLevel = levelIndex.clamp(0, maxLevel).toInt();
    if (!state.isLevelUnlocked(safeCity, safeLevel)) {
      safeLevel = state.firstIncompleteLevelInCity(safeCity);
    }
    return MapCursor(cityIndex: safeCity, levelIndex: safeLevel);
  }

  Future<List<CityMapDefinition>> _loadCities(List<Lesson> lessons) async {
    final List<String> fallbackIds = _fallbackLevelIds(lessons, 0);
    try {
      final String rawJson = await rootBundle.loadString(
        AppAssets.cityMapsJson,
      );
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is! List<dynamic>) {
        return _fallbackCities(lessons);
      }
      final List<CityMapDefinition> parsed = <CityMapDefinition>[];
      for (int index = 0; index < decoded.length; index++) {
        final dynamic entry = decoded[index];
        if (entry is! Map<String, dynamic>) {
          continue;
        }
        parsed.add(
          CityMapDefinition.fromJson(
            entry,
            fallbackLevelIds: _fallbackLevelIds(
              lessons,
              index,
              seed: fallbackIds,
            ),
          ),
        );
      }
      if (parsed.isNotEmpty) {
        return parsed;
      }
    } catch (_) {
      // Fall back to generated city config.
    }
    return _fallbackCities(lessons);
  }

  List<String> _fallbackLevelIds(
    List<Lesson> lessons,
    int cityIndex, {
    List<String>? seed,
  }) {
    if (lessons.isEmpty) {
      return seed ??
          List<String>.generate(
            CityMapDefinition.levelsPerCity,
            (index) => 'missing_lesson_$index',
          );
    }
    return List<String>.generate(CityMapDefinition.levelsPerCity, (slot) {
      final int lessonIndex =
          (cityIndex * CityMapDefinition.levelsPerCity + slot) % lessons.length;
      return lessons[lessonIndex].id;
    }, growable: false);
  }

  List<CityMapDefinition> _fallbackCities(List<Lesson> lessons) {
    const List<String> names = <String>[
      'Van',
      'Mardin',
      'Amed',
      'Bingöl',
      'Bitlis',
      'Agirî',
    ];
    const List<String> slugs = <String>[
      'van',
      'mardin',
      'amed',
      'bingol',
      'bitlis',
      'agri',
    ];

    return List<CityMapDefinition>.generate(names.length, (index) {
      return CityMapDefinition(
        id: 'city_${slugs[index]}',
        name: names[index],
        background: 'assets/images/maps/${slugs[index]}.png',
        levelIds: _fallbackLevelIds(lessons, index),
        nodeAnchors: CityMapDefinition.defaultAnchors,
      );
    }, growable: false);
  }

  Map<String, Set<int>> _parseCompletedSlots(
    List<String> rawSlots,
    List<CityMapDefinition> cities,
  ) {
    final Set<String> cityIds = cities.map((city) => city.id).toSet();
    final Map<String, Set<int>> parsed = <String, Set<int>>{};

    for (final String token in rawSlots) {
      final List<String> parts = token.split(':');
      if (parts.length != 2) {
        continue;
      }
      final String cityId = parts[0];
      if (!cityIds.contains(cityId)) {
        continue;
      }
      final int? levelIndex = int.tryParse(parts[1]);
      if (levelIndex == null) {
        continue;
      }
      final int maxLevels = cities
          .firstWhere((city) => city.id == cityId)
          .levelIds
          .length;
      if (levelIndex < 0 || levelIndex >= maxLevels) {
        continue;
      }
      parsed.putIfAbsent(cityId, () => <int>{}).add(levelIndex);
    }

    return parsed;
  }

  List<String> _encodeCompletedSlots(Map<String, Set<int>> completedByCity) {
    final List<String> tokens = <String>[];
    for (final MapEntry<String, Set<int>> entry in completedByCity.entries) {
      final List<int> sorted = entry.value.toList()..sort();
      for (final int levelIndex in sorted) {
        tokens.add('${entry.key}:$levelIndex');
      }
    }
    return tokens;
  }

  Future<void> _persistMapState(MapProgressState mapState) async {
    final SharedPreferences prefs =
        _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_kPrefsNars, mapState.nars);
    await prefs.setString(_kPrefsSelectedAvatar, mapState.selectedAvatarPath);
    await prefs.setInt(_kPrefsCurrentCityIndex, mapState.currentCityIndex);
    await prefs.setInt(_kPrefsCurrentLevelIndex, mapState.currentLevelIndex);
    await prefs.setStringList(
      _kPrefsCityCompletedSlots,
      _encodeCompletedSlots(mapState.completedLevelIndexesByCity),
    );
  }
}
