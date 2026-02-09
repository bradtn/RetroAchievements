import 'package:flutter/material.dart';
import 'haptics.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        Haptics.medium();
        await onRefresh();
      },
      // Distinctive amber/gold color
      color: color ?? Colors.amber,
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      strokeWidth: 3,
      displacement: 50,
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

