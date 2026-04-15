import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';
import 'package:student_survivor/data/ai_request.dart';
import 'package:student_survivor/data/ai_router_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/supabase_mappers.dart';
import 'package:student_survivor/models/app_models.dart';

class SyllabusBulkResult {
  final int uploaded;
  final int skipped;
  final List<String> messages;
  final List<String> unmatchedFiles;
  final List<String> ambiguousFiles;

  const SyllabusBulkResult({
    required this.uploaded,
    required this.skipped,
    required this.messages,
    this.unmatchedFiles = const [],
    this.ambiguousFiles = const [],
  });
}

class BulkUploadResult {
  final int uploaded;
  final int skipped;
  final List<String> messages;

  const BulkUploadResult({
    required this.uploaded,
    required this.skipped,
    required this.messages,
  });
}

class AdminSemesterRecord {
  final String id;
  final String name;
  final String code;
  final int sortOrder;

  const AdminSemesterRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.sortOrder,
  });
}

class AdminSubjectRecord {
  final String id;
  final String semesterId;
  final String name;
  final String code;
  final String description;
  final String accentColor;
  final int sortOrder;

  const AdminSubjectRecord({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.code,
    required this.description,
    required this.accentColor,
    required this.sortOrder,
  });
}

class AdminChapterRecord {
  final String id;
  final String subjectId;
  final String title;
  final String summary;
  final int sortOrder;
  final List<ChapterTopic> subtopics;

  const AdminChapterRecord({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.summary,
    required this.sortOrder,
    required this.subtopics,
  });
}

class AdminService {
  final SupabaseClient _client;
  final AiRouterService _aiRouter;

  AdminService(this._client) : _aiRouter = AiRouterService(_client);

  Future<void> addSemester({
    required String name,
    required String code,
    required int sortOrder,
  }) async {
    await _client.from('semesters').insert({
      'name': name,
      'code': code,
      'sort_order': sortOrder,
    });
  }

