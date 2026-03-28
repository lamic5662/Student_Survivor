import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/features/admin/admin_gate.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Survivor Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AdminGate(),
    );
  }
}
