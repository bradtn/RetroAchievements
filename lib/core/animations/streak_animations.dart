import 'package:flutter/material.dart';
import 'haptics.dart';

/// Animated fire icon for streaks
class AnimatedFireIcon extends StatefulWidget {
  final double size;
  final Color color;
  final bool isActive;

  const AnimatedFireIcon({
    super.key,
    this.size = 24,
    this.color = Colors.orange,
    this.isActive = true,
  });

  @override
  State<AnimatedFireIcon> createState() => _AnimatedFireIconState();
}

class _AnimatedFireIconState extends State<AnimatedFireIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedFireIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Icon(
        Icons.local_fire_department,
        size: widget.size,
        color: Colors.grey,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _glowAnimation.value),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              Icons.local_fire_department,
              size: widget.size,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class StreakMilestoneBadge extends StatefulWidget {
  final int streakDays;
  final bool showCelebration;
  final VoidCallback? onCelebrationComplete;

  const StreakMilestoneBadge({
    super.key,
    required this.streakDays,
    this.showCelebration = false,
    this.onCelebrationComplete,
  });

  /// Check if a streak value is a milestone
  static bool isMilestone(int days) {
    return days == 7 || days == 14 || days == 30 || days == 50 ||
           days == 100 || days == 200 || days == 365 || days == 500 ||
           days == 1000;
  }

  /// Get milestone label
  static String? getMilestoneLabel(int days) {
    switch (days) {
      case 7: return '1 Week!';
      case 14: return '2 Weeks!';
      case 30: return '1 Month!';
      case 50: return '50 Days!';
      case 100: return '100 Days!';
      case 200: return '200 Days!';
      case 365: return '1 Year!';
      case 500: return '500 Days!';
      case 1000: return 'LEGENDARY!';
      default: return null;
    }
  }

  @override
  State<StreakMilestoneBadge> createState() => _StreakMilestoneBadgeState();
}

class _StreakMilestoneBadgeState extends State<StreakMilestoneBadge>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _celebrationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_celebrationController);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeOut),
    );

    if (StreakMilestoneBadge.isMilestone(widget.streakDays)) {
      _pulseController.repeat(reverse: true);
    }

    if (widget.showCelebration) {
      _celebrationController.forward().then((_) {
        widget.onCelebrationComplete?.call();
      });
      Haptics.celebration();
    }
  }

  @override
  void didUpdateWidget(StreakMilestoneBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showCelebration && !oldWidget.showCelebration) {
      _celebrationController.forward(from: 0).then((_) {
        widget.onCelebrationComplete?.call();
      });
      Haptics.celebration();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMilestone = StreakMilestoneBadge.isMilestone(widget.streakDays);
    final milestoneLabel = StreakMilestoneBadge.getMilestoneLabel(widget.streakDays);

    if (!isMilestone) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _celebrationController]),
      builder: (context, child) {
        final showCelebration = _celebrationController.isAnimating ||
                                _celebrationController.isCompleted;

        return Transform.scale(
          scale: showCelebration ? _scaleAnimation.value : _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade600, Colors.orange.shade700],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: _glowAnimation.value * 0.6),
                  blurRadius: 12 * _glowAnimation.value,
                  spreadRadius: 2 * _glowAnimation.value,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  milestoneLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated flame icon that burns brighter for higher streaks
class AnimatedStreakFlame extends StatefulWidget {
  final int streakDays;
  final double size;

  const AnimatedStreakFlame({
    super.key,
    required this.streakDays,
    this.size = 48,
  });

  @override
  State<AnimatedStreakFlame> createState() => _AnimatedStreakFlameState();
}

class _AnimatedStreakFlameState extends State<AnimatedStreakFlame>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: _getAnimationSpeed()),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0 + (_getIntensity() * 0.15),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.3 + (_getIntensity() * 0.5),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  double _getIntensity() {
    if (widget.streakDays >= 100) return 1.0;
    if (widget.streakDays >= 30) return 0.8;
    if (widget.streakDays >= 14) return 0.6;
    if (widget.streakDays >= 7) return 0.4;
    return 0.2;
  }

  int _getAnimationSpeed() {
    if (widget.streakDays >= 100) return 600;
    if (widget.streakDays >= 30) return 800;
    if (widget.streakDays >= 14) return 1000;
    return 1200;
  }

  Color _getFlameColor() {
    if (widget.streakDays >= 100) return Colors.blue;
    if (widget.streakDays >= 30) return Colors.purple;
    if (widget.streakDays >= 14) return Colors.red;
    if (widget.streakDays >= 7) return Colors.deepOrange;
    return Colors.orange;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getFlameColor();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _glowAnimation.value),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              Icons.local_fire_department,
              size: widget.size,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
