import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../data/models/lesson.dart';
import '../../application/map_providers.dart';
import 'level_node.dart';
import 'map_path_painter.dart';

class CityPageView extends ConsumerStatefulWidget {
  const CityPageView({super.key, required this.onLevelTap});

  final Future<void> Function(int cityIndex, int levelIndex, Lesson lesson)
  onLevelTap;

  @override
  ConsumerState<CityPageView> createState() => _CityPageViewState();
}

class _CityPageViewState extends ConsumerState<CityPageView>
    with TickerProviderStateMixin {
  static const double _mapSourceWidth = 1024;
  static const double _mapSourceHeight = 1536;

  late final PageController _pageController;
  bool _isUserSwiping = false;
  bool _initialSyncDone = false;

  // Avatar path animation
  AnimationController? _avatarPathController;
  Animation<double>? _avatarPathAnimation;
  int? _animFromLevel;
  int? _animToLevel;
  int? _animCityIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _avatarPathController?.dispose();
    super.dispose();
  }

  /// Starts avatar walk animation from one level to the next
  void _animateAvatarToLevel(int cityIndex, int fromLevel, int toLevel) {
    _avatarPathController?.dispose();
    _avatarPathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _avatarPathAnimation = CurvedAnimation(
      parent: _avatarPathController!,
      curve: Curves.easeInOut,
    );
    _animFromLevel = fromLevel;
    _animToLevel = toLevel;
    _animCityIndex = cityIndex;

    _avatarPathController!.forward().then((_) {
      if (mounted) {
        setState(() {
          _animFromLevel = null;
          _animToLevel = null;
          _animCityIndex = null;
        });
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    // Listen for state changes to trigger avatar animation and programmatic page sync
    ref.listen<AsyncValue<MapProgressState>>(mapProvider, (previous, next) {
      final MapProgressState? prevState = previous?.valueOrNull;
      final MapProgressState? nextState = next.valueOrNull;
      if (prevState == null || nextState == null) return;

      // Detect if a level was just completed in the current city
      if (prevState.currentCityIndex == nextState.currentCityIndex) {
        final int prevLevel = prevState.currentLevelIndex;
        final int nextLevel = nextState.currentLevelIndex;
        if (nextLevel > prevLevel && nextLevel - prevLevel == 1) {
          _animateAvatarToLevel(
            nextState.currentCityIndex,
            prevLevel,
            nextLevel,
          );
        }
      }

      // Programmatic city change (e.g. completing all levels in a city advances to next)
      // Only sync page if the user is NOT actively swiping
      if (!_isUserSwiping &&
          prevState.currentCityIndex != nextState.currentCityIndex) {
        _jumpToPage(nextState.currentCityIndex);
      }
    });

    return mapState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Map load error:\n$error', textAlign: TextAlign.center),
        ),
      ),
      data: (progress) {
        if (progress.cities.isEmpty || progress.lessons.isEmpty) {
          return Center(
            child: Text(
              'Daney\u00EAn nex\u015Fey\u00EA vala ne.',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4E342E),
              ),
            ),
          );
        }

        // Only sync on first build (initial load)
        if (!_initialSyncDone) {
          _initialSyncDone = true;
          _jumpToPage(progress.currentCityIndex);
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _isUserSwiping = true;
            } else if (notification is ScrollEndNotification) {
              _isUserSwiping = false;
            }
            return false;
          },
          child: PageView.builder(
          key: const ValueKey('city_page_view'),
          controller: _pageController,
          itemCount: progress.cities.length,
          onPageChanged: (index) {
            if (_isUserSwiping) {
              ref.read(mapProvider.notifier).setCityPage(index);
            }
          },
          itemBuilder: (context, cityIndex) {
            final CityMapDefinition city = progress.cities[cityIndex];
            final bool cityUnlocked = progress.isCityUnlocked(cityIndex);
            final bool isActiveCity = cityIndex == progress.currentCityIndex;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final Size canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final Rect mapRect = _fitMapRect(canvasSize);
                  final List<Offset> points = city.nodeAnchors
                      .map(
                        (anchor) => Offset(
                          mapRect.left + (anchor.dx * mapRect.width),
                          mapRect.top + (anchor.dy * mapRect.height),
                        ),
                      )
                      .toList(growable: false);

                  // Calculate completed level count for path painter
                  int completedCount = 0;
                  for (int i = 0; i < city.levelIds.length; i++) {
                    if (progress.isLevelCompleted(cityIndex, i)) {
                      completedCount = i + 1;
                    } else {
                      break;
                    }
                  }

                  return Stack(
                    children: [
                      // Background image
                      Positioned.fromRect(
                        rect: mapRect,
                        child: _CityBackground(
                          path: city.background,
                          locked: !cityUnlocked,
                        ),
                      ),

                      // Path between nodes
                      Positioned.fromRect(
                        rect: mapRect,
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: MapPathPainter(
                              points: points
                                  .map(
                                    (p) => Offset(
                                      p.dx - mapRect.left,
                                      p.dy - mapRect.top,
                                    ),
                                  )
                                  .toList(growable: false),
                              completedSegments: completedCount,
                            ),
                          ),
                        ),
                      ),

                      // Level nodes
                      for (
                        int levelIndex = 0;
                        levelIndex < city.levelIds.length;
                        levelIndex++
                      )
                        Builder(
                          builder: (context) {
                            final Offset center = points[levelIndex];
                            final bool isCurrentSlot =
                                isActiveCity &&
                                levelIndex == progress.currentLevelIndex;
                            final bool isLocked = !progress.isLevelUnlocked(
                              cityIndex,
                              levelIndex,
                            );
                            final bool isCompleted = progress.isLevelCompleted(
                              cityIndex,
                              levelIndex,
                            );
                            final Lesson lesson = progress.lessonForSlot(
                              cityIndex,
                              levelIndex,
                            );

                            // Don't show avatar on node if it's currently animating along path
                            final bool isAnimating =
                                _animCityIndex == cityIndex &&
                                _animFromLevel != null;
                            final bool showAvatarOnNode =
                                isCurrentSlot && !isAnimating;

                            return Positioned(
                              left: center.dx - 80,
                              top: center.dy - 72,
                              child: LevelNode(
                                key: ValueKey(
                                  'level_node_${cityIndex}_$levelIndex',
                                ),
                                tapKey: ValueKey(
                                  'level_node_tap_${cityIndex}_$levelIndex',
                                ),
                                title: lesson.title,
                                isLocked: isLocked || !cityUnlocked,
                                isCurrent: isCurrentSlot,
                                isCompleted: isCompleted,
                                isAvatarOnRight: levelIndex.isEven,
                                avatarPath: showAvatarOnNode
                                    ? progress.selectedAvatarPath
                                    : null,
                                onTap: (isLocked || !cityUnlocked)
                                    ? null
                                    : () => widget.onLevelTap(
                                        cityIndex,
                                        levelIndex,
                                        lesson,
                                      ),
                              ),
                            );
                          },
                        ),

                      // --- Animated avatar walking along path ---
                      if (_animCityIndex == cityIndex &&
                          _animFromLevel != null &&
                          _animToLevel != null &&
                          _avatarPathAnimation != null)
                        AnimatedBuilder(
                          animation: _avatarPathAnimation!,
                          builder: (context, child) {
                            final Offset from = points[_animFromLevel!];
                            final Offset to = points[_animToLevel!];
                            final double t = _avatarPathAnimation!.value;

                            // Lerp along path with slight arc
                            final double midX = (from.dx + to.dx) / 2;
                            final double midY =
                                from.dy + (to.dy - from.dy) * 0.5;
                            final Offset control = Offset(midX, midY);

                            // Quadratic bezier interpolation
                            final double x = _quadBezier(
                              from.dx,
                              control.dx,
                              to.dx,
                              t,
                            );
                            final double y = _quadBezier(
                              from.dy,
                              control.dy,
                              to.dy,
                              t,
                            );

                            return Positioned(
                              left: x - 24,
                              top: y - 56,
                              child: child!,
                            );
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF6F00),
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: Image.asset(
                                progress.selectedAvatarPath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person_rounded,
                                    size: 24,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                      // Locked city overlay
                      if (!cityUnlocked)
                        Positioned.fromRect(
                          rect: mapRect,
                          child: const _LockedCityOverlay(),
                        ),

                      // City name badge
                      Positioned(
                        left: mapRect.left + 14,
                        top: mapRect.top + 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF4E342E),
                              width: 3,
                            ),
                          ),
                          child: Text(
                            city.name,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4E342E),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
        );
      },
    );
  }

  double _quadBezier(double p0, double p1, double p2, double t) {
    return (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2;
  }

  void _jumpToPage(int cityIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final int currentPage =
          (_pageController.page ?? _pageController.initialPage.toDouble())
              .round();
      if (currentPage == cityIndex) {
        return;
      }
      _pageController.animateToPage(
        cityIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Rect _fitMapRect(Size canvasSize) {
    const double aspectRatio = _mapSourceWidth / _mapSourceHeight;

    double width = canvasSize.width;
    double height = width / aspectRatio;
    if (height > canvasSize.height) {
      height = canvasSize.height;
      width = height * aspectRatio;
    }

    return Rect.fromLTWH(
      (canvasSize.width - width) / 2,
      (canvasSize.height - height) / 2,
      width,
      height,
    );
  }
}

class _CityBackground extends StatelessWidget {
  const _CityBackground({required this.path, required this.locked});

  final String path;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1C6),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFF4E342E), width: 6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  AppAssets.mapReference,
                  fit: BoxFit.cover,
                  errorBuilder: (context, secondError, secondStackTrace) {
                    return Container(
                      color: const Color(0xFFB2EBF2),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.map_rounded,
                        size: 72,
                        color: Color(0xFF4E342E),
                      ),
                    );
                  },
                );
              },
            ),
            if (locked) Container(color: const Color(0x88000000)),
          ],
        ),
      ),
    );
  }
}

class _LockedCityOverlay extends StatelessWidget {
  const _LockedCityOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF4E342E), width: 4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF4E342E), size: 26),
            const SizedBox(width: 8),
            Text(
              'Girt\u00EE ye',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4E342E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
