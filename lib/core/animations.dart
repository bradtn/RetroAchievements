import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:confetti/confetti.dart';

// ============ PAGE TRANSITIONS ============

/// Custom page route with slide + fade animation
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlidePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          opaque: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Use fastOutSlowIn for smoother perceived motion
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.fastOutSlowIn,
            );

            // Shorter slide distance (0.3 instead of 1.0) for snappier feel
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.25, 0.0),
                end: Offset.zero,
              ).animate(curve),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    // Fade in quickly at the start
                    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Fade scale page transition
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScalePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
                child: child,
              ),
            );
          },
        );
}

// ============ SHIMMER LOADING ============

/// Shimmer loading placeholder for cards
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.width,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer loading for game list tiles
class ShimmerGameTile extends StatelessWidget {
  const ShimmerGameTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading for achievement tiles
class ShimmerAchievementTile extends StatelessWidget {
  const ShimmerAchievementTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading for profile header
class ShimmerProfileHeader extends StatelessWidget {
  const ShimmerProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 14,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ LIST ANIMATIONS ============

/// Animated list item that slides and fades in
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Stagger the animation based on index
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// ============ INTERACTIVE ANIMATIONS ============

/// Tappable card with scale animation and haptic feedback
class TappableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final bool enableHaptics;

  const TappableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.97,
    this.enableHaptics = true,
  });

  @override
  State<TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<TappableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _handleLongPress() {
    if (widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress != null ? _handleLongPress : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ============ ANIMATED FIRE ICON ============

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

// ============ ANIMATED PROGRESS BAR ============

/// Animated progress bar that fills up smoothly
class AnimatedProgressBar extends StatefulWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double height;
  final Duration duration;
  final BorderRadius? borderRadius;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.color = Colors.blue,
    this.backgroundColor = Colors.grey,
    this.height = 8,
    this.duration = const Duration(milliseconds: 800),
    this.borderRadius,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(widget.height / 2);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor.withValues(alpha: 0.3),
            borderRadius: radius,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _animation.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color,
                    widget.color.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============ CELEBRATION ANIMATION ============

/// Pulsing celebration badge
class CelebrationBadge extends StatefulWidget {
  final Widget child;
  final bool celebrate;

  const CelebrationBadge({
    super.key,
    required this.child,
    this.celebrate = true,
  });

  @override
  State<CelebrationBadge> createState() => _CelebrationBadgeState();
}

class _CelebrationBadgeState extends State<CelebrationBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.celebrate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.celebrate) {
      return widget.child;
    }

    return ScaleTransition(
      scale: _pulseAnimation,
      child: widget.child,
    );
  }
}

// ============ SCROLL-AWARE ANIMATED ITEM ============

/// Animated item that slides in when it becomes visible on screen
class ScrollAnimatedItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;
  final double initialOpacity;

  const ScrollAnimatedItem({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 15),
    this.duration = const Duration(milliseconds: 200),
    this.beginOffset = const Offset(0.15, 0.0),
    this.initialOpacity = 0.3,
  });

  @override
  State<ScrollAnimatedItem> createState() => _ScrollAnimatedItemState();
}

class _ScrollAnimatedItemState extends State<ScrollAnimatedItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slideAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Start with some opacity so items aren't invisible while waiting
    _opacity = Tween<double>(begin: widget.initialOpacity, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startAnimation() {
    if (_hasAnimated) return;
    _hasAnimated = true;

    // Stagger animation based on index, but cap the delay to max 5 items
    final cappedIndex = widget.index.clamp(0, 5);
    Future.delayed(widget.delay * cappedIndex, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Start animation when built (visible)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimation();
    });

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Staggered grid animation for achievement tiles
class AnimatedAchievementTile extends StatefulWidget {
  final Widget child;
  final int index;
  final bool animate;

  const AnimatedAchievementTile({
    super.key,
    required this.child,
    required this.index,
    this.animate = true,
  });

  @override
  State<AnimatedAchievementTile> createState() => _AnimatedAchievementTileState();
}

class _AnimatedAchievementTileState extends State<AnimatedAchievementTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startAnimation() {
    if (_hasAnimated || !widget.animate) return;
    _hasAnimated = true;

    // Stagger based on index with cap
    final delay = Duration(milliseconds: 40 * (widget.index.clamp(0, 8)));
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return widget.child;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimation();
    });

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

// ============ CONFETTI CELEBRATION ============

/// Confetti celebration overlay widget
class ConfettiCelebration extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final VoidCallback? onComplete;

  const ConfettiCelebration({
    super.key,
    required this.child,
    this.trigger = false,
    this.onComplete,
  });

  @override
  State<ConfettiCelebration> createState() => ConfettiCelebrationState();
}

