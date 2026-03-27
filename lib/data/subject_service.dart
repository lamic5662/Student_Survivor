import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectService {
  final SupabaseClient _client;

  SubjectService(this._client);

  Future<List<Semester>> fetchSemesters() async {
    final data = await _client
        .from('semesters')
        .select('id, name, code, subjects(id,name,code,accent_color)')
        .order('sort_order');

    return (data as List<dynamic>).map(_semesterFromMap).toList();
  }

  Semester _semesterFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final subjects = (map['subjects'] as List<dynamic>? ?? [])
        .map(_subjectFromMap)
        .toList();

    return Semester(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Semester',
      subjects: subjects,
    );
  }

  Subject _subjectFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return Subject(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Subject',
      code: map['code']?.toString() ?? '',
      accentColor: _parseColor(map['accent_color']?.toString()),
      chapters: const [],
    );
  }

  Color _parseColor(String? value) {
    if (value == null || value.isEmpty) {
      return const Color(0xFF6366F1);
    }
    final hex = value.replaceAll('#', '').padLeft(6, '0');
    final colorValue = int.tryParse('FF$hex', radix: 16) ?? 0xFF6366F1;
    return Color(colorValue);
  }
}
