import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/lesson.dart';
import '../../../data/models/word.dart';

enum GamePhase { flashcard, quiz, success, failure, lessonComplete }

class GameSessionConfig {
  const GameSessionConfig({required this.lesson, required this.optionPool});

  final Lesson lesson;
  final List<Word> optionPool;

  @override
  bool operator ==(Object other) {
    return other is GameSessionConfig && other.lesson.id == lesson.id;
  }

  @override
  int get hashCode => lesson.id.hashCode;
}

class GameState {
  const GameState({
    required this.lesson,
    required this.phase,
    required this.currentWordIndex,
    required this.options,
    required this.narsEarned,
    required this.lastAnswerCorrect,
    required this.selectedWordId,
  });

  final Lesson lesson;
  final GamePhase phase;
  final int currentWordIndex;
  final List<Word> options;
  final int narsEarned;
  final bool? lastAnswerCorrect;
  final String? selectedWordId;

  Word get currentWord => lesson.words[currentWordIndex];
  bool get isLastWord => currentWordIndex >= lesson.words.length - 1;
  int get totalWords => lesson.words.length;

  double get progress {
    if (totalWords == 0) {
      return 0;
    }
    return (currentWordIndex + 1) / totalWords;
  }

  GameState copyWith({
    Lesson? lesson,
    GamePhase? phase,
    int? currentWordIndex,
    List<Word>? options,
    int? narsEarned,
    bool? lastAnswerCorrect,
    bool clearAnswerResult = false,
    String? selectedWordId,
    bool clearSelection = false,
  }) {
    return GameState(
      lesson: lesson ?? this.lesson,
      phase: phase ?? this.phase,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      options: options ?? this.options,
      narsEarned: narsEarned ?? this.narsEarned,
      lastAnswerCorrect: clearAnswerResult
          ? null
          : (lastAnswerCorrect ?? this.lastAnswerCorrect),
      selectedWordId: clearSelection
          ? null
          : (selectedWordId ?? this.selectedWordId),
    );
  }
}

final gameControllerProvider = StateNotifierProvider.autoDispose
    .family<GameController, GameState, GameSessionConfig>((ref, config) {
      return GameController(
        lesson: config.lesson,
        optionPool: config.optionPool,
      );
    });

class GameController extends StateNotifier<GameState> {
  GameController({
    required Lesson lesson,
    required List<Word> optionPool,
    Random? random,
  }) : this._internal(
         lesson: lesson,
         optionPool: _preparePool(lesson, optionPool),
         random: random ?? Random(),
       );

  GameController._internal({
    required Lesson lesson,
    required List<Word> optionPool,
    required Random random,
  }) : _random = random,
       _optionPool = optionPool,
       super(
         _buildInitialState(
           lesson: lesson,
           optionPool: optionPool,
           random: random,
         ),
       );

  final Random _random;
  final List<Word> _optionPool;

  static GameState _buildInitialState({
    required Lesson lesson,
    required List<Word> optionPool,
    required Random random,
  }) {
    if (lesson.words.isEmpty) {
      return GameState(
        lesson: lesson,
        phase: GamePhase.lessonComplete,
        currentWordIndex: 0,
        options: const <Word>[],
        narsEarned: 0,
        lastAnswerCorrect: null,
        selectedWordId: null,
      );
    }

    final Word firstWord = lesson.words.first;
    return GameState(
      lesson: lesson,
      phase: GamePhase.flashcard,
      currentWordIndex: 0,
      options: _buildOptions(
        correctWord: firstWord,
        optionPool: optionPool,
        random: random,
      ),
      narsEarned: 0,
      lastAnswerCorrect: null,
      selectedWordId: null,
    );
  }

  static List<Word> _preparePool(Lesson lesson, List<Word> optionPool) {
    if (optionPool.isEmpty) {
      return lesson.words;
    }

    final List<Word> merged = <Word>[...optionPool, ...lesson.words];
    return _uniqueWords(merged);
  }

  static List<Word> _uniqueWords(List<Word> words) {
    final Set<String> seen = <String>{};
    final List<Word> unique = <Word>[];

    for (final word in words) {
      final String key = '${word.id}:${word.image}:${word.kurdish}';
      if (seen.add(key)) {
        unique.add(word);
      }
    }
    return unique;
  }

  static List<Word> _buildOptions({
    required Word correctWord,
    required List<Word> optionPool,
    required Random random,
  }) {
    final List<Word> distractors =
        optionPool
            .where(
              (word) =>
                  !(word.id == correctWord.id &&
                      word.image == correctWord.image &&
                      word.kurdish == correctWord.kurdish),
            )
            .toList(growable: true)
          ..shuffle(random);

    final List<Word> options = <Word>[correctWord];
    for (final word in distractors) {
      if (options.length >= 4) {
        break;
      }
      options.add(word);
    }

    while (options.length < 4) {
      if (distractors.isNotEmpty) {
        options.add(distractors[random.nextInt(distractors.length)]);
      } else {
        options.add(correctWord);
      }
    }

    options.shuffle(random);
    return options;
  }

  void goToQuiz() {
    if (state.phase != GamePhase.flashcard) {
      return;
    }
    state = state.copyWith(
      phase: GamePhase.quiz,
      clearAnswerResult: true,
      clearSelection: true,
    );
  }

  void replayWordAudio() {
    state = state.copyWith();
  }

  void submitAnswer(Word selectedWord) {
    if (state.phase != GamePhase.quiz) {
      return;
    }

    final bool isCorrect = _isCorrect(selectedWord);
    state = state.copyWith(
      phase: isCorrect ? GamePhase.success : GamePhase.failure,
      selectedWordId: selectedWord.id,
      lastAnswerCorrect: isCorrect,
      narsEarned: isCorrect ? state.narsEarned + 1 : state.narsEarned,
    );
  }

  void nextWord() {
    if (state.phase != GamePhase.success && state.phase != GamePhase.failure) {
      return;
    }

    if (state.isLastWord) {
      state = state.copyWith(phase: GamePhase.lessonComplete);
      return;
    }

    final int nextIndex = state.currentWordIndex + 1;
    final Word nextWord = state.lesson.words[nextIndex];
    state = state.copyWith(
      phase: GamePhase.flashcard,
      currentWordIndex: nextIndex,
      options: _buildOptions(
        correctWord: nextWord,
        optionPool: _optionPool,
        random: _random,
      ),
      clearAnswerResult: true,
      clearSelection: true,
    );
  }

  bool _isCorrect(Word selectedWord) {
    final currentWord = state.currentWord;
    return selectedWord.id == currentWord.id &&
        selectedWord.image == currentWord.image &&
        selectedWord.kurdish == currentWord.kurdish;
  }
}
