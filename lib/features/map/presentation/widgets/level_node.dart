import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelNode extends StatefulWidget {
  const LevelNode({
    super.key,
    this.tapKey,
    required this.title,
    required this.isLocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.isAvatarOnRight,
    required this.onTap,
    this.avatarPath,
  });

  final Key? tapKey;
  final String title;
  final bool isLocked;
  final bool isCurrent;
  final bool isCompleted;
  final bool isAvatarOnRight;
  final VoidCallback? onTap;
  final String? avatarPath;

  static const Color _brown = Color(0xFF4E342E);
  static const double nodeSize = 80;
  static const String _hinarAsset = 'assets/images/nar.png';

  @override
  State<LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<LevelNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    if (widget.isCurrent && !widget.isLocked) {
      _bounceController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LevelNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !widget.isLocked) {
      if (!_bounceController.isAnimating) {
        _bounceController.repeat(reverse: true);
      }
    } else {
      _bounceController.stop();
      _bounceController.reset();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Node colors based on state
    final Color circleColor = widget.isCompleted
        ? const Color(0xFF43A047)
        : widget.isLocked
        ? const Color(0xFFBDBDBD)
        : const Color(0xFFE53935);

    final Color borderColor = widget.isCompleted
        ? const Color(0xFF2E7D32)
        : LevelNode._brown;

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // --- Avatar (alternates right/left by level) ---
          if (widget.isCurrent && widget.avatarPath != null)
            Positioned(
              left: widget.isAvatarOnRight ? 116 : -4,
              top: 48,
              child: AnimatedBuilder(
                animation: _bounceAnim,
                builder: (context, child) {
                  final double offset = _bounceAnim.value * -10;
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: child,
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
                        color: Color(0x40000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: Image.asset(
                      widget.avatarPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person_rounded,
                          size: 24,
                          color: LevelNode._brown,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          // --- Nar (pomegranate) node ---
          Positioned(
            top: 32,
            child: GestureDetector(
              key: widget.tapKey,
              onTap: widget.isLocked ? null : widget.onTap,
              child: Container(
                width: LevelNode.nodeSize,
                height: LevelNode.nodeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor,
                  border: Border.all(color: borderColor, width: 4),
                  boxShadow: widget.isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF6F00,
                            ).withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : [
                          const BoxShadow(
                            color: Color(0x30000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: widget.isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 38,
                        )
                      : Opacity(
                          opacity: widget.isLocked ? 0.45 : 1,
                          child: Image.asset(
                            LevelNode._hinarAsset,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.local_florist_rounded,
                                color: widget.isLocked
                                    ? Colors.grey.shade700
                                    : Colors.white,
                                size: 36,
                              );
                            },
                          ),
                        ),
                ),
              ),
            ),
          ),

          // --- Locked icon overlay ---
          if (widget.isLocked)
            Positioned(
              top: 32,
              child: IgnorePointer(
                child: Container(
                  width: LevelNode.nodeSize,
                  height: LevelNode.nodeSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x66000000),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white70,
                    size: 30,
                  ),
                ),
              ),
            ),

          // --- Title label ---
          Positioned(
            top: 112,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: LevelNode._brown, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                widget.title,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: LevelNode._brown,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
