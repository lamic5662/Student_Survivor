import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class CollegeService {
  final SupabaseClient _client;

  CollegeService(this._client);

  Future<List<College>> fetchColleges({bool includeInactive = false}) async {
    final baseQuery =
        _client.from('colleges').select('id,name,is_active');
    final data = includeInactive
        ? await baseQuery.order('name')
        : await baseQuery.eq('is_active', true).order('name');
    return (data as List<dynamic>)
        .map(
          (row) => College(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            isActive: row['is_active'] as bool? ?? true,
          ),
        )
        .where((college) => college.id.isNotEmpty && college.name.isNotEmpty)
        .toList();
  }
}
