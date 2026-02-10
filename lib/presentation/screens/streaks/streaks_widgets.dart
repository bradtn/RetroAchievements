import 'package:flutter/material.dart';
import '../../../core/theme_utils.dart';
import '../../../core/animations.dart';

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
    final isMilestone = StreakMilestoneBadge.isMilestone(value);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
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
                  AnimatedStreakFlame(streakDays: value, size: 24)
                else
                  Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isMilestone) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: StreakMilestoneBadge(streakDays: value),
                  ),
                ],
              ],
            ),
            Text(
              value == 1 ? 'day' : 'days',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
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
  final bool isToday;
  final bool isFuture;

  const CalendarDay({
    super.key,
    required this.day,
    required this.activityCount,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (isFuture) {
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
        border: isToday ? Border.all(color: Colors.orange, width: 2) : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isFuture
                ? Colors.grey
                : (activityCount > 0 ? Colors.white : null),
          ),
        ),
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
          style: TextStyle(
            fontSize: 10,
            color: context.subtitleColor,
          ),
        ),
      ],
    );
  }
}

class StatItem extends StatelessWidget {
  final String value;
  final String label;

  const StatItem({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.subtitleColor,
          ),
        ),
      ],
    );
  }
}

String getMonthName(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${months[date.month - 1]} ${date.year}';
}

bool isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}
