import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/features/auth/auth_screen.dart';

class StudentSurvivorApp extends StatelessWidget {
  const StudentSurvivorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Survivor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthScreen(),
    );
  }
}
