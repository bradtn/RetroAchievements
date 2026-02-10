import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;

  const FeatureTile(this.icon, this.title, this.subtitle, this.locked, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return ListTile(
      leading: Icon(icon, color: locked ? Colors.grey : Colors.green),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(subtitle, style: TextStyle(color: subtitleColor)),
      trailing: locked
          ? const Icon(Icons.lock, size: 18, color: Colors.grey)
          : const Icon(Icons.check_circle, size: 18, color: Colors.green),
    );
  }
}

class CheckItem extends StatelessWidget {
  final String text;
  const CheckItem(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }
}