class ConfettiCelebrationState extends State<ConfettiCelebration> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    if (widget.trigger) {
      _playConfetti();
    }
  }

  @override
  void didUpdateWidget(ConfettiCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _playConfetti();
    }
  }

  void _playConfetti() {
    _confettiController.play();
    Future.delayed(const Duration(seconds: 2), () {
      widget.onComplete?.call();
    });
  }

  /// Call this method to trigger confetti externally
  void celebrate() {
    _playConfetti();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.amber,
              Colors.orange,
              Colors.red,
              Colors.purple,
              Colors.blue,
              Colors.green,
              Colors.pink,
            ],
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.05,
            gravity: 0.2,
          ),
        ),
      ],
    );
  }
}

/// A button that triggers confetti on tap
class ConfettiButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool showConfetti;

  const ConfettiButton({
    super.key,
    required this.child,
    this.onTap,
    this.showConfetti = true,
  });

  @override
  State<ConfettiButton> createState() => _ConfettiButtonState();
}

class _ConfettiButtonState extends State<ConfettiButton> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (widget.showConfetti) {
              _controller.play();
            }
            widget.onTap?.call();
          },
          child: widget.child,
        ),
        ConfettiWidget(
          confettiController: _controller,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            Colors.amber,
            Colors.orange,
            Colors.yellow,
            Colors.green,
          ],
          numberOfParticles: 15,
          maxBlastForce: 15,
          minBlastForce: 5,
          gravity: 0.3,
        ),
      ],
    );
  }
}

// ============ COUNT UP ANIMATION ============

/// Animated number that counts up
class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String? prefix;
  final String? suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 1000),
    this.prefix,
    this.suffix,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = IntTween(begin: _previousValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix ?? ''}${_animation.value}${widget.suffix ?? ''}',
          style: widget.style,
        );
      },
    );
  }
}

// ============ ACHIEVEMENT UNLOCK ANIMATION ============

/// Achievement unlock popup animation with scale, glow, and shine effects
class AchievementUnlockAnimation extends StatefulWidget {
  final Widget child;
  final bool show;
  final VoidCallback? onComplete;
  final Duration duration;

  const AchievementUnlockAnimation({
    super.key,
    required this.child,
    this.show = false,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<AchievementUnlockAnimation> createState() =>
      AchievementUnlockAnimationState();
}

class AchievementUnlockAnimationState extends State<AchievementUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shineController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _shineAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _shineController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_scaleController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 80,
      ),
    ]).animate(_scaleController);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.3)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 70,
      ),
    ]).animate(_scaleController);

    _shineAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );

    if (widget.show) {
      _playAnimation();
    }
  }

  @override
  void didUpdateWidget(AchievementUnlockAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _playAnimation();
    }
  }

  void _playAnimation() {
    _scaleController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _shineController.forward(from: 0);
      }
    });
    Future.delayed(widget.duration, () {
      widget.onComplete?.call();
    });
  }

  /// Trigger the animation externally
  void play() {
    _playAnimation();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _shineController]),
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: _glowAnimation.value * 0.6),
                    blurRadius: 30 * _glowAnimation.value,
                    spreadRadius: 10 * _glowAnimation.value,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Stack(
                  children: [
                    widget.child,
                    // Shine overlay
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                            stops: [
                              (_shineAnimation.value - 0.3).clamp(0.0, 1.0),
                              _shineAnimation.value.clamp(0.0, 1.0),
                              (_shineAnimation.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Achievement unlock dialog that shows with fanfare
class AchievementUnlockDialog extends StatefulWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final int points;
  final VoidCallback? onDismiss;

  const AchievementUnlockDialog({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.points,
    this.onDismiss,
  });

  @override
  State<AchievementUnlockDialog> createState() => _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<AchievementUnlockDialog>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _contentController;
  late ConfettiController _confettiController;
  late Animation<double> _bgAnimation;
  late Animation<double> _contentScaleAnimation;
  late Animation<double> _contentOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _bgAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeOut),
    );

    _contentScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_contentController);

    _contentOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Start animations
    _bgController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _contentController.forward();
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _contentController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _contentController.reverse();
    await _bgController.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bgController, _contentController]),
      builder: (context, child) {
        return GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withValues(alpha: _bgAnimation.value * 0.7),
            child: Stack(
              children: [
                // Confetti
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Colors.amber,
                      Colors.orange,
                      Colors.yellow,
                      Colors.purple,
                      Colors.blue,
                    ],
                    numberOfParticles: 50,
                    maxBlastForce: 30,
                    minBlastForce: 10,
                    gravity: 0.1,
                  ),
                ),
                // Content
                Center(
                  child: Opacity(
                    opacity: _contentOpacityAnimation.value,
                    child: Transform.scale(
                      scale: _contentScaleAnimation.value,
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.amber.shade800,
                              Colors.orange.shade900,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              size: 48,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ACHIEVEMENT UNLOCKED!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (widget.imageUrl != null)
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    widget.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey,
                                      child: const Icon(
                                        Icons.stars,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.yellow,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${widget.points} points',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap anywhere to dismiss',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
}

// ============ HAPTIC FEEDBACK UTILITIES ============

/// Utility class for consistent haptic feedback throughout the app
class Haptics {
  Haptics._();

  /// Light tap feedback - for button presses, list item taps
  static void light() => HapticFeedback.lightImpact();

  /// Medium feedback - for toggles, selections, confirmations
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy feedback - for important actions, deletions
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection feedback - for picker changes, tab switches
  static void selection() => HapticFeedback.selectionClick();

  /// Vibrate feedback - for errors, warnings
  static void vibrate() => HapticFeedback.vibrate();

  /// Success feedback - for achievements, completions
  static void success() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Celebration feedback - for milestones, big achievements
  static void celebration() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 160), () {
      HapticFeedback.lightImpact();
    });
  }
}

