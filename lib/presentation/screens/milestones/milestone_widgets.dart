import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme_utils.dart';
import '../../../core/animations.dart';
import 'milestone_data.dart';

class MilestoneDetailDialog extends StatefulWidget {
  final Milestone milestone;
  final String? viewingUsername;
  final String userPic;
  final VoidCallback onShare;

  const MilestoneDetailDialog({
    super.key,
    required this.milestone,
    required this.viewingUsername,
    required this.userPic,
    required this.onShare,
  });

  @override
  State<MilestoneDetailDialog> createState() => _MilestoneDetailDialogState();
}

class _MilestoneDetailDialogState extends State<MilestoneDetailDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    // Auto-trigger confetti for earned milestones
    if (widget.milestone.isEarned) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _confettiController.play();
        }
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestone;
    final progress = milestone.requirement > 0
        ? (milestone.currentValue / milestone.requirement).clamp(0.0, 1.0)
        : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge icon with celebration animation
                  if (milestone.isEarned)
                    CelebrationBadge(
                      celebrate: true,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: milestone.color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: milestone.color.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          milestone.icon,
                          size: 36,
                          color: milestone.color,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: milestone.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: milestone.color.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        milestone.icon,
                        size: 36,
                        color: milestone.color.withValues(alpha: 0.7),
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    milestone.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    milestone.description,
                    style: TextStyle(color: context.subtitleColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: milestone.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      milestone.category,
                      style: TextStyle(color: milestone.color, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progress or earned status
                  if (!milestone.isEarned) ...[
                    AnimatedCounter(
                      value: milestone.currentValue,
                      suffix: ' / ${milestone.requirement}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedProgressBar(
                      progress: progress,
                      color: milestone.color,
                      backgroundColor: Colors.grey,
                      height: 8,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(progress * 100).toInt()}% complete',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: widget.onShare,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'EARNED',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: widget.onShare,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Confetti overlay for earned milestones
            if (milestone.isEarned)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: [
                      milestone.color,
                      milestone.color.withValues(alpha: 0.7),
                      Colors.amber,
                      Colors.orange,
                      Colors.yellow,
                    ],
                    numberOfParticles: 20,
                    maxBlastForce: 15,
                    minBlastForce: 5,
                    emissionFrequency: 0.05,
                    gravity: 0.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MilestoneBadge extends StatelessWidget {
  final Milestone milestone;
  final VoidCallback onTap;
  final bool compact;

  const MilestoneBadge({
    super.key,
    required this.milestone,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = milestone.requirement > 0
        ? (milestone.currentValue / milestone.requirement).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).toInt();

    final iconSize = compact ? 24.0 : 32.0;
    final progressSize = compact ? 32.0 : 40.0;
    final progressIconSize = compact ? 16.0 : 20.0;
    final fontSize = compact ? 8.0 : 10.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: milestone.color.withValues(alpha: milestone.isEarned ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          border: Border.all(
            color: milestone.color.withValues(alpha: milestone.isEarned ? 0.5 : 0.3),
            width: compact ? 1.5 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (milestone.isEarned) ...[
              // Earned: just show the icon
              Icon(
                milestone.icon,
                size: iconSize,
                color: milestone.color,
              ),
            ] else ...[
              // Not earned: show icon with circular progress
              SizedBox(
                width: progressSize,
                height: progressSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: compact ? 2 : 3,
                      color: milestone.color.withValues(alpha: 0.15),
                    ),
                    // Progress circle
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: compact ? 2 : 3,
                      color: milestone.color.withValues(alpha: 0.8),
                      backgroundColor: Colors.transparent,
                    ),
                    // Icon in center
                    Icon(
                      milestone.icon,
                      size: progressIconSize,
                      color: milestone.color.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: compact ? 4 : 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
              child: Text(
                milestone.title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: milestone.isEarned ? null : milestone.color.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!milestone.isEarned) ...[
              SizedBox(height: compact ? 1 : 2),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: milestone.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RAAwardBadge extends StatelessWidget {
  final Map<String, dynamic> award;
  final VoidCallback onTap;
  final bool compact;

  const RAAwardBadge({
    super.key,
    required this.award,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = award['Title'] ?? 'Award';
    final imageIcon = award['ImageIcon'] ?? '';
    final awardType = award['AwardType'] ?? '';

    // Determine border color based on award type
    Color borderColor;
    switch (awardType) {
      case 'Mastery/Completion':
        borderColor = Colors.amber;
        break;
      case 'Game Beaten':
        final isHardcore = award['AwardDataExtra'] == 1;
        borderColor = isHardcore ? Colors.orange : Colors.green;
        break;
      default:
        borderColor = Colors.blue;
    }

    final imageSize = compact ? 36.0 : 48.0;
    final fontSize = compact ? 8.0 : 10.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: borderColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.5),
            width: compact ? 1.5 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 6 : 8),
              child: Image.network(
                'https://retroachievements.org$imageIcon',
                width: imageSize,
                height: imageSize,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: imageSize,
                  height: imageSize,
                  color: Colors.grey[800],
                  child: Icon(Icons.emoji_events, color: borderColor, size: imageSize / 2),
                ),
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AwardStat extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final bool compact;

  const AwardStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: compact ? 16 : 20),
        SizedBox(height: compact ? 2 : 4),
        Text(
          '$value',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: compact ? 12 : 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: compact ? 8 : 10,
          ),
        ),
      ],
    );
  }
}

class RAAwardsSummary extends StatelessWidget {
  final int totalAwards;
  final int masteryCount;
  final int beatenHardcore;
  final int beatenSoftcore;
  final int eventAwards;
  final bool compact;
  final VoidCallback? onShare;

  const RAAwardsSummary({
    super.key,
    required this.totalAwards,
    required this.masteryCount,
    required this.beatenHardcore,
    required this.beatenSoftcore,
    required this.eventAwards,
    this.compact = false,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade700,
              Colors.purple.shade800,
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.military_tech, color: Colors.white, size: compact ? 20 : 28),
                    SizedBox(width: compact ? 6 : 8),
                    Text(
                      '$totalAwards',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 22 : 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  'RetroAchievements Awards',
                  style: TextStyle(color: Colors.white70, fontSize: compact ? 11 : 14),
                ),
                SizedBox(height: compact ? 10 : 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AwardStat(icon: Icons.workspace_premium, value: masteryCount, label: 'Mastery', compact: compact),
                    AwardStat(icon: Icons.verified, value: beatenHardcore, label: 'Beaten HC', compact: compact),
                    AwardStat(icon: Icons.check_circle, value: beatenSoftcore, label: 'Beaten', compact: compact),
                    if (eventAwards > 0)
                      AwardStat(icon: Icons.celebration, value: eventAwards, label: 'Events', compact: compact),
                  ],
                ),
              ],
            ),
            if (onShare != null)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white70, size: 20),
                  onPressed: onShare,
                  tooltip: 'Share',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GoalsSummary extends StatelessWidget {
  final int completed;
  final int total;
  final bool compact;
  final VoidCallback? onShare;

  const GoalsSummary({
    super.key,
    required this.completed,
    required this.total,
    this.compact = false,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;

    return Card(
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.teal.shade600,
              Colors.green.shade700,
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flag, color: Colors.white, size: compact ? 20 : 28),
                    SizedBox(width: compact ? 6 : 8),
                    Text(
                      '$completed / $total',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 22 : 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  'RetroTrack Goals',
                  style: TextStyle(color: Colors.white70, fontSize: compact ? 11 : 14),
                ),
                SizedBox(height: compact ? 10 : 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(compact ? 4 : 8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: compact ? 6 : 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
            if (onShare != null)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white70, size: 20),
                  onPressed: onShare,
                  tooltip: 'Share',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