  Future<AdminSemesterRecord> fetchSemesterRecord(String semesterId) async {
    final row = await _client
        .from('semesters')
        .select('id,name,code,sort_order')
        .eq('id', semesterId)
        .single();
    return AdminSemesterRecord(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      code: row['code']?.toString() ?? '',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> updateSemester({
    required String semesterId,
    required String name,
    required String code,
    required int sortOrder,
  }) async {
    await _client.from('semesters').update({
      'name': name,
      'code': code,
      'sort_order': sortOrder,
    }).eq('id', semesterId);
  }

  Future<void> deleteSemester(String semesterId) async {
    await _client.from('semesters').delete().eq('id', semesterId);
  }

  Future<List<College>> fetchColleges({bool includeInactive = true}) async {
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

  Future<void> addCollege({required String name}) async {
    await _client.from('colleges').insert({'name': name});
  }

  Future<void> updateCollege({
    required String collegeId,
    required String name,
  }) async {
    await _client
        .from('colleges')
        .update({'name': name})
        .eq('id', collegeId);
  }

  Future<void> setCollegeActive({
    required String collegeId,
    required bool isActive,
  }) async {
    await _client
        .from('colleges')
        .update({'is_active': isActive})
        .eq('id', collegeId);
  }

  Future<void> deleteCollege(String collegeId) async {
    await _client.from('colleges').delete().eq('id', collegeId);
  }

  Future<List<AdminManagedUser>> fetchUsers({
    String query = '',
    bool? blockedOnly,
    int limit = 25,
    int offset = 0,
  }) async {
    final trimmed = query.trim().toLowerCase();
    List<AdminManagedUser> users;
    try {
      dynamic queryBuilder = _client.from('profiles').select(
        'id,full_name,email,phone,college_name,semester_id,is_admin,is_blocked,blocked_reason,blocked_at',
      );
      if (blockedOnly == true) {
        queryBuilder = queryBuilder.eq('is_blocked', true);
      }
      if (trimmed.isNotEmpty) {
        final escaped = _escapeIlike(trimmed);
        queryBuilder = queryBuilder.or(
          'full_name.ilike.%$escaped%,'
          'email.ilike.%$escaped%,'
          'phone.ilike.%$escaped%,'
          'college_name.ilike.%$escaped%',
        );
      }
      final data = await queryBuilder
          .order('updated_at', ascending: false)
          .range(offset, offset + limit - 1);
      final maps = (data as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();
      final semesterLookup = await _fetchSemesterLookup(
        maps
            .map((row) => row['semester_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
      users = maps
          .map((row) => _adminManagedUserFromMap(row, semesterLookup))
          .toList();
    } on PostgrestException catch (error) {
      final fallbackData = await _loadUsersFallback(
        error,
        query: trimmed,
        blockedOnly: blockedOnly,
        limit: limit,
        offset: offset,
      );
      users = fallbackData;
    }
    return users;
  }

  Future<List<AdminManagedUser>> _loadUsersFallback(
    PostgrestException originalError,
    {
    required String query,
    required bool? blockedOnly,
    required int limit,
    required int offset,
  }
  ) async {
    try {
      final rows = await _client
          .from('profiles')
          .select(
            'id,full_name,email,phone,college_name,is_admin,semester_id',
          )
          .order('updated_at', ascending: false);
      final maps = (rows as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();
      final semesterLookup = await _fetchSemesterLookup(
        maps
            .map((row) => row['semester_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );

      var users = maps.map((map) {
        return _adminManagedUserFromMap(map, semesterLookup);
      }).toList();

      if (blockedOnly == true) {
        users = const [];
      }
      if (query.isNotEmpty) {
        users = users.where((user) {
          return user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.phone.toLowerCase().contains(query) ||
              user.collegeName.toLowerCase().contains(query) ||
              user.semesterName.toLowerCase().contains(query);
        }).toList();
      }
      final start = offset.clamp(0, users.length);
      final end = (start + limit).clamp(0, users.length);
      return users.sublist(start, end);
    } on PostgrestException {
      throw Exception(
        'Admin user schema is not ready. Apply the latest Supabase migrations, including 0050_admin_moderation.sql. Original error: ${originalError.message}',
      );
    }
  }

  Future<void> setUserBlocked({
    required String userId,
    required bool blocked,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'is_blocked': blocked,
      'blocked_reason': blocked ? reason?.trim() : null,
      'blocked_at':
          blocked ? DateTime.now().toUtc().toIso8601String() : null,
      'blocked_by': blocked ? _client.auth.currentUser?.id : null,
    };
    await _client.from('profiles').update(payload).eq('id', userId);
    await _logAdminAction(
      actionType: blocked ? 'user_blocked' : 'user_unblocked',
      targetType: 'profile',
      targetId: userId,
      targetUserId: userId,
      details: {
        if (blocked) 'reason': reason?.trim() ?? '',
      },
    );
  }

  Future<void> deleteUser(String userId) async {
    await _client.rpc('admin_delete_user', params: {'p_user_id': userId});
  }

  Future<int> fetchUserCount() async {
    final rows = await _client.from('profiles').select('id');
    return (rows as List<dynamic>).length;
  }

  Future<int> fetchFilteredUserCount({
    String query = '',
    bool? blockedOnly,
  }) async {
    final trimmed = query.trim().toLowerCase();
    try {
      dynamic queryBuilder = _client.from('profiles').select('id');
      if (blockedOnly == true) {
        queryBuilder = queryBuilder.eq('is_blocked', true);
      }
      if (trimmed.isNotEmpty) {
        final escaped = _escapeIlike(trimmed);
        queryBuilder = queryBuilder.or(
          'full_name.ilike.%$escaped%,'
          'email.ilike.%$escaped%,'
          'phone.ilike.%$escaped%,'
          'college_name.ilike.%$escaped%',
        );
      }
      final response = await queryBuilder.count(CountOption.exact);
      return response.count ?? 0;
    } on PostgrestException {
      final rows = await _client
          .from('profiles')
          .select(
            'id,full_name,email,phone,college_name,is_admin,semester_id',
          )
          .order('updated_at', ascending: false);
      final maps = (rows as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();
      final semesterLookup = await _fetchSemesterLookup(
        maps
            .map((row) => row['semester_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
      var users = maps.map((map) {
        return _adminManagedUserFromMap(map, semesterLookup);
      }).toList();
      if (blockedOnly == true) {
        users = const [];
      }
      if (trimmed.isNotEmpty) {
        users = users.where((user) {
          return user.name.toLowerCase().contains(trimmed) ||
              user.email.toLowerCase().contains(trimmed) ||
              user.phone.toLowerCase().contains(trimmed) ||
              user.collegeName.toLowerCase().contains(trimmed) ||
              user.semesterName.toLowerCase().contains(trimmed);
        }).toList();
      }
      return users.length;
    }
  }

  Future<int> fetchBlockedUserCount() async {
    final rows = await _client
        .from('profiles')
        .select('id')
        .eq('is_blocked', true);
    return (rows as List<dynamic>).length;
  }

  Future<int> fetchRecentActivityCount({
    String search = '',
    String? activityType,
  }) async {
    final trimmed = search.trim();
    try {
      dynamic query = _client.from('admin_activity_feed').select('id');
      if (activityType != null && activityType.isNotEmpty) {
        query = query.eq('activity_type', activityType);
      }
      if (trimmed.isNotEmpty) {
        query = query.ilike('search_text', '%${_escapeIlike(trimmed)}%');
      }
      final response = await query.count(CountOption.exact);
      return response.count;
    } on PostgrestException {
      final entries = await fetchRecentActivities(
        limit: 500,
        offset: 0,
      );
      return _filterActivityEntries(
        entries,
        search: trimmed,
        activityType: activityType,
      ).length;
    }
  }

  Future<List<AdminActivityEntry>> fetchRecentActivities({
    int limit = 80,
    int offset = 0,
    String search = '',
    String? activityType,
  }) async {
    final trimmed = search.trim();
    try {
      dynamic query = _client.from('admin_activity_feed').select(
        'id,user_id,user_name,user_email,activity_type,source,points,subject_name,chapter_title,metadata,created_at',
      );
      if (activityType != null && activityType.isNotEmpty) {
        query = query.eq('activity_type', activityType);
      }
      if (trimmed.isNotEmpty) {
        query = query.ilike('search_text', '%${_escapeIlike(trimmed)}%');
      }
      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (rows as List<dynamic>)
          .map((row) => _adminActivityEntryFromFeedMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      final activityRows = await _client
          .from('user_activity_log')
          .select('id,user_id,activity_type,source,points,subject_id,chapter_id,metadata,created_at')
          .order('created_at', ascending: false)
          .range(0, 499);

      final rows = (activityRows as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();
      final profileLookup = await _fetchProfileLookup(
        rows
            .map((row) => row['user_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
      final subjectLookup = await _fetchSubjectLookup(
        rows
            .map((row) => row['subject_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
      final chapterLookup = await _fetchChapterLookup(
        rows
            .map((row) => row['chapter_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );

      final entries = rows
          .map(
            (row) => _adminActivityEntryFromMap(
              row,
              profileLookup: profileLookup,
              subjectLookup: subjectLookup,
              chapterLookup: chapterLookup,
            ),
          )
          .toList();
      final filtered = _filterActivityEntries(
        entries,
        search: trimmed,
        activityType: activityType,
      );
      final start = offset.clamp(0, filtered.length);
      final end = (start + limit).clamp(0, filtered.length);
      return filtered.sublist(start, end);
    }
  }

  Future<int> fetchAdminAuditCount({
    String search = '',
    String? actionType,
  }) async {
    final trimmed = search.trim();
    try {
      dynamic query = _client.from('admin_audit_feed').select('id');
      if (actionType != null && actionType.isNotEmpty) {
        query = query.eq('action_type', actionType);
      }
      if (trimmed.isNotEmpty) {
        query = query.ilike('search_text', '%${_escapeIlike(trimmed)}%');
      }
      final response = await query.count(CountOption.exact);
      return response.count;
    } on PostgrestException {
      final entries = await fetchAdminAuditEntries(
        limit: 500,
        offset: 0,
      );
      return _filterAuditEntries(
        entries,
        search: trimmed,
        actionType: actionType,
      ).length;
    }
  }

  Future<List<AdminAuditEntry>> fetchAdminAuditEntries({
    int limit = 60,
    int offset = 0,
    String search = '',
    String? actionType,
  }) async {
    final trimmed = search.trim();
    try {
      dynamic query = _client.from('admin_audit_feed').select(
        'id,actor_id,actor_name,actor_email,action_type,target_type,target_id,target_user_id,details,created_at',
      );
      if (actionType != null && actionType.isNotEmpty) {
        query = query.eq('action_type', actionType);
      }
      if (trimmed.isNotEmpty) {
        query = query.ilike('search_text', '%${_escapeIlike(trimmed)}%');
      }
      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (rows as List<dynamic>)
          .map((row) => _adminAuditEntryFromFeedMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      final rows = await _client
          .from('admin_audit_log')
          .select('id,actor_id,action_type,target_type,target_id,target_user_id,details,created_at')
          .order('created_at', ascending: false)
          .range(0, 499);

      final maps = (rows as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();
      final profileLookup = await _fetchProfileLookup(
        maps
            .map((row) => row['actor_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );

      final entries = maps
          .map(
            (row) => _adminAuditEntryFromMap(
              row,
              profileLookup: profileLookup,
            ),
          )
          .toList();
      final filtered = _filterAuditEntries(
        entries,
        search: trimmed,
        actionType: actionType,
      );
      final start = offset.clamp(0, filtered.length);
      final end = (start + limit).clamp(0, filtered.length);
      return filtered.sublist(start, end);
    }
  }

  Future<List<AdminContentReport>> fetchReports({
    String? status = 'pending',
  }) async {
    final baseQuery = _client.from('content_reports').select(
      'id,reporter_id,target_type,target_id,target_owner_id,target_title,target_preview,reason,details,status,reviewed_by,review_note,created_at,reviewed_at',
    );
    final rows = (status == null || status == 'all')
        ? await baseQuery.order('created_at', ascending: false)
        : await baseQuery
            .eq('status', status)
            .order('created_at', ascending: false);

    final maps = (rows as List<dynamic>)
        .map((row) => row as Map<String, dynamic>)
        .toList();
    final userIds = <String>{
      ...maps
          .map((row) => row['reporter_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
      ...maps
          .map((row) => row['reviewed_by']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    };
    final profileLookup = await _fetchProfileLookup(userIds);

    return maps
        .map(
          (row) => _adminContentReportFromMap(
            row,
            profileLookup: profileLookup,
          ),
        )
        .toList();
  }

  Future<int> fetchPendingReportCount() async {
    final rows = await _client
        .from('content_reports')
        .select('id')
        .eq('status', 'pending');
    return (rows as List<dynamic>).length;
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? reviewNote,
  }) async {
    final reviewerId = _client.auth.currentUser?.id;
    await _client.from('content_reports').update({
      'status': status,
      'reviewed_by': reviewerId,
      'review_note': reviewNote?.trim(),
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);
    await _logAdminAction(
      actionType: 'report_$status',
      targetType: 'content_report',
      targetId: reportId,
      details: {
        'review_note': reviewNote?.trim() ?? '',
      },
    );
  }

  Future<void> deleteUserNote(String noteId) async {
    await _client.from('user_notes').delete().eq('id', noteId);
    await _logAdminAction(
      actionType: 'user_note_deleted',
      targetType: 'user_note',
      targetId: noteId,
    );
  }

  Future<void> deleteCommunityQuestion(String questionId) async {
    await _client.from('community_questions').delete().eq('id', questionId);
    await _logAdminAction(
      actionType: 'community_question_deleted',
      targetType: 'community_question',
      targetId: questionId,
    );
  }

  Future<void> deleteCommunityAnswer(String answerId) async {
    await _client.from('community_answers').delete().eq('id', answerId);
    await _logAdminAction(
      actionType: 'community_answer_deleted',
      targetType: 'community_answer',
      targetId: answerId,
    );
  }

  Future<void> deleteChatMessage(String messageId) async {
    await _client.from('chat_messages').delete().eq('id', messageId);
    await _logAdminAction(
      actionType: 'chat_message_deleted',
      targetType: 'chat_message',
      targetId: messageId,
    );
  }

  Future<void> addSubject({
    required String semesterId,
    required String name,
    required String code,
    String? description,
    String? accentColor,
    int sortOrder = 0,
  }) async {
    await _client.from('subjects').insert({
      'semester_id': semesterId,
      'name': name,
      'code': code,
      'description': description,
      'accent_color': accentColor,
      'sort_order': sortOrder,
    });
  }

  Future<AdminSubjectRecord> fetchSubjectRecord(String subjectId) async {
    final row = await _client
        .from('subjects')
        .select(
          'id,semester_id,name,code,description,accent_color,sort_order',
        )
        .eq('id', subjectId)
        .single();
    return AdminSubjectRecord(
      id: row['id']?.toString() ?? '',
      semesterId: row['semester_id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      code: row['code']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      accentColor: row['accent_color']?.toString() ?? '#2563EB',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> updateSubject({
    required String subjectId,
    required String semesterId,
    required String name,
    required String code,
    String? description,
    String? accentColor,
    int sortOrder = 0,
  }) async {
    await _client.from('subjects').update({
      'semester_id': semesterId,
      'name': name,
      'code': code,
      'description': description,
      'accent_color': accentColor,
      'sort_order': sortOrder,
    }).eq('id', subjectId);
  }

  Future<void> deleteSubject(String subjectId) async {
    await _client.from('subjects').delete().eq('id', subjectId);
  }

  Future<void> addChapter({
    required String subjectId,
    required String title,
    String? summary,
    int sortOrder = 0,
    List<Map<String, dynamic>> subtopics = const [],
  }) async {
    final inserted = await _client
        .from('chapters')
        .insert({
          'subject_id': subjectId,
          'title': title,
          'summary': summary,
          'sort_order': sortOrder,
        })
        .select('id')
        .single();
    final chapterId = inserted['id']?.toString() ?? '';
    if (chapterId.isNotEmpty) {
      if (subtopics.isNotEmpty) {
        final payload = subtopics
            .map(
              (topic) => {
                'chapter_id': chapterId,
                'title': topic['title'],
                'summary': topic['summary'],
                'sort_order': topic['sort_order'] ?? 0,
              },
            )
            .toList();
        await _client.from('chapter_subtopics').insert(payload);
      }
      await _client.from('quizzes').insert({
        'chapter_id': chapterId,
        'title': 'AI Quick Quiz',
        'quiz_type': 'mcq',
        'difficulty': 'easy',
        'duration_minutes': 10,
        'question_count': 10,
      });
    }
  }

  Future<AdminChapterRecord> fetchChapterRecord(String chapterId) async {
    final row = await _client
        .from('chapters')
        .select('id,subject_id,title,summary,sort_order')
        .eq('id', chapterId)
        .single();
    final subtopicRows = await _client
        .from('chapter_subtopics')
        .select('id,title,summary,sort_order')
        .eq('chapter_id', chapterId)
        .order('sort_order');
    return AdminChapterRecord(
      id: row['id']?.toString() ?? '',
      subjectId: row['subject_id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      summary: row['summary']?.toString() ?? '',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      subtopics: (subtopicRows as List<dynamic>)
          .map(
            (item) => ChapterTopic(
              id: item['id']?.toString() ?? '',
              title: item['title']?.toString() ?? '',
              summary: item['summary']?.toString() ?? '',
              sortOrder: (item['sort_order'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
    );
  }

  Future<void> updateChapter({
    required String chapterId,
    required String subjectId,
    required String title,
    String? summary,
    int sortOrder = 0,
    List<Map<String, dynamic>> subtopics = const [],
  }) async {
    await _client.from('chapters').update({
      'subject_id': subjectId,
      'title': title,
      'summary': summary,
      'sort_order': sortOrder,
    }).eq('id', chapterId);
    await _client.from('chapter_subtopics').delete().eq('chapter_id', chapterId);
    if (subtopics.isNotEmpty) {
      final payload = subtopics
          .map(
            (topic) => {
              'chapter_id': chapterId,
              'title': topic['title'],
              'summary': topic['summary'],
              'sort_order': topic['sort_order'] ?? 0,
            },
          )
          .toList();
      await _client.from('chapter_subtopics').insert(payload);
    }
  }

  Future<void> deleteChapter(String chapterId) async {
    await _client.from('chapters').delete().eq('id', chapterId);
  }

  Future<void> addNote({
    required String chapterId,
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    List<String> tags = const [],
    String? fileUrl,
  }) async {
    final payload = <String, dynamic>{
      'chapter_id': chapterId,
      'title': title,
      'short_answer': shortAnswer,
      'detailed_answer': detailedAnswer,
      'tags': tags,
    };
    if (fileUrl != null && fileUrl.isNotEmpty) {
      payload['file_url'] = fileUrl;
    }
    await _client.from('notes').insert(payload);
  }

  Future<BulkUploadResult> uploadNotesBatch({
    required String chapterId,
    required List<PlatformFile> files,
    List<String> tags = const [],
  }) async {
    var uploaded = 0;
    var skipped = 0;
    final messages = <String>[];

    for (final file in files) {
      if (file.bytes == null || file.bytes!.isEmpty) {
        skipped += 1;
        messages.add('Skipped ${file.name} (no data).');
        continue;
      }

      final fileUrl = await uploadNoteAttachment(
        chapterId: chapterId,
        file: file,
      );
      final title = _baseName(file.name);
      final short = 'Attachment: ${file.name}';
      final detailed =
          'This note contains an uploaded file. Open the attachment to read the content.';

      await addNote(
        chapterId: chapterId,
        title: title.isEmpty ? 'Uploaded note' : title,
        shortAnswer: short,
        detailedAnswer: detailed,
        tags: tags,
        fileUrl: fileUrl,
      );
      uploaded += 1;
      messages.add('Uploaded ${file.name}');
    }

    return BulkUploadResult(
      uploaded: uploaded,
      skipped: skipped,
      messages: messages,
    );
  }

  Future<List<AdminNote>> fetchNotesForChapter(String chapterId) async {
    if (chapterId.isEmpty) {
      return [];
    }
    final data = await _client
        .from('notes')
        .select('id,chapter_id,title,short_answer,detailed_answer,file_url,tags')
        .eq('chapter_id', chapterId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((row) => _adminNoteFromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateNote({
    required String noteId,
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    List<String> tags = const [],
    String? fileUrl,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'short_answer': shortAnswer,
      'detailed_answer': detailedAnswer,
      'tags': tags,
    };
    if (fileUrl != null && fileUrl.isNotEmpty) {
      payload['file_url'] = fileUrl;
    }
    await _client.from('notes').update(payload).eq('id', noteId);
  }

  Future<void> deleteNote(String noteId) async {
    await _client.from('notes').delete().eq('id', noteId);
    await _logAdminAction(
      actionType: 'note_deleted',
      targetType: 'note',
      targetId: noteId,
    );
  }

  Future<int> fetchPendingNoteSubmissionCount() async {
    final data = await _client
        .from('note_submissions')
        .select('id')
        .eq('status', 'pending');
    return (data as List<dynamic>).length;
  }

  Future<List<AdminNoteSubmission>> fetchPendingNoteSubmissions({
    String? chapterId,
  }) async {
    final baseQuery = _client
        .from('note_submissions')
        .select(
          'id,user_id,chapter_id,title,short_answer,detailed_answer,file_url,tags,status,created_at,'
          'chapter:chapters(id,title,subject:subjects(id,name)),'
          'user:profiles(full_name,college_name)',
        )
        .eq('status', 'pending');

    if (chapterId != null && chapterId.isNotEmpty) {
      final data = await baseQuery
          .eq('chapter_id', chapterId)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((row) => _adminSubmissionFromMap(row as Map<String, dynamic>))
          .toList();
    }

    final data = await baseQuery.order('created_at', ascending: false);
    return (data as List<dynamic>)
        .map((row) => _adminSubmissionFromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveNoteSubmission(AdminNoteSubmission submission) async {
    await _client.from('notes').insert({
      'chapter_id': submission.chapterId,
      'title': submission.title,
      'short_answer': submission.shortAnswer,
      'detailed_answer': submission.detailedAnswer,
      'tags': submission.tags,
      if (submission.fileUrl != null && submission.fileUrl!.isNotEmpty)
        'file_url': submission.fileUrl,
    });

    final adminId = _client.auth.currentUser?.id;
    await _client.from('note_submissions').update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': adminId,
    }).eq('id', submission.id);
    await _logAdminAction(
      actionType: 'note_submission_approved',
      targetType: 'note_submission',
      targetId: submission.id,
      targetUserId: submission.userId,
      details: {
        'chapter_id': submission.chapterId,
        'title': submission.title,
      },
    );
  }

  Future<void> rejectNoteSubmission(
    AdminNoteSubmission submission, {
    String? feedback,
  }) async {
    final adminId = _client.auth.currentUser?.id;
    await _client.from('note_submissions').update({
      'status': 'rejected',
      'admin_feedback': feedback,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': adminId,
    }).eq('id', submission.id);
    await _logAdminAction(
      actionType: 'note_submission_rejected',
      targetType: 'note_submission',
      targetId: submission.id,
      targetUserId: submission.userId,
      details: {
        'feedback': feedback?.trim() ?? '',
      },
    );
  }

  Future<void> deleteNoteSubmission(String submissionId) async {
    await _client.from('note_submissions').delete().eq('id', submissionId);
    await _logAdminAction(
      actionType: 'note_submission_deleted',
      targetType: 'note_submission',
      targetId: submissionId,
    );
  }

  Future<List<AdminCommunityQuestion>> fetchPendingCommunityQuestions() async {
    final data = await _client
        .from('community_questions')
        .select(
          'id,question,subject_id,user_id,status,ai_reason,created_at,'
          'subject:subjects(id,name)',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((row) => _adminCommunityQuestionFromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveCommunityQuestion(AdminCommunityQuestion question) async {
    final adminId = _client.auth.currentUser?.id;
    await _client.from('community_questions').update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': adminId,
    }).eq('id', question.id);
    await _logAdminAction(
      actionType: 'community_question_approved',
      targetType: 'community_question',
      targetId: question.id,
      targetUserId: question.userId,
      details: {
        'subject_id': question.subjectId,
      },
    );
  }

  Future<void> rejectCommunityQuestion(
    AdminCommunityQuestion question, {
    String? adminReason,
  }) async {
    final adminId = _client.auth.currentUser?.id;
    await _client.from('community_questions').update({
      'status': 'rejected',
      'admin_reason': adminReason,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': adminId,
    }).eq('id', question.id);
    await _logAdminAction(
      actionType: 'community_question_rejected',
      targetType: 'community_question',
      targetId: question.id,
      targetUserId: question.userId,
      details: {
        'reason': adminReason?.trim() ?? '',
      },
    );
  }

  Future<void> deleteQuestion(String questionId) async {
    await _client.from('questions').delete().eq('id', questionId);
    await _logAdminAction(
      actionType: 'question_deleted',
      targetType: 'question',
      targetId: questionId,
    );
  }

  Future<void> clearSubjectSyllabus(String subjectId) async {
    await _client
        .from('subjects')
        .update({'syllabus_url': null}).eq('id', subjectId);
  }

  Future<void> deleteSyllabusFile({
    required String subjectId,
    required String syllabusUrl,
  }) async {
    final path = _extractStoragePath(syllabusUrl, 'syllabus');
    if (path != null && path.isNotEmpty) {
      await _client.storage.from('syllabus').remove([path]);
    }
    await clearSubjectSyllabus(subjectId);
  }

  Future<void> addPastPaper({
    required String subjectId,
    required String title,
    required String fileUrl,
    int? year,
  }) async {
    final payload = <String, dynamic>{
      'subject_id': subjectId,
      'title': title,
      'file_url': fileUrl,
    };
    if (year != null) {
      payload['year'] = year;
    }
    await _client.from('past_papers').insert(payload);
  }

  Future<void> addQuestion({
    required String chapterId,
    required String prompt,
    int marks = 5,
    String kind = 'important',
    int? year,
  }) async {
    final payload = <String, dynamic>{
      'chapter_id': chapterId,
      'prompt': prompt,
      'marks': marks,
      'kind': kind,
    };
    if (year != null) {
      payload['year'] = year;
    }
    await _client.from('questions').insert(payload);
  }

  Future<BulkUploadResult> uploadQuestionsBatch({
    required String chapterId,
    required List<PlatformFile> files,
    required String kind,
    int marks = 5,
    int? defaultYear,
  }) async {
    var uploaded = 0;
    var skipped = 0;
    final messages = <String>[];

    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        skipped += 1;
        messages.add('Skipped ${file.name} (no data).');
        continue;
      }

      final ext = file.extension?.toLowerCase() ?? '';
      List<_QuestionLine> questions;
      if (ext == 'txt' || ext == 'csv') {
        final content = utf8.decode(bytes, allowMalformed: true);
        questions = _extractQuestionLines(
          content,
          isCsv: ext == 'csv',
        );
      } else {
        final content = _extractTextFromBytes(bytes, ext);
        if (content.trim().isEmpty) {
          skipped += 1;
          messages.add('Skipped ${file.name} (no readable text).');
          continue;
        }
        questions = await _generateQuestionsFromContent(
          content: content,
          kind: kind,
          defaultMarks: marks,
          defaultYear: defaultYear,
        );
        if (questions.isEmpty) {
          questions = _extractQuestionsFromText(content);
        }
      }

      if (questions.isEmpty) {
        skipped += 1;
        messages.add('Skipped ${file.name} (no questions found).');
        continue;
      }

      var fileCount = 0;
      for (final item in questions) {
        if (item.prompt.trim().isEmpty) continue;
        await addQuestion(
          chapterId: chapterId,
          prompt: item.prompt.trim(),
          marks: item.marks ?? marks,
          kind: kind,
          year: item.year ?? defaultYear,
        );
        uploaded += 1;
        fileCount += 1;
      }
      messages.add('Imported $fileCount question(s) from ${file.name}.');
    }

    return BulkUploadResult(
      uploaded: uploaded,
      skipped: skipped,
      messages: messages,
    );
  }

  Future<String> addQuiz({
    required String chapterId,
    required String title,
    String quizType = 'mcq',
    String difficulty = 'easy',
    int durationMinutes = 10,
  }) async {
    final data = await _client
        .from('quizzes')
        .insert({
          'chapter_id': chapterId,
          'title': title,
          'quiz_type': quizType,
          'difficulty': difficulty,
          'duration_minutes': durationMinutes,
          'question_count': 0,
        })
        .select('id')
        .single();
    return data['id']?.toString() ?? '';
  }

  Future<void> addQuizQuestion({
    required String quizId,
    required String prompt,
    required List<String> options,
    int? correctIndex,
    String? explanation,
    String? topic,
  }) async {
    final payload = {
      'quiz_id': quizId,
      'prompt': prompt,
      'options': options,
      'correct_index': correctIndex,
      'explanation': explanation,
      'topic': topic,
    };
    await _client.from('quiz_questions').insert(payload);
    await _refreshQuizQuestionCount(quizId);
  }

  Future<String> ensureGeneralChapter(String subjectId) async {
    final existing = await _client
        .from('chapters')
        .select('id')
        .eq('subject_id', subjectId)
        .eq('title', 'General')
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      return existing['id'].toString();
    }

    final inserted = await _client
        .from('chapters')
        .insert({
          'subject_id': subjectId,
          'title': 'General',
          'summary': 'Auto-generated chapter for subject notes.',
          'sort_order': 0,
        })
        .select('id')
        .single();

    return inserted['id'].toString();
  }

  Future<List<Chapter>> fetchChaptersForSubject(String subjectId) async {
    final data = await _client
        .from('chapters')
        .select('id,title,summary,sort_order')
        .eq('subject_id', subjectId)
        .order('sort_order');

    return (data as List<dynamic>)
        .map((row) => Chapter(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              notes: const [],
              importantQuestions: const [],
              pastQuestions: const [],
              quizzes: const [],
            ))
        .toList();
  }

  Future<List<Quiz>> fetchQuizzesForChapter(String chapterId) async {
    if (chapterId.isEmpty) {
      return [];
    }
    final data = await _client
        .from('quizzes')
        .select('id,title,quiz_type,difficulty,question_count,duration_minutes')
        .eq('chapter_id', chapterId)
        .order('created_at');

    return (data as List<dynamic>)
        .map((row) => Quiz(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? 'Quiz',
              type: parseQuizType(row['quiz_type']?.toString()),
              difficulty: parseQuizDifficulty(row['difficulty']?.toString()),
              questionCount: (row['question_count'] as num?)?.toInt() ?? 0,
              duration: Duration(
                minutes: (row['duration_minutes'] as num?)?.toInt() ?? 10,
              ),
            ))
        .toList();
  }

  Future<void> _refreshQuizQuestionCount(String quizId) async {
    final rows = await _client
        .from('quiz_questions')
        .select('id')
        .eq('quiz_id', quizId);
    final count = (rows as List<dynamic>).length;
    await _client
        .from('quizzes')
        .update({'question_count': count})
        .eq('id', quizId);
  }

  Future<SyllabusBulkResult> uploadSyllabusBatch({
    required Semester semester,
    required List<PlatformFile> files,
  }) async {
    final subjects = semester.subjects;
    if (subjects.isEmpty) {
      return const SyllabusBulkResult(
        uploaded: 0,
        skipped: 0,
        messages: ['No subjects found for the selected semester.'],
      );
    }

    int uploaded = 0;
    int skipped = 0;
    final messages = <String>[];
    final unmatchedFiles = <String>[];
    final ambiguousFiles = <String>[];

    for (final file in files) {
      final match = _matchSubject(file.name, subjects);
      if (match.subject == null) {
        skipped += 1;
        if (match.ambiguous) {
          ambiguousFiles.add(file.name);
          messages.add(match.message ?? 'Skipped ${file.name}: ambiguous match.');
        } else {
          unmatchedFiles.add(file.name);
          messages.add(match.message ?? 'Skipped ${file.name}: no matching subject.');
        }
        continue;
      }
      if (file.bytes == null) {
        skipped += 1;
        messages.add('Skipped ${file.name}: file bytes unavailable.');
        continue;
      }
      final subject = match.subject!;
      final safeCode = subject.code.isNotEmpty ? subject.code : subject.id;
      final path = '$safeCode.pdf';

      await _client.storage.from('syllabus').uploadBinary(
            path,
            file.bytes!,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/pdf',
            ),
          );

      final url = _client.storage.from('syllabus').getPublicUrl(path);
      await _client.from('subjects').update({
        'syllabus_url': url,
      }).eq('id', subject.id);

      uploaded += 1;
      messages.add('Uploaded ${file.name} → ${subject.code}');
    }

    return SyllabusBulkResult(
      uploaded: uploaded,
      skipped: skipped,
      messages: messages,
      unmatchedFiles: unmatchedFiles,
      ambiguousFiles: ambiguousFiles,
    );
  }

  _MatchResult _matchSubject(String filename, List<Subject> subjects) {
    final base = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    final lower = base.toLowerCase();
    final normalizedFile = _normalize(base);

    final matches = <_MatchCandidate>[];

    for (final subject in subjects) {
      final code = subject.code.toLowerCase();
      final normalizedCode = _normalize(code);
      if (code.isNotEmpty && lower.contains(code)) {
        matches.add(_MatchCandidate(subject, 3));
        continue;
      }
      if (normalizedCode.isNotEmpty && normalizedFile.contains(normalizedCode)) {
        matches.add(_MatchCandidate(subject, 2));
        continue;
      }

      final normalizedName = _normalize(subject.name);
      if (normalizedName.isEmpty) continue;
      if (normalizedFile == normalizedName) {
        matches.add(_MatchCandidate(subject, 2));
        continue;
      }
      if (normalizedFile.startsWith(normalizedName)) {
        matches.add(_MatchCandidate(subject, 1));
        continue;
      }
      if (normalizedName.length >= 6 && normalizedFile.contains(normalizedName)) {
        matches.add(_MatchCandidate(subject, 1));
      }
    }

    if (matches.isEmpty) {
      return _MatchResult.none('Skipped $filename: no matching subject.');
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    final bestScore = matches.first.score;
    final bestMatches = matches.where((m) => m.score == bestScore).toList();
    if (bestMatches.length > 1) {
      final labels = bestMatches
          .map((m) => m.subject.code.isNotEmpty ? m.subject.code : m.subject.name)
          .join(', ');
      return _MatchResult.ambiguous(
        'Skipped $filename: matches multiple subjects ($labels).',
      );
    }

    return _MatchResult(bestMatches.first.subject);
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _extractStoragePath(String url, String bucket) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf(bucket);
      if (bucketIndex == -1 || bucketIndex + 1 >= segments.length) {
        return null;
      }
      return segments.sublist(bucketIndex + 1).join('/');
    } catch (_) {
      return null;
    }
  }

  List<String> parseTags(String raw) {
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  Future<String> uploadNoteAttachment({
    required String chapterId,
    required PlatformFile file,
  }) async {
    if (file.bytes == null) {
      throw Exception('File bytes unavailable.');
    }
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final path = '$chapterId/$timestamp-$safeName';
    final contentType = _contentTypeForExtension(file.extension);

    await _client.storage.from('notes').uploadBinary(
          path,
          file.bytes!,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
          ),
        );

    return _client.storage.from('notes').getPublicUrl(path);
  }

  Future<String> uploadPastPaper({
    required String subjectId,
    required PlatformFile file,
  }) async {
    if (file.bytes == null) {
      throw Exception('File bytes unavailable.');
    }
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final path = '$subjectId/$timestamp-$safeName';

    await _client.storage.from('past_papers').uploadBinary(
          path,
          file.bytes!,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'application/pdf',
          ),
        );

    return _client.storage.from('past_papers').getPublicUrl(path);
  }

  String _contentTypeForExtension(String? ext) {
    final lower = ext?.toLowerCase();
    switch (lower) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  String _baseName(String filename) {
    return filename.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
  }

  List<_QuestionLine> _extractQuestionLines(
    String content, {
    required bool isCsv,
  }) {
    final lines = content.split(RegExp(r'\r?\n'));
    final items = <_QuestionLine>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parsed = _parseQuestionLine(line, isCsv: isCsv);
      if (parsed.prompt.trim().isEmpty) continue;
      items.add(parsed);
    }
    return items;
  }

  _QuestionLine _parseQuestionLine(
    String line, {
    required bool isCsv,
  }) {
    List<String> parts;
    if (line.contains('|')) {
      parts = line.split('|');
    } else if (line.contains('\t')) {
      parts = line.split('\t');
    } else if (isCsv && line.contains(',')) {
      parts = line.split(',');
    } else {
      parts = [line];
    }
    final prompt = parts.isNotEmpty ? parts[0].trim() : '';
    final marks = parts.length > 1 ? int.tryParse(parts[1].trim()) : null;
    final year = parts.length > 2 ? int.tryParse(parts[2].trim()) : null;
    return _QuestionLine(prompt: prompt, marks: marks, year: year);
  }

  String _extractTextFromBytes(List<int> bytes, String ext) {
    final lower = ext.toLowerCase();
    if (lower == 'pdf') {
      try {
        final document = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(document).extractText();
        document.dispose();
        return text;
      } catch (_) {
        return '';
      }
    }
    if (lower == 'pptx' || lower == 'ppt') {
      return _extractTextFromPptx(bytes);
    }
    if (lower == 'docx' || lower == 'doc') {
      return _extractTextFromDocx(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _extractTextFromPptx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final buffer = StringBuffer();
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name;
        if (!name.startsWith('ppt/slides/slide') || !name.endsWith('.xml')) {
          continue;
        }
        final content = utf8.decode(file.content as List<int>,
            allowMalformed: true);
        final doc = XmlDocument.parse(content);
        for (final node in doc.descendants.whereType<XmlElement>()) {
          if (node.name.local != 't') continue;
          final text = node.innerText.trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  String _extractTextFromDocx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.firstWhere(
        (file) => file.isFile && file.name == 'word/document.xml',
        orElse: () => ArchiveFile.noCompress('', 0, []),
      );
      if (documentFile.isFile && documentFile.size > 0) {
        final content = utf8.decode(documentFile.content as List<int>,
            allowMalformed: true);
        final doc = XmlDocument.parse(content);
        final buffer = StringBuffer();
        for (final node in doc.descendants.whereType<XmlElement>()) {
          if (node.name.local != 't') continue;
          final text = node.innerText.trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        }
        return buffer.toString();
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<List<_QuestionLine>> _generateQuestionsFromContent({
    required String content,
    required String kind,
    required int defaultMarks,
    int? defaultYear,
  }) async {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.notes).toLowerCase();
    if (!_isSupportedAi(mode)) {
      return [];
    }

    final safeContent = _trim(content.replaceAll(RegExp(r'\s+'), ' '), 3500);
    final systemPrompt =
        'You are a BCA exam question generator. Return ONLY valid JSON.\n'
        'Schema: [{"prompt":"...","marks":5,"year":2024}]\n'
        'Rules: 8-15 questions. Use clear exam-style prompts. '
        'Use marks only if given; otherwise leave it null.';
    final userPrompt =
        'Question type: $kind\n'
        'Default marks: $defaultMarks\n'
        'Default year: ${defaultYear ?? ''}\n'
        'Notes:\n$safeContent';

    final raw = await _sendChat(
      mode: mode,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    if (raw.trim().isEmpty) return [];

    final jsonText = _extractJson(raw);
    final decoded = jsonDecode(jsonText);
    final list = decoded is Map<String, dynamic>
        ? (decoded['questions'] as List<dynamic>? ?? [])
        : decoded as List<dynamic>;
    if (list.isEmpty) return [];

    final items = <_QuestionLine>[];
    for (final entry in list) {
      if (entry is! Map<String, dynamic>) continue;
      final prompt = entry['prompt']?.toString().trim() ?? '';
      if (prompt.isEmpty) continue;
      final marks = _parseInt(entry['marks']) ?? defaultMarks;
      final year = _parseInt(entry['year']) ?? defaultYear;
      items.add(_QuestionLine(prompt: prompt, marks: marks, year: year));
    }
    return items;
  }

  List<_QuestionLine> _extractQuestionsFromText(String content) {
    var candidates = content
        .split(RegExp(r'[\n\r]+'))
        .map((line) => line.trim())
        .where((line) => line.length > 20)
        .toList();
    if (candidates.isEmpty) {
      candidates = content
          .split(RegExp(r'(?<=[.!?])\\s+'))
          .map((line) => line.trim())
          .where((line) => line.length > 25)
          .toList();
    }
    if (candidates.isEmpty) {
      return [];
    }
    return candidates.take(20).map((line) {
      final prompt = line.endsWith('?') ? line : 'Explain: $line';
      return _QuestionLine(prompt: prompt, marks: null, year: null);
    }).toList();
  }

  bool _isSupportedAi(String mode) {
    final normalized = mode.toLowerCase();
    return normalized == 'ollama' ||
        normalized == 'lmstudio' ||
        normalized == 'lm-studio' ||
        normalized == 'lm_studio' ||
        normalized == 'backend' ||
        normalized == 'openrouter' ||
        normalized == 'groq' ||
        normalized == 'gemini' ||
        normalized == 'cloud' ||
        normalized == 'auto';
  }

  Future<String> _sendChat({
    required String mode,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    return _aiRouter.send(
      AiRequest(
        feature: AiFeature.notes,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        expectsJson: true,
      ),
    );
  }

  String _extractJson(String text) {
    final fenceStart = text.indexOf('```');
    if (fenceStart != -1) {
      final fenceEnd = text.indexOf('```', fenceStart + 3);
      if (fenceEnd != -1) {
        var fenced = text.substring(fenceStart + 3, fenceEnd).trim();
        if (fenced.toLowerCase().startsWith('json')) {
          fenced = fenced.substring(4).trim();
        }
        if (fenced.isNotEmpty) {
          return fenced;
        }
      }
    }
    final listStart = text.indexOf('[');
    final listEnd = text.lastIndexOf(']');
    if (listStart != -1 && listEnd != -1 && listEnd > listStart) {
      return text.substring(listStart, listEnd + 1);
    }
    final braceStart = text.indexOf('{');
    final braceEnd = text.lastIndexOf('}');
    if (braceStart != -1 && braceEnd != -1 && braceEnd > braceStart) {
      return text.substring(braceStart, braceEnd + 1);
    }
    return text;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _trim(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  Future<Map<String, _AdminProfileStub>> _fetchProfileLookup(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('profiles')
        .select('id,full_name,email,college_name')
        .inFilter('id', ids.toList());
    final map = <String, _AdminProfileStub>{};
    for (final row in rows as List<dynamic>) {
      final item = _adminProfileStubFromMap(row as Map<String, dynamic>);
      map[item.id] = item;
    }
    return map;
  }

  Future<Map<String, String>> _fetchSubjectLookup(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('subjects')
        .select('id,name')
        .inFilter('id', ids.toList());
    return {
      for (final row in rows as List<dynamic>)
        row['id']?.toString() ?? '': row['name']?.toString() ?? 'Subject',
    }..remove('');
  }

  Future<Map<String, String>> _fetchChapterLookup(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('chapters')
        .select('id,title')
        .inFilter('id', ids.toList());
    return {
      for (final row in rows as List<dynamic>)
        row['id']?.toString() ?? '': row['title']?.toString() ?? 'Chapter',
    }..remove('');
  }

  Future<Map<String, Map<String, dynamic>>> _fetchSemesterLookup(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('semesters')
        .select('id,name,code')
        .inFilter('id', ids.toList());
    return {
      for (final row in rows as List<dynamic>)
        row['id']?.toString() ?? '': row as Map<String, dynamic>,
    }..remove('');
  }

  Future<void> _logAdminAction({
    required String actionType,
    String? targetType,
    String? targetId,
    String? targetUserId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _client.rpc(
        'log_admin_action',
        params: {
          'p_action_type': actionType,
          'p_target_type': targetType,
          'p_target_id': targetId,
          'p_target_user_id': targetUserId,
          'p_details': details ?? <String, dynamic>{},
        },
      );
    } catch (_) {}
  }

  String _escapeIlike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_')
        .replaceAll(',', r'\,');
  }
}

class _QuestionLine {
  final String prompt;
  final int? marks;
  final int? year;

  const _QuestionLine({
    required this.prompt,
    this.marks,
    this.year,
  });
}

class AdminNote {
  final String id;
  final String chapterId;
  final String title;
  final String shortAnswer;
  final String detailedAnswer;
  final List<String> tags;
  final String? fileUrl;

  const AdminNote({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.shortAnswer,
    required this.detailedAnswer,
    required this.tags,
    this.fileUrl,
  });
}

class AdminManagedUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String collegeName;
  final String semesterId;
  final String semesterName;
  final bool isAdmin;
  final bool isBlocked;
  final String blockedReason;
  final DateTime? blockedAt;

  const AdminManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.collegeName,
    required this.semesterId,
    required this.semesterName,
    required this.isAdmin,
    required this.isBlocked,
    required this.blockedReason,
    this.blockedAt,
  });
}

class AdminActivityEntry {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String activityType;
  final String source;
  final int points;
  final String subjectName;
  final String chapterTitle;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const AdminActivityEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.activityType,
    required this.source,
    required this.points,
    required this.subjectName,
    required this.chapterTitle,
    required this.metadata,
    this.createdAt,
  });
}

class AdminAuditEntry {
  final String id;
  final String actorId;
  final String actorName;
  final String actorEmail;
  final String actionType;
  final String targetType;
  final String targetId;
  final String targetUserId;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  const AdminAuditEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actorEmail,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.targetUserId,
    required this.details,
    this.createdAt,
  });
}

class AdminContentReport {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reporterEmail;
  final String reporterCollegeName;
  final String targetType;
  final String targetId;
  final String targetOwnerId;
  final String targetTitle;
  final String targetPreview;
  final String reason;
  final String details;
  final String status;
  final String reviewedBy;
  final String reviewerName;
  final String reviewNote;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const AdminContentReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reporterEmail,
    required this.reporterCollegeName,
    required this.targetType,
    required this.targetId,
    required this.targetOwnerId,
    required this.targetTitle,
    required this.targetPreview,
    required this.reason,
    required this.details,
    required this.status,
    required this.reviewedBy,
    required this.reviewerName,
    required this.reviewNote,
    this.createdAt,
    this.reviewedAt,
  });
}

class _AdminProfileStub {
  final String id;
  final String fullName;
  final String email;
  final String collegeName;

  const _AdminProfileStub({
    required this.id,
    required this.fullName,
    required this.email,
    required this.collegeName,
  });
}

class AdminNoteSubmission {
  final String id;
  final String chapterId;
  final String title;
  final String shortAnswer;
  final String detailedAnswer;
  final List<String> tags;
  final String status;
  final String? fileUrl;
  final String userId;
  final String? userName;
  final String? collegeName;
  final String chapterTitle;
  final String? subjectName;
  final DateTime? createdAt;

  const AdminNoteSubmission({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.shortAnswer,
    required this.detailedAnswer,
    required this.tags,
    required this.status,
    this.fileUrl,
    required this.userId,
    this.userName,
    this.collegeName,
    required this.chapterTitle,
    this.subjectName,
    this.createdAt,
  });
}

class AdminCommunityQuestion {
  final String id;
  final String question;
  final String subjectId;
  final String subjectName;
  final String userId;
  final String status;
  final String? aiReason;
  final DateTime? createdAt;

  const AdminCommunityQuestion({
    required this.id,
    required this.question,
    required this.subjectId,
    required this.subjectName,
    required this.userId,
    required this.status,
    this.aiReason,
    this.createdAt,
  });
}

AdminNote _adminNoteFromMap(Map<String, dynamic> map) {
  final tags = (map['tags'] as List<dynamic>? ?? [])
      .map((tag) => tag.toString())
      .where((tag) => tag.isNotEmpty)
      .toList();
  return AdminNote(
    id: map['id']?.toString() ?? '',
    chapterId: map['chapter_id']?.toString() ?? '',
    title: map['title']?.toString() ?? 'Note',
    shortAnswer: map['short_answer']?.toString() ?? '',
    detailedAnswer: map['detailed_answer']?.toString() ?? '',
    tags: tags,
    fileUrl: map['file_url']?.toString(),
  );
}

_AdminProfileStub _adminProfileStubFromMap(Map<String, dynamic> map) {
  return _AdminProfileStub(
    id: map['id']?.toString() ?? '',
    fullName: map['full_name']?.toString() ?? 'Student',
    email: map['email']?.toString() ?? '',
    collegeName: map['college_name']?.toString() ?? '',
  );
}

AdminManagedUser _adminManagedUserFromMap(
  Map<String, dynamic> map, [
  Map<String, Map<String, dynamic>> semesterLookup = const {},
]) {
  final semesterId = map['semester_id']?.toString() ?? '';
  final semesterMap = semesterLookup[semesterId];
  final blockedAtRaw = map['blocked_at']?.toString();
  return AdminManagedUser(
    id: map['id']?.toString() ?? '',
    name: map['full_name']?.toString() ?? 'Student',
    email: map['email']?.toString() ?? '',
    phone: map['phone']?.toString() ?? '',
    collegeName: map['college_name']?.toString() ?? '',
    semesterId: semesterId,
    semesterName: semesterMap?['name']?.toString() ?? '',
    isAdmin: map['is_admin'] as bool? ?? false,
    isBlocked: map['is_blocked'] as bool? ?? false,
    blockedReason: map['blocked_reason']?.toString() ?? '',
    blockedAt: blockedAtRaw == null ? null : DateTime.tryParse(blockedAtRaw),
  );
}

AdminNoteSubmission _adminSubmissionFromMap(Map<String, dynamic> map) {
  final tags = (map['tags'] as List<dynamic>? ?? [])
      .map((tag) => tag.toString())
      .where((tag) => tag.isNotEmpty)
      .toList();
  final chapterMap = map['chapter'] as Map<String, dynamic>?;
  final subjectMap = chapterMap?['subject'] as Map<String, dynamic>?;
  final userMap = map['user'];
  final createdAtRaw = map['created_at']?.toString();
  return AdminNoteSubmission(
    id: map['id']?.toString() ?? '',
    chapterId: map['chapter_id']?.toString() ?? '',
    title: map['title']?.toString() ?? 'Note',
    shortAnswer: map['short_answer']?.toString() ?? '',
    detailedAnswer: map['detailed_answer']?.toString() ?? '',
    tags: tags,
    status: map['status']?.toString() ?? 'pending',
    fileUrl: map['file_url']?.toString(),
    userId: map['user_id']?.toString() ?? '',
    userName: userMap is Map<String, dynamic>
        ? userMap['full_name']?.toString()
        : null,
    collegeName: userMap is Map<String, dynamic>
        ? userMap['college_name']?.toString()
        : null,
    chapterTitle: chapterMap?['title']?.toString() ?? 'Chapter',
    subjectName: subjectMap?['name']?.toString(),
    createdAt:
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
  );
}

AdminCommunityQuestion _adminCommunityQuestionFromMap(
  Map<String, dynamic> map,
) {
  final subjectMap = map['subject'] as Map<String, dynamic>?;
  final createdAtRaw = map['created_at']?.toString();
  return AdminCommunityQuestion(
    id: map['id']?.toString() ?? '',
    question: map['question']?.toString() ?? '',
    subjectId: map['subject_id']?.toString() ?? '',
    subjectName: subjectMap?['name']?.toString() ?? 'Subject',
    userId: map['user_id']?.toString() ?? '',
    status: map['status']?.toString() ?? 'pending',
    aiReason: map['ai_reason']?.toString(),
    createdAt:
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
  );
}

AdminActivityEntry _adminActivityEntryFromMap(
  Map<String, dynamic> map, {
  required Map<String, _AdminProfileStub> profileLookup,
  required Map<String, String> subjectLookup,
  required Map<String, String> chapterLookup,
}) {
  final userId = map['user_id']?.toString() ?? '';
  final subjectId = map['subject_id']?.toString() ?? '';
  final chapterId = map['chapter_id']?.toString() ?? '';
  final profile = profileLookup[userId];
  final metadata = map['metadata'];
  final createdAtRaw = map['created_at']?.toString();
  return AdminActivityEntry(
    id: map['id']?.toString() ?? '',
    userId: userId,
    userName: profile?.fullName ?? 'Student',
    userEmail: profile?.email ?? '',
    activityType: map['activity_type']?.toString() ?? '',
    source: map['source']?.toString() ?? '',
    points: (map['points'] as num?)?.toInt() ?? 0,
    subjectName: subjectLookup[subjectId] ?? '',
    chapterTitle: chapterLookup[chapterId] ?? '',
    metadata: metadata is Map<String, dynamic>
        ? metadata
        : Map<String, dynamic>.from(metadata as Map? ?? const {}),
    createdAt:
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
  );
}

AdminActivityEntry _adminActivityEntryFromFeedMap(Map<String, dynamic> map) {
  final metadata = map['metadata'];
  final createdAtRaw = map['created_at']?.toString();
  return AdminActivityEntry(
    id: map['id']?.toString() ?? '',
    userId: map['user_id']?.toString() ?? '',
    userName: map['user_name']?.toString() ?? 'Student',
    userEmail: map['user_email']?.toString() ?? '',
    activityType: map['activity_type']?.toString() ?? '',
    source: map['source']?.toString() ?? '',
    points: (map['points'] as num?)?.toInt() ?? 0,
    subjectName: map['subject_name']?.toString() ?? '',
    chapterTitle: map['chapter_title']?.toString() ?? '',
    metadata: metadata is Map<String, dynamic>
        ? metadata
        : Map<String, dynamic>.from(metadata as Map? ?? const {}),
    createdAt:
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
  );
}

AdminAuditEntry _adminAuditEntryFromMap(
  Map<String, dynamic> map, {
  required Map<String, _AdminProfileStub> profileLookup,
}) {
  final actorId = map['actor_id']?.toString() ?? '';
  final actor = profileLookup[actorId];
  final details = map['details'];
  final createdAtRaw = map['created_at']?.toString();
  return AdminAuditEntry(
    id: map['id']?.toString() ?? '',
    actorId: actorId,
    actorName: actor?.fullName ?? 'Admin',
    actorEmail: actor?.email ?? '',
    actionType: map['action_type']?.toString() ?? '',
    targetType: map['target_type']?.toString() ?? '',
    targetId: map['target_id']?.toString() ?? '',
    targetUserId: map['target_user_id']?.toString() ?? '',
    details: details is Map<String, dynamic>
        ? details
        : Map<String, dynamic>.from(details as Map? ?? const {}),
    createdAt:
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
  );
}

AdminAuditEntry _adminAuditEntryFromFeedMap(Map<String, dynamic> map) {
  final details = map['details'];
  final createdAtRaw = map['created_at']?.toString();
  return AdminAuditEntry(
    id: map['id']?.toString() ?? '',
    actorId: map['actor_id']?.toString() ?? '',
    actorName: map['actor_name']?.toString() ?? 'Admin',
    actorEmail: map['actor_email']?.toString() ?? '',
    actionType: map['action_type']?.toString() ?? '',
    targetType: map['target_type']?.toString() ?? '',
    targetId: map['target_id']?.toString() ?? '',
    targetUserId: map['target_user_id']?.toString() ?? '',
    details: details is Map<String, dynamic>
        ? details
        : Map<String, dynamic>.from(details as Map? ?? const {}),
    createdAt:
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
  );
}

AdminContentReport _adminContentReportFromMap(
  Map<String, dynamic> map, {
  required Map<String, _AdminProfileStub> profileLookup,
}) {
  final reporterId = map['reporter_id']?.toString() ?? '';
  final reviewedBy = map['reviewed_by']?.toString() ?? '';
  final reporter = profileLookup[reporterId];
  final reviewer = profileLookup[reviewedBy];
  final createdAtRaw = map['created_at']?.toString();
  final reviewedAtRaw = map['reviewed_at']?.toString();
  return AdminContentReport(
    id: map['id']?.toString() ?? '',
    reporterId: reporterId,
    reporterName: reporter?.fullName ?? 'Student',
    reporterEmail: reporter?.email ?? '',
    reporterCollegeName: reporter?.collegeName ?? '',
    targetType: map['target_type']?.toString() ?? '',
    targetId: map['target_id']?.toString() ?? '',
    targetOwnerId: map['target_owner_id']?.toString() ?? '',
    targetTitle: map['target_title']?.toString() ?? '',
    targetPreview: map['target_preview']?.toString() ?? '',
    reason: map['reason']?.toString() ?? '',
    details: map['details']?.toString() ?? '',
    status: map['status']?.toString() ?? 'pending',
    reviewedBy: reviewedBy,
    reviewerName: reviewer?.fullName ?? '',
    reviewNote: map['review_note']?.toString() ?? '',
    createdAt:
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
    reviewedAt:
        reviewedAtRaw == null ? null : DateTime.tryParse(reviewedAtRaw),
  );
}

List<AdminActivityEntry> _filterActivityEntries(
  List<AdminActivityEntry> entries, {
  String search = '',
  String? activityType,
}) {
  final trimmed = search.trim().toLowerCase();
  return entries.where((entry) {
    if (activityType != null &&
        activityType.isNotEmpty &&
        entry.activityType != activityType) {
      return false;
    }
    if (trimmed.isEmpty) {
      return true;
    }
    final haystack = [
      entry.userName,
      entry.userEmail,
      entry.activityType,
      entry.source,
      entry.subjectName,
      entry.chapterTitle,
      ...entry.metadata.entries.map((item) => '${item.key} ${item.value}'),
    ].join(' ').toLowerCase();
    return haystack.contains(trimmed);
  }).toList();
}

List<AdminAuditEntry> _filterAuditEntries(
  List<AdminAuditEntry> entries, {
  String search = '',
  String? actionType,
}) {
  final trimmed = search.trim().toLowerCase();
  return entries.where((entry) {
    if (actionType != null &&
        actionType.isNotEmpty &&
        entry.actionType != actionType) {
      return false;
    }
    if (trimmed.isEmpty) {
      return true;
    }
    final haystack = [
      entry.actorName,
      entry.actorEmail,
      entry.actionType,
      entry.targetType,
      entry.targetId,
      ...entry.details.entries.map((item) => '${item.key} ${item.value}'),
    ].join(' ').toLowerCase();
    return haystack.contains(trimmed);
  }).toList();
}

class _MatchCandidate {
  final Subject subject;
  final int score;

  const _MatchCandidate(this.subject, this.score);
}

class _MatchResult {
  final Subject? subject;
  final bool ambiguous;
  final String? message;

  const _MatchResult(this.subject)
      : ambiguous = false,
        message = null;

  const _MatchResult.none(this.message) : subject = null, ambiguous = false;

  const _MatchResult.ambiguous(this.message)
      : subject = null,
        ambiguous = true;
}
