import 'package:flutter/material.dart';

/// Parallax scrolling effect for backgrounds
class ParallaxFlexibleSpaceBar extends StatelessWidget {
  final Widget background;
  final Widget? foreground;
  final double parallaxFactor;

  const ParallaxFlexibleSpaceBar({
    super.key,
    required this.background,
    this.foreground,
    this.parallaxFactor = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        if (settings == null) {
          return background;
        }

        final deltaExtent = settings.maxExtent - settings.minExtent;
        final t = (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent)
            .clamp(0.0, 1.0);

        // Calculate parallax offset
        final parallaxOffset = t * deltaExtent * parallaxFactor;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Parallax background
            Positioned(
              top: -parallaxOffset,
              left: 0,
              right: 0,
              height: constraints.maxHeight + (deltaExtent * parallaxFactor),
              child: background,
            ),
            // Gradient overlay that fades in as we scroll
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3 + (t * 0.4)),
                    ],
                  ),
                ),
              ),
            ),
            // Optional foreground content
            if (foreground != null) foreground!,
          ],
        );
      },
    );
  }
}

/// A header image that slightly zooms and moves on scroll
class AnimatedHeaderImage extends StatelessWidget {
  final String imageUrl;
  final ScrollController scrollController;
  final double maxZoom;
  final double height;

  const AnimatedHeaderImage({
    super.key,
    required this.imageUrl,
    required this.scrollController,
    this.maxZoom = 1.2,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final offset = scrollController.hasClients ? scrollController.offset : 0.0;

        // When pulling down (negative offset), zoom in
        final zoom = offset < 0 ? 1.0 + (-offset / height) * (maxZoom - 1.0) : 1.0;

        // When scrolling up, apply parallax
        final parallax = offset > 0 ? offset * 0.5 : 0.0;

        return SizedBox(
          height: height + (offset < 0 ? -offset : 0),
          child: Transform.translate(
            offset: Offset(0, parallax),
            child: Transform.scale(
              scale: zoom.clamp(1.0, maxZoom),
              child: child,
            ),
          ),
        );
      },
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade800,
          child: const Icon(Icons.image, size: 64, color: Colors.grey),
        ),
      ),
    );
  }
}
