import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class NoteSubmissionService {
  final SupabaseClient _client;

  NoteSubmissionService(this._client);

  Future<void> submitNote({
    required String chapterId,
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    String? fileUrl,
    List<String> tags = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated.');
    }
    final payload = <String, dynamic>{
      'user_id': user.id,
      'chapter_id': chapterId,
      'title': title,
      'short_answer': shortAnswer,
      'detailed_answer': detailedAnswer,
      'tags': tags,
      'status': 'pending',
    };
    if (fileUrl != null && fileUrl.isNotEmpty) {
      payload['file_url'] = fileUrl;
    }
    await _client.from('note_submissions').insert(payload);
  }

  Future<List<NoteSubmission>> fetchMySubmissions(String chapterId) async {
    final user = _client.auth.currentUser;
    if (user == null || chapterId.isEmpty) {
      return [];
    }
    final data = await _client
        .from('note_submissions')
        .select(
          'id,chapter_id,title,short_answer,detailed_answer,file_url,tags,status,admin_feedback,created_at,'
          'user:profiles(full_name,college_name)',
        )
        .eq('user_id', user.id)
        .eq('chapter_id', chapterId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((row) => _submissionFromMap(row as Map<String, dynamic>))
        .toList();
  }

  NoteSubmission _submissionFromMap(Map<String, dynamic> map) {
    final tags = (map['tags'] as List<dynamic>? ?? [])
        .map((tag) => tag.toString())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final createdAt = map['created_at']?.toString();
    final user = map['user'];
    return NoteSubmission(
      id: map['id']?.toString() ?? '',
      chapterId: map['chapter_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Note',
      shortAnswer: map['short_answer']?.toString() ?? '',
      detailedAnswer: map['detailed_answer']?.toString() ?? '',
      tags: tags,
      status: map['status']?.toString() ?? 'pending',
      fileUrl: map['file_url']?.toString(),
      adminFeedback: map['admin_feedback']?.toString(),
      userName: user is Map<String, dynamic>
          ? user['full_name']?.toString()
          : null,
      collegeName: user is Map<String, dynamic>
          ? user['college_name']?.toString()
          : null,
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt),
    );
  }

  Future<String> uploadSubmissionAttachment({
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

    await _client.storage.from('note_submissions').uploadBinary(
          path,
          file.bytes!,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
          ),
        );

    return _client.storage.from('note_submissions').getPublicUrl(path);
  }

  Future<void> deleteSubmission(String submissionId) async {
    await _client.from('note_submissions').delete().eq('id', submissionId);
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
