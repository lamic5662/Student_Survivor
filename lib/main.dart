import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:student_survivor/app.dart';
import 'package:student_survivor/data/supabase_config.dart';

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

  runApp(const StudentSurvivorApp());
}

class MissingSupabaseConfigApp extends StatelessWidget {
  const MissingSupabaseConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Survivor',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missing Supabase Config',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Run the app with these values set:',
                ),
                SizedBox(height: 12),
                Text(
                  'flutter run \\\n  --dart-define=SUPABASE_URL=YOUR_URL \\\n  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY',
                  style: TextStyle(fontFamily: 'Courier'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
