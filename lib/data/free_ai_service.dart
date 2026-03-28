import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/search_service.dart';
import 'package:student_survivor/models/app_models.dart';

class FreeAiService {
  final SupabaseClient _client;
  final SearchService _searchService;

  FreeAiService(this._client) : _searchService = SearchService(_client);

  Future<String> answer(String message, {String? mode}) async {
    final lower = message.toLowerCase();
    if (_isGreeting(lower)) {
      return 'Hi! Ask me about a topic, e.g., "OSI model" or "TCP vs UDP".';
    }

    if (lower.contains('weak') || lower.contains('recommend')) {
      final rec = await _weakTopicsAndNotes();
      if (rec.isNotEmpty) {
        return rec;
      }
    }

    if (_isExamMode(mode, lower)) {
      return await _importantQuestions(message);
    }

    final query = _stripModeKeywords(message);
    if (query.isEmpty || query.length < 3) {
      return 'Tell me a topic or question.';
    }

    final hits = await _searchService.searchHits(query);
    if (hits.isEmpty) {
      return 'I could not find matching notes. Try another keyword.';
    }

    final noteHit = hits.firstWhere(
      (hit) => hit.type == 'note',
      orElse: () => hits.first,
    );

    if (noteHit.type == 'note') {
      final note = await _fetchNote(noteHit.id);
      if (note != null) {
        return _renderNote(note, mode, lower);
      }
    }

    if (noteHit.type == 'chapter') {
      final notes = await _fetchNotesForChapter(noteHit.id);
      if (notes.isNotEmpty) {
        return _renderNote(notes.first, mode, lower);
      }
    }

    return noteHit.snippet.isNotEmpty
        ? noteHit.snippet
        : 'Try searching with another keyword.';
  }

  bool _isGreeting(String text) {
    final cleaned = text.trim();
    return cleaned == 'hi' ||
        cleaned == 'hello' ||
        cleaned == 'hey' ||
        cleaned == 'hi!' ||
        cleaned == 'hello!' ||
        cleaned == 'hey!';
  }

  bool _isExamMode(String? mode, String lower) {
    final text = mode?.toLowerCase() ?? '';
    return text.contains('exam') ||
        text.contains('important') ||
        lower.contains('important question') ||
        lower.contains('exam');
  }

  String _stripModeKeywords(String message) {
    var trimmed = message.trim();
    trimmed = trimmed.replaceFirst(
      RegExp(
        r'^(short answer|long answer|explain in simple language|suggest exam questions|short|long|simple|exam)\s*:?',
        caseSensitive: false,
      ),
      '',
    );
    return trimmed.trim();
  }

  String _renderNote(Note note, String? mode, String lower) {
    final normalized = (mode ?? lower).toLowerCase();
    if (normalized.contains('long') || normalized.contains('10')) {
      return note.detailedAnswer.isNotEmpty
          ? note.detailedAnswer
          : note.shortAnswer;
    }
    if (normalized.contains('simple')) {
      return note.shortAnswer.isNotEmpty ? note.shortAnswer : note.detailedAnswer;
    }
    if (normalized.contains('short') || normalized.contains('5')) {
      return note.shortAnswer.isNotEmpty ? note.shortAnswer : note.detailedAnswer;
    }
    return note.shortAnswer.isNotEmpty ? note.shortAnswer : note.detailedAnswer;
  }

  Future<Note?> _fetchNote(String id) async {
    if (id.isEmpty) return null;
    final data = await _client
        .from('notes')
        .select('id,title,short_answer,detailed_answer,file_url')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Note(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      shortAnswer: data['short_answer']?.toString() ?? '',
      detailedAnswer: data['detailed_answer']?.toString() ?? '',
      fileUrl: data['file_url']?.toString(),
    );
  }

  Future<List<Note>> _fetchNotesForChapter(String chapterId) async {
    if (chapterId.isEmpty) return [];
    final rows = await _client
        .from('notes')
        .select('id,title,short_answer,detailed_answer,file_url')
        .eq('chapter_id', chapterId)
        .limit(3);
    return (rows as List<dynamic>)
        .map(
          (row) => Note(
            id: row['id']?.toString() ?? '',
            title: row['title']?.toString() ?? '',
            shortAnswer: row['short_answer']?.toString() ?? '',
            detailedAnswer: row['detailed_answer']?.toString() ?? '',
            fileUrl: row['file_url']?.toString(),
          ),
        )
        .toList();
  }

  Future<String> _importantQuestions(String query) async {
    final cleaned = _stripModeKeywords(query);
    if (cleaned.isEmpty) {
      return 'Tell me a topic to list important questions.';
    }
    final rows = await _client
        .from('questions')
        .select('prompt,marks')
        .ilike('prompt', '%$cleaned%')
        .eq('kind', 'important')
        .limit(5);
    final questions = (rows as List<dynamic>)
        .map((row) => row['prompt']?.toString() ?? '')
        .where((prompt) => prompt.isNotEmpty)
        .toList();
    if (questions.isEmpty) {
      return 'No important questions found. Try another topic.';
    }
    final buffer = StringBuffer('Important questions:\\n');
    for (final q in questions) {
      buffer.writeln('- $q');
    }
    return buffer.toString().trim();
  }

  Future<String> _weakTopicsAndNotes() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return '';
    }
    final weak = await _client
        .from('weak_topics')
        .select('topic, reason')
        .order('severity', ascending: false)
        .limit(5);
    final topics = (weak as List<dynamic>)
        .map((row) => row['topic']?.toString() ?? '')
        .where((topic) => topic.isNotEmpty)
        .toList();

    final recs = await _client
        .from('recommendations')
        .select('note:notes(title)')
        .order('created_at', ascending: false)
        .limit(5);
    final notes = (recs as List<dynamic>)
        .map((row) => row['note']?['title']?.toString() ?? '')
        .where((title) => title.isNotEmpty)
        .toList();

    if (topics.isEmpty && notes.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    if (topics.isNotEmpty) {
      buffer.writeln('Weak topics: ${topics.join(', ')}.');
    }
    if (notes.isNotEmpty) {
      buffer.writeln('Recommended notes: ${notes.join(', ')}.');
    }
    return buffer.toString().trim();
  }
}
