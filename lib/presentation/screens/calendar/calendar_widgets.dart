import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme_utils.dart';
import '../../../core/animations.dart';
import '../game_detail_screen.dart';
import 'calendar_helpers.dart';

class StreakCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool showFlame;

  const StreakCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.showFlame = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showFlame && value > 0)
                  AnimatedStreakFlame(streakDays: value, size: 20)
                else
                  Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  value == 1 ? 'day' : 'days',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarDay extends StatelessWidget {
  final int day;
  final int activityCount;
  final bool isSelected;
  final bool isToday;
  final bool isFuture;

  const CalendarDay({
    super.key,
    required this.day,
    required this.activityCount,
    required this.isSelected,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (isSelected) {
      bgColor = Theme.of(context).colorScheme.primary;
    } else if (isFuture) {
      bgColor = Colors.transparent;
    } else if (activityCount == 0) {
      bgColor = Theme.of(context).brightness == Brightness.light
          ? Colors.grey.shade200
          : Colors.grey.shade800;
    } else if (activityCount <= 2) {
      bgColor = Colors.green.shade300;
    } else if (activityCount <= 5) {
      bgColor = Colors.green.shade500;
    } else {
      bgColor = Colors.green.shade700;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: isToday && !isSelected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : isFuture
                      ? Colors.grey
                      : (activityCount > 0 ? Colors.white : null),
            ),
          ),
          if (activityCount > 0 && !isSelected)
            Text(
              '$activityCount',
              style: const TextStyle(
                fontSize: 8,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.subtitleColor),
        ),
      ],
    );
  }
}

class CalendarAchievementTile extends StatelessWidget {
  final dynamic achievement;

  const CalendarAchievementTile({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final gameTitle = achievement['GameTitle'] ?? '';
    final gameId = achievement['GameID'];
    final dateStr = achievement['Date'] ?? achievement['DateEarned'] ?? '';
    final formattedTime = formatTime(dateStr);
    final hardcoreMode = achievement['HardcoreMode'] == 1 ||
                         achievement['HardcoreMode'] == true ||
                         achievement['Hardcore'] == 1 ||
                         achievement['Hardcore'] == true ||
                         achievement['DateEarnedHardcore'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: gameId != null ? () {
          Haptics.light();
          final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
          if (id > 0) {
            Navigator.push(
              context,
              SlidePageRoute(
                page: GameDetailScreen(gameId: id, gameTitle: gameTitle),
              ),
            );
          }
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: Colors.grey[800],
                child: const Icon(Icons.emoji_events),
              ),
            ),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.subtitleColor, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.stars, size: 12, color: Colors.amber[400]),
                  const SizedBox(width: 4),
                  Text('$points pts', style: TextStyle(color: Colors.amber[400], fontSize: 11)),
                  if (hardcoreMode) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HC',
                        style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (formattedTime.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(formattedTime, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                gameTitle,
                style: TextStyle(color: context.subtitleColor, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LegendItem(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.grey.shade200
              : Colors.grey.shade800,
          label: 'None',
        ),
        const SizedBox(width: 12),
        LegendItem(color: Colors.green.shade300, label: '1-2'),
        const SizedBox(width: 12),
        LegendItem(color: Colors.green.shade500, label: '3-5'),
        const SizedBox(width: 12),
        LegendItem(color: Colors.green.shade700, label: '6+'),
      ],
    );
  }
}

class DayHeader extends StatelessWidget {
  final DateTime selectedDate;
  final int achievementCount;

  const DayHeader({
    super.key,
    required this.selectedDate,
    required this.achievementCount,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = formatDate(selectedDate);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            dateStr,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: achievementCount > 0
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$achievementCount unlock${achievementCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: achievementCount > 0 ? Colors.green : context.subtitleColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyDayView extends StatelessWidget {
  const EmptyDayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No achievements on this day',
            style: TextStyle(color: context.subtitleColor),
          ),
        ],
      ),
    );
  }
}

class CalendarErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const CalendarErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(error, style: TextStyle(color: context.subtitleColor)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('View My Calendar'),
          ),
        ],
      ),
    );
  }
}
