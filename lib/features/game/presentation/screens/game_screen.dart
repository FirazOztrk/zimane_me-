import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/game_audio_service.dart';
import '../../../../data/models/lesson.dart';
import '../../../../data/models/word.dart';
import '../../application/game_controller.dart';

class GameResult {
  const GameResult({required this.levelIndex, required this.earnedNars});

  final int levelIndex;
  final int earnedNars;
}

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    required this.levelId,
    required this.lesson,
    required this.allLessons,
    required this.levelIndex,
  });

  final String levelId;
  final Lesson lesson;
  final List<Lesson> allLessons;
  final int levelIndex;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  static const Duration _feedbackDuration = Duration(milliseconds: 900);

  late final AnimationController _catJumpController;
  late final AnimationController _shakeController;
  late final GameSessionConfig _sessionConfig;
  late final GameAudioService _audioService;

  Timer? _nextWordTimer;
  bool _hasShownCompletionPopup = false;

  @override
  void initState() {
    super.initState();

    final Lesson playableLesson = widget.lesson.words.length <= 10
        ? widget.lesson
        : widget.lesson.copyWith(
            words: widget.lesson.words.take(10).toList(growable: false),
          );

    final List<Word> optionPool = widget.allLessons
        .expand((lesson) => lesson.words)
        .toList(growable: false);

    _sessionConfig = GameSessionConfig(
      lesson: playableLesson,
      optionPool: optionPool,
    );
    _audioService = GameAudioService();

    _catJumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final state = ref.read(gameControllerProvider(_sessionConfig));
      if (state.totalWords > 0) {
        _playWordAudio(state.currentWord.audio);
      }
    });
  }

  @override
  void dispose() {
    _nextWordTimer?.cancel();
    unawaited(_audioService.dispose());
    _catJumpController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = gameControllerProvider(_sessionConfig);
    final controller = ref.read(provider.notifier);
    final state = ref.watch(provider);

    ref.listen<GameState>(provider, (previous, next) {
      final bool changedPhase = previous?.phase != next.phase;
      final bool changedWord =
          previous?.currentWordIndex != next.currentWordIndex;

      if (next.totalWords > 0 &&
          ((changedPhase && next.phase == GamePhase.flashcard) ||
              changedWord)) {
        _playWordAudio(next.currentWord.audio);
      }

      if (changedPhase && next.phase == GamePhase.success) {
        _onCorrect(controller);
      }

      if (changedPhase && next.phase == GamePhase.failure) {
        _onWrong(controller);
      }

      if (changedPhase && next.phase == GamePhase.lessonComplete) {
        _showLessonCompleteDialog(next);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.creamYellow,
      appBar: AppBar(
        backgroundColor: AppColors.creamYellow,
        foregroundColor: AppColors.darkBrown,
        leading: IconButton(
          key: const ValueKey('game_back_button'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.lesson.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _ProgressHeader(
                progress: state.progress,
                current: state.totalWords == 0 ? 0 : state.currentWordIndex + 1,
                total: state.totalWords,
                narCount: state.narsEarned,
              ),
              const SizedBox(height: 16),
              _buildCatMood(state),
              const SizedBox(height: 16),
              Expanded(child: _buildPhaseContent(state, controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(GameState state, GameController controller) {
    switch (state.phase) {
      case GamePhase.flashcard:
        return _buildFlashcardPhase(state, controller);
      case GamePhase.quiz:
      case GamePhase.success:
      case GamePhase.failure:
        return _buildQuizPhase(state, controller);
      case GamePhase.lessonComplete:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFlashcardPhase(GameState state, GameController controller) {
    final Word word = state.currentWord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.darkBrown, width: 6),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _WordAssetCard(imagePath: word.image),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  word.kurdish,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBrown,
                  ),
                ),
                if (word.audio.trim().isNotEmpty)
                  const SizedBox(height: 8),
                if (word.audio.trim().isNotEmpty)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up_rounded, size: 16, color: Colors.black45),
                      SizedBox(width: 4),
                      Text(
                        'Deng heye',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (word.audio.trim().isNotEmpty) ...[
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('play_audio_button'),
                  onPressed: () => _playWordAudio(word.audio),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 66),
                    side: const BorderSide(color: AppColors.darkBrown, width: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Guhdar\u00EE Bike'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ElevatedButton(
                key: const ValueKey('start_quiz_button'),
                onPressed: controller.goToQuiz,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 66),
                  backgroundColor: AppColors.vibrantRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(
                      color: AppColors.darkBrown,
                      width: 4,
                    ),
                  ),
                ),
                child: const Text(
                  'Dest P\u00EA Bike',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizPhase(GameState state, GameController controller) {
    final Word targetWord = state.currentWord;
    final bool selectionLocked =
        state.phase == GamePhase.success || state.phase == GamePhase.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.darkBrown, width: 4),
          ),
          child: Text(
            'K\u00EEjan ${targetWord.kurdish} e?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.darkBrown,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            itemCount: state.options.length,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final Word option = state.options[index];
              final bool isSelected = state.selectedWordId == option.id;
              final bool isCorrectOption = _isSameWord(option, targetWord);
              final bool showSuccessGlow =
                  state.phase == GamePhase.success && isCorrectOption;
              final bool showErrorShake =
                  state.phase == GamePhase.failure &&
                  isSelected &&
                  !isCorrectOption;

              final Color fill = showSuccessGlow
                  ? AppColors.successGreen.withValues(alpha: 0.22)
                  : Colors.white;
              final Color border = showSuccessGlow
                  ? AppColors.successGreen
                  : showErrorShake
                  ? AppColors.vibrantRed
                  : AppColors.darkBrown;

              Widget card = Material(
                color: fill,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  key: ValueKey('quiz_option_$index'),
                  borderRadius: BorderRadius.circular(22),
                  onTap: selectionLocked
                      ? null
                      : () => controller.submitAnswer(option),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: border, width: 4),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: _WordAssetCard(imagePath: option.image),
                  ),
                ),
              );

              if (showErrorShake) {
                card = AnimatedBuilder(
                  animation: _shakeController,
                  child: card,
                  builder: (context, child) {
                    final double progress = _shakeController.value;
                    final double offset =
                        math.sin(progress * math.pi * 7) * (1 - progress) * 14;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                );
              }

              return card;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCatMood(GameState state) {
    final bool success = state.phase == GamePhase.success;
    final bool failure = state.phase == GamePhase.failure;

    final String mood = success
        ? '(=^.^=)'
        : failure
        ? '(=?.?=)'
        : '(=^_^=)';
    final String text = success
        ? 'Cat: Aferin!'
        : failure
        ? 'Cat: Careke din'
        : 'Cat: Bextewar e';

    return AnimatedBuilder(
      animation: _catJumpController,
      builder: (context, child) {
        final double jump = math.sin(_catJumpController.value * math.pi) * 20;
        return Transform.translate(offset: Offset(0, -jump), child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.darkBrown, width: 3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkBrown, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/icons/petfarmanimals/cat.png',
                  fit: BoxFit.contain,
                  color: failure ? Colors.grey.shade500 : null,
                  colorBlendMode: failure ? BlendMode.saturation : null,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.pets_rounded,
                      color: AppColors.darkBrown,
                      size: 28,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$mood  $text',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.darkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onCorrect(GameController controller) {
    _nextWordTimer?.cancel();
    _catJumpController.forward(from: 0);
    _playFeedbackSound(success: true);
    _nextWordTimer = Timer(_feedbackDuration, controller.nextWord);
  }

  void _onWrong(GameController controller) {
    _nextWordTimer?.cancel();
    _shakeController.forward(from: 0);
    _playFeedbackSound(success: false);
    _nextWordTimer = Timer(_feedbackDuration, controller.nextWord);
  }

  Future<void> _playWordAudio(String audioPath) async {
    await _audioService.playWord(audioPath);
  }

  void _playFeedbackSound({required bool success}) {
    if (!mounted) {
      return;
    }
    if (success) {
      unawaited(_audioService.playCorrect());
      return;
    }
    unawaited(_audioService.playWrong());
  }

  Future<void> _showLessonCompleteDialog(GameState state) async {
    if (_hasShownCompletionPopup || !mounted) {
      return;
    }
    _hasShownCompletionPopup = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: AppColors.darkBrown, width: 5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.7, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 64,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Afer\u00EEn!',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '+${state.narsEarned} Nar',
                  style: const TextStyle(
                    fontSize: 26,
                    color: AppColors.vibrantRed,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rast: ${state.narsEarned}/${state.totalWords}',
                  style: const TextStyle(
                    color: AppColors.darkBrown,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('complete_return_button'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop(
                        GameResult(
                          levelIndex: widget.levelIndex,
                          earnedNars: state.narsEarned,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.vibrantRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(
                          color: AppColors.darkBrown,
                          width: 4,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Map\u00EA Vegere',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isSameWord(Word a, Word b) {
    return a.id == b.id && a.image == b.image && a.kurdish == b.kurdish;
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.progress,
    required this.current,
    required this.total,
    required this.narCount,
  });

  final double progress;
  final int current;
  final int total;
  final int narCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 14,
                  backgroundColor: Colors.white,
                  color: AppColors.successGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$current/$total',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.darkBrown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Nar x$narCount',
          style: const TextStyle(
            color: AppColors.vibrantRed,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WordAssetCard extends StatelessWidget {
  const _WordAssetCard({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFFDF3),
        border: Border.all(color: AppColors.darkBrown, width: 6),
      ),
      alignment: Alignment.center,
      child: Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.image_not_supported_rounded, size: 38),
              SizedBox(height: 8),
              Text('Placeholder'),
            ],
          );
        },
      ),
    );
  }
}
