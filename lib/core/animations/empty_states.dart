import 'package:flutter/material.dart';

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
        subtitle: 'Start playing to see your games here!\n\nPull down to refresh',
        action: action,
      );

  /// Empty state for no achievements
  factory EmptyStateWidget.noAchievements({Widget? action}) => EmptyStateWidget(
        icon: Icons.emoji_events_outlined,
        title: 'No achievements yet',
        subtitle: 'Earn achievements by playing games\n\nPull down to refresh',
        iconColor: Colors.amber,
        action: action,
      );

  /// Empty state for no favorites
  factory EmptyStateWidget.noFavorites({Widget? action}) => EmptyStateWidget(
        icon: Icons.star_outline,
        title: 'No favorites yet',
        subtitle: 'Star games you want to track\n\nPull down to refresh',
        iconColor: Colors.amber,
        action: action,
      );

  /// Empty state for no friends
  factory EmptyStateWidget.noFriends({Widget? action}) => EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No friends yet',
        subtitle: 'Add friends to compare progress\n\nPull down to refresh',
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