// ============ CUSTOM REFRESH INDICATOR ============

/// Custom pull-to-refresh indicator with retro gaming theme
class RetroRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  const RetroRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    return RefreshIndicator(
      onRefresh: () async {
        Haptics.medium();
        await onRefresh();
      },
      color: indicatorColor,
      backgroundColor: theme.cardColor,
      strokeWidth: 3,
      displacement: 60,
      child: child,
    );
  }
}

/// Animated loading spinner with retro game controller icon
class RetroLoadingSpinner extends StatefulWidget {
  final double size;
  final Color? color;

  const RetroLoadingSpinner({
    super.key,
    this.size = 48,
    this.color,
  });

  @override
  State<RetroLoadingSpinner> createState() => _RetroLoadingSpinnerState();
}

class _RetroLoadingSpinnerState extends State<RetroLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return RotationTransition(
      turns: _controller,
      child: Icon(
        Icons.sports_esports,
        size: widget.size,
        color: color,
      ),
    );
  }
}

/// Pulsing loading indicator
class PulsingLoader extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const PulsingLoader({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<PulsingLoader> createState() => _PulsingLoaderState();
}

class _PulsingLoaderState extends State<PulsingLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
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
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

// ============ EMPTY STATE ILLUSTRATIONS ============

/// Beautiful empty state widget with animated icon
class EmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
  });

  /// Empty state for no games
  factory EmptyStateWidget.noGames({Widget? action}) => EmptyStateWidget(
        icon: Icons.sports_esports_outlined,
        title: 'No games yet',
        subtitle: 'Start playing to see your games here!',
        action: action,
      );

  /// Empty state for no achievements
  factory EmptyStateWidget.noAchievements({Widget? action}) => EmptyStateWidget(
        icon: Icons.emoji_events_outlined,
        title: 'No achievements yet',
        subtitle: 'Earn achievements by playing games',
        iconColor: Colors.amber,
        action: action,
      );

  /// Empty state for no favorites
  factory EmptyStateWidget.noFavorites({Widget? action}) => EmptyStateWidget(
        icon: Icons.star_outline,
        title: 'No favorites yet',
        subtitle: 'Star games you want to track',
        iconColor: Colors.amber,
        action: action,
      );

  /// Empty state for no friends
  factory EmptyStateWidget.noFriends({Widget? action}) => EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No friends yet',
        subtitle: 'Add friends to compare progress',
        action: action,
      );

  /// Empty state for search with no results
  factory EmptyStateWidget.noResults({String? query, Widget? action}) =>
      EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No results found',
        subtitle: query != null ? 'No matches for "$query"' : 'Try a different search',
        action: action,
      );

  /// Empty state for no notifications
  factory EmptyStateWidget.noNotifications({Widget? action}) => EmptyStateWidget(
        icon: Icons.notifications_off_outlined,
        title: 'All caught up!',
        subtitle: 'No new notifications',
        action: action,
      );

  /// Empty state for error
  factory EmptyStateWidget.error({String? message, Widget? action}) =>
      EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        subtitle: message ?? 'Please try again later',
        iconColor: Colors.red,
        action: action,
      );

  /// Empty state for offline
  factory EmptyStateWidget.offline({Widget? action}) => EmptyStateWidget(
        icon: Icons.cloud_off,
        title: 'You\'re offline',
        subtitle: 'Check your internet connection',
        action: action,
      );

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = widget.iconColor ??
        (isDark ? Colors.grey[400] : Colors.grey[600]);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon with decorative circle
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (widget.iconColor ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 64,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.action != null) ...[
                const SizedBox(height: 24),
                widget.action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============ STREAK MILESTONE CELEBRATION ============

/// Widget that shows a celebration for streak milestones
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
