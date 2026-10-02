import 'package:flutter/material.dart';

/// Individual feature card widget
class ProfileFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const ProfileFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

