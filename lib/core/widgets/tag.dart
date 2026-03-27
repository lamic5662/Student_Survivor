import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';

class Tag extends StatelessWidget {
  final String label;
  final Color? color;

  const Tag({
    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: baseColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
