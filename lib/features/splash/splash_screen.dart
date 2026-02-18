import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../map/application/map_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const Color _startButtonOrange = Color(0xFFFFA726);
  static const String _catMascotPath = 'assets/icons/petfarmanimals/cat.png';
  static const List<String> _avatarPaths = <String>[
    'assets/avatars/kewe.png',
    'assets/avatars/pisik.png',
    'assets/avatars/wisar.png',
    'assets/avatars/xoser.png',
  ];

  int? _selectedAvatarIndex;

  Future<void> _onStartPressed() async {
    if (_selectedAvatarIndex == null) {
      return;
    }
    final String selectedPath = _avatarPaths[_selectedAvatarIndex!];
    await ref.read(lessonProvider.notifier).selectAvatar(selectedPath);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bool canStart = _selectedAvatarIndex != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 42,
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      'Ziman\u00EA Me',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkBrown,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 140,
                      width: 140,
                      child: Image.asset(
                        _catMascotPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.darkBrown,
                                width: 4,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.pets_rounded,
                              size: 62,
                              color: AppColors.darkBrown,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Karakter\u00EA Xwe Hilbij\u00EAre',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkBrown,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 196,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _avatarPaths.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final String avatarPath = _avatarPaths[index];
                          final bool isSelected = _selectedAvatarIndex == index;
                          return _AvatarCard(
                            key: ValueKey('avatar_$index'),
                            avatarPath: avatarPath,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedAvatarIndex = index;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _StartButton(enabled: canStart, onTap: _onStartPressed),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    super.key,
    required this.avatarPath,
    required this.isSelected,
    required this.onTap,
  });

  final String avatarPath;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 148,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.successGreen : AppColors.darkBrown,
            width: isSelected ? 6 : 4,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x335D4037),
              blurRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  avatarPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFFFF8E1),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person_rounded,
                        size: 74,
                        color: AppColors.darkBrown,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.darkBrown, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = enabled
        ? _SplashScreenState._startButtonOrange
        : const Color(0xFFFFCC80);
    final Color labelColor = enabled ? Colors.white : const Color(0xFF795548);

    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0xFF5D4037),
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const ValueKey('start_button'),
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            disabledBackgroundColor: buttonColor,
            elevation: 0,
            foregroundColor: labelColor,
            disabledForegroundColor: labelColor,
            minimumSize: const Size.fromHeight(76),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: AppColors.darkBrown, width: 3),
            ),
          ),
          child: Text(
            'DEST P\u00CA BIKE',
            style: GoogleFonts.nunito(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
