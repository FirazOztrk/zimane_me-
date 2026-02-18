import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../data/models/lesson.dart';
import '../../../game/presentation/screens/game_screen.dart';
import '../../application/map_providers.dart';
import '../widgets/city_page_view.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const Color _mapCream = Color(0xFFFFF9C4);
  static const Color _barCream = Color(0xFFFFF8E1);
  static const Color _brown = Color(0xFF4E342E);
  static const Color _green = Color(0xFF8BC34A);

  int _tabIndex = 2;

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    return Scaffold(
      backgroundColor: _mapCream,
      body: mapState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Map state error:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (state) {
          final List<Widget> tabs = <Widget>[
            const _TabPlaceholder(
              title: 'Mal',
              subtitle: 'Bi xosh hati',
              icon: Icons.home_rounded,
            ),
            _RewardsTab(
              nars: state.nars,
              completedCount: state.totalCompletedLevels,
            ),
            _buildMapTab(state),
            const _TabPlaceholder(
              title: 'Saz\u00EE',
              subtitle: 'M\u00EEheng \u00FB deng',
              icon: Icons.settings_rounded,
            ),
          ];

          return IndexedStack(index: _tabIndex, children: tabs);
        },
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _barCream,
          border: Border(top: BorderSide(color: _brown, width: 4)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _tabIndex,
          onTap: (index) => setState(() => _tabIndex = index),
          selectedItemColor: const Color(0xFF3E2723),
          unselectedItemColor: const Color(0xFFA1887F),
          selectedLabelStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Mal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_rounded),
              label: 'Xelat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_rounded),
              label: 'Nex\u015Fe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Saz\u00EE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab(MapProgressState progress) {
    if (progress.cities.isEmpty || progress.lessons.isEmpty) {
      return const Center(child: Text('No map/lesson data found.'));
    }

    final int completed = progress.totalCompletedLevels;
    final int total = progress.totalLevels;
    final double progressValue = total == 0 ? 0 : completed / total;
    final CityMapDefinition currentCity =
        progress.cities[progress.currentCityIndex];
    final String cityName = currentCity.name;
    final int cityLevelCount = currentCity.levelIds.length;

    return Container(
      color: _mapCream,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _brown, width: 3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    '$cityName - ${progress.currentLevelIndex + 1}/$cityLevelCount',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w900,
                      color: _brown,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _brown,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _brown, width: 2),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progressValue.clamp(0.03, 1),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_florist_rounded,
                        size: 18,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${progress.nars} Nar',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          color: _brown,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: CityPageView(
                onLevelTap: (cityIndex, levelIndex, lesson) => _openGameForSlot(
                  cityIndex: cityIndex,
                  levelIndex: levelIndex,
                  lesson: lesson,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGameForSlot({
    required int cityIndex,
    required int levelIndex,
    required Lesson lesson,
  }) async {
    final MapProgressState? map = ref.read(mapProvider).valueOrNull;
    if (map == null) {
      return;
    }
    final int lessonIndex = map.lessonIndexForSlot(cityIndex, levelIndex);
    if (lessonIndex < 0 || lessonIndex >= map.lessons.length) {
      return;
    }

    final GameResult? result = await Navigator.of(context).push<GameResult>(
      MaterialPageRoute<GameResult>(
        builder: (_) => GameScreen(
          levelId: lesson.id,
          lesson: lesson,
          allLessons: map.lessons,
          levelIndex: lessonIndex,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    await ref
        .read(mapProvider.notifier)
        .completeCityLevel(
          cityIndex: cityIndex,
          levelIndex: levelIndex,
          earnedNars: result.earnedNars,
        );

    await ref
        .read(lessonProvider.notifier)
        .completeLevel(levelIndex: lessonIndex, earnedNars: result.earnedNars);
  }
}

class _RewardsTab extends StatelessWidget {
  const _RewardsTab({required this.nars, required this.completedCount});

  final int nars;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _MapScreenState._brown, width: 5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.park_rounded,
                size: 68,
                color: Color(0xFFE5A100),
              ),
              const SizedBox(height: 12),
              Text(
                'Xelat',
                style: GoogleFonts.nunito(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: _MapScreenState._brown,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Nar: $nars',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE53935),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Qonax\u00EAn qediyay\u00EE: $completedCount',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _MapScreenState._brown,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _MapScreenState._brown, width: 5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: _MapScreenState._brown),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _MapScreenState._brown,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6D4C41),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
