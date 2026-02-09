import 'package:flutter/material.dart';

/// Animated avatar with glow and pulse effects
class AnimatedAvatar extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final bool isActive;
  final int? streakDays;
  final VoidCallback? onTap;

  const AnimatedAvatar({
    super.key,
    this.imageUrl,
    this.size = 80,
    this.isActive = false,
    this.streakDays,
    this.onTap,
  });

  @override
  State<AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<AnimatedAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedAvatar oldWidget) {
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

  Color _getGlowColor() {
    if (widget.streakDays == null || widget.streakDays! <= 0) {
      return Colors.blue;
    }
    if (widget.streakDays! >= 100) return Colors.purple;
    if (widget.streakDays! >= 30) return Colors.amber;
    if (widget.streakDays! >= 7) return Colors.orange;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: _getGlowColor().withValues(alpha: _glowAnimation.value),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Transform.scale(
              scale: widget.isActive ? _scaleAnimation.value : 1.0,
              child: child,
            ),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isActive ? _getGlowColor() : Colors.grey.shade600,
              width: 3,
            ),
          ),
          child: ClipOval(
            child: widget.imageUrl != null
                ? Image.network(
                    widget.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade800,
                      child: Icon(
                        Icons.person,
                        size: widget.size * 0.5,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade800,
                    child: Icon(
                      Icons.person,
                      size: widget.size * 0.5,
                      color: Colors.grey.shade400,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Animated rank badge that glows and pulses
class AnimatedRankBadge extends StatefulWidget {
  final String rank;
  final Color color;
  final double size;

  const AnimatedRankBadge({
    super.key,
    required this.rank,
    this.color = Colors.amber,
    this.size = 32,
  });

  @override
  State<AnimatedRankBadge> createState() => _AnimatedRankBadgeState();
}

class _AnimatedRankBadgeState extends State<AnimatedRankBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color,
                  widget.color.withValues(alpha: 0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.rank,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.size * 0.4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

