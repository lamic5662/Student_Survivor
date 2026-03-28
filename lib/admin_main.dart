import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:student_survivor/admin_app.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await SupabaseConfig.initialize();

  if (!SupabaseConfig.isConfigured) {
    runApp(const MissingSupabaseConfigApp());
    return;
  }

  runApp(const AdminApp());
}
