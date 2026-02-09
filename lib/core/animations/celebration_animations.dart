import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'haptics.dart';

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
