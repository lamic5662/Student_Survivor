import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class AdminService {
  final SupabaseClient _client;

  AdminService(this._client);

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

  Future<void> addChapter({
    required String subjectId,
    required String title,
    String? summary,
    int sortOrder = 0,
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
  }

  Future<List<AdminNoteSubmission>> fetchPendingNoteSubmissions({
    String? chapterId,
  }) async {
    final baseQuery = _client
        .from('note_submissions')
        .select(
          'id,user_id,chapter_id,title,short_answer,detailed_answer,tags,status,created_at,'
          'chapter:chapters(id,title,subject:subjects(id,name))',
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
    });

    final adminId = _client.auth.currentUser?.id;
    await _client.from('note_submissions').update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': adminId,
    }).eq('id', submission.id);
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
  }

  Future<void> deleteNoteSubmission(String submissionId) async {
    await _client.from('note_submissions').delete().eq('id', submissionId);
  }

  Future<void> deleteQuestion(String questionId) async {
    await _client.from('questions').delete().eq('id', questionId);
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

class AdminNoteSubmission {
  final String id;
  final String chapterId;
  final String title;
  final String shortAnswer;
  final String detailedAnswer;
  final List<String> tags;
  final String status;
  final String userId;
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
    required this.userId,
    required this.chapterTitle,
    this.subjectName,
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

AdminNoteSubmission _adminSubmissionFromMap(Map<String, dynamic> map) {
  final tags = (map['tags'] as List<dynamic>? ?? [])
      .map((tag) => tag.toString())
      .where((tag) => tag.isNotEmpty)
      .toList();
  final chapterMap = map['chapter'] as Map<String, dynamic>?;
  final subjectMap = chapterMap?['subject'] as Map<String, dynamic>?;
  final createdAtRaw = map['created_at']?.toString();
  return AdminNoteSubmission(
    id: map['id']?.toString() ?? '',
    chapterId: map['chapter_id']?.toString() ?? '',
    title: map['title']?.toString() ?? 'Note',
    shortAnswer: map['short_answer']?.toString() ?? '',
    detailedAnswer: map['detailed_answer']?.toString() ?? '',
    tags: tags,
    status: map['status']?.toString() ?? 'pending',
    userId: map['user_id']?.toString() ?? '',
    chapterTitle: chapterMap?['title']?.toString() ?? 'Chapter',
    subjectName: subjectMap?['name']?.toString(),
    createdAt:
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
  );
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
