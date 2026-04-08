import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/localization/locale_controller.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/features/auth/auth_screen.dart';

class StudentSurvivorApp extends StatelessWidget {
  const StudentSurvivorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'StudentSurge',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthScreen(),
        );
      },
    );
  }
}
