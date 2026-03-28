import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';

class AdminBreadcrumb extends StatelessWidget {
  final String label;

  const AdminBreadcrumb({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.home, size: 18),
            label: const Text('Dashboard'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '›',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
