import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class RevisionQueueService {
  final SupabaseClient _client;

  RevisionQueueService(this._client);

  Future<List<RevisionItem>> fetchQueue({
    required List<Subject> subjects,
    int limit = 8,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final index = _SubjectIndex(subjects);
    final suggestions = await _buildSuggestions(index);
    await _seedQueue(user.id, suggestions);

    final upcoming = DateTime.now().add(const Duration(days: 7));
    final rows = await _client
        .from('revision_items')
        .select(
          'item_key,item_type,priority,title,detail,'
          'due_at,subject_id,chapter_id,note_id,question_id',
        )
        .eq('user_id', user.id)
        .lte('due_at', upcoming.toIso8601String())
        .order('due_at', ascending: true)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((row) => _itemFromRow(row as Map<String, dynamic>, index))
        .toList();
  }

  Future<void> markReviewed({
    required RevisionItem item,
    bool success = true,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final row = await _client
        .from('revision_items')
        .select('interval_days,ease_factor,success_count')
        .eq('user_id', user.id)
        .eq('item_key', item.id)
        .maybeSingle();
    if (row == null) return;

    var interval = (row['interval_days'] as num?)?.toInt() ?? 1;
    var ease = (row['ease_factor'] as num?)?.toDouble() ?? 2.2;
    var successCount = (row['success_count'] as num?)?.toInt() ?? 0;

    if (success) {
      successCount += 1;
      ease = (ease + 0.1).clamp(1.3, 2.8);
      interval = (interval * ease).round().clamp(1, 30);
    } else {
      successCount = 0;
      ease = (ease - 0.2).clamp(1.3, 2.8);
      interval = 1;
    }

    final nextDue = DateTime.now().add(Duration(days: interval));
    await _client
        .from('revision_items')
        .update({
          'due_at': nextDue.toIso8601String(),
          'interval_days': interval,
          'ease_factor': ease,
          'success_count': successCount,
          'last_reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id)
        .eq('item_key', item.id);
  }

  Future<List<_RevisionSeed>> _buildSuggestions(_SubjectIndex index) async {
    final items = <_RevisionSeed>[];
    final seen = <String>{};

    final weakRows = await _client
        .from('weak_topics')
        .select('id,topic,reason,severity,last_seen_at,chapter_id')
        .order('severity', ascending: false)
        .order('last_seen_at', ascending: false)
        .limit(6);

    for (final raw in (weakRows as List<dynamic>)) {
      final map = raw as Map<String, dynamic>;
      final topic = map['topic']?.toString() ?? '';
      if (topic.isEmpty) continue;
      final chapterId = map['chapter_id']?.toString();
      final chapter = chapterId != null ? index.chapterById[chapterId] : null;
      final subject = chapterId != null ? index.subjectByChapter[chapterId] : null;
      final severity = (map['severity'] as num?)?.toInt() ?? 1;
      final lastSeen = _parseDate(map['last_seen_at']);
      final dueAt = _nextDueDate(lastSeen, severity);
      final item = RevisionItem(
        id: '',
        type: RevisionItemType.topic,
        priority: _priorityForSeverity(severity),
        title: topic,
        detail: map['reason']?.toString() ?? 'Needs revision',
        dueAt: dueAt,
        subject: subject,
        chapter: chapter,
      );
      final key = _itemKey(item);
      if (seen.contains(key)) continue;
      seen.add(key);
      items.add(_RevisionSeed(item: item, itemKey: key));
    }

    final progressRows = await _client
        .from('user_chapter_progress')
        .select('chapter_id, completion_percent, last_activity_at')
        .order('completion_percent', ascending: true)
        .limit(4);

    final focusChapterIds = <String>{};
    for (final raw in (progressRows as List<dynamic>)) {
      final map = raw as Map<String, dynamic>;
      final chapterId = map['chapter_id']?.toString();
      if (chapterId == null || chapterId.isEmpty) continue;
      final chapter = index.chapterById[chapterId];
      if (chapter == null) continue;
      final subject = index.subjectByChapter[chapterId];
      final completion =
          (map['completion_percent'] as num?)?.toDouble() ?? 0.0;
      if (completion >= 75) continue;
      final lastActivity = _parseDate(map['last_activity_at']);
      final dueAt = _nextDueForCompletion(lastActivity, completion);
      final item = RevisionItem(
        id: '',
        type: RevisionItemType.chapter,
        priority: _priorityForCompletion(completion),
        title: chapter.title,
        detail: 'Progress ${(completion).round()}%',
        dueAt: dueAt,
        subject: subject,
        chapter: chapter,
      );
      final key = _itemKey(item);
      if (seen.contains(key)) continue;
      seen.add(key);
      focusChapterIds.add(chapterId);
      items.add(_RevisionSeed(item: item, itemKey: key));
    }

    for (final raw in weakRows as List<dynamic>) {
      final chapterId =
          (raw as Map<String, dynamic>)['chapter_id']?.toString();
      if (chapterId != null && chapterId.isNotEmpty) {
        focusChapterIds.add(chapterId);
      }
    }

    if (focusChapterIds.isNotEmpty) {
      final questionRows = await _client
          .from('questions')
          .select('id,prompt,marks,kind,year,chapter_id')
          .inFilter('chapter_id', focusChapterIds.toList())
          .eq('kind', 'important')
          .order('created_at', ascending: false)
          .limit(3);
      for (final raw in (questionRows as List<dynamic>)) {
        final map = raw as Map<String, dynamic>;
        final prompt = map['prompt']?.toString() ?? '';
        if (prompt.isEmpty) continue;
        final chapterId = map['chapter_id']?.toString();
        final chapter = chapterId != null ? index.chapterById[chapterId] : null;
        final subject = chapterId != null ? index.subjectByChapter[chapterId] : null;
        final question = Question(
          id: map['id']?.toString() ?? '',
          prompt: prompt,
          marks: (map['marks'] as num?)?.toInt() ?? 5,
          kind: map['kind']?.toString() ?? 'important',
          year: (map['year'] as num?)?.toInt(),
        );
        final item = RevisionItem(
          id: '',
          type: RevisionItemType.question,
          priority: RevisionPriority.medium,
          title: 'Important question',
          detail: question.prompt,
          dueAt: DateTime.now(),
          subject: subject,
          chapter: chapter,
          question: question,
        );
        final key = _itemKey(item);
        if (seen.contains(key)) continue;
        seen.add(key);
        items.add(_RevisionSeed(item: item, itemKey: key));
      }

      final noteRows = await _client
          .from('notes')
          .select('id,title,short_answer,detailed_answer,file_url,chapter_id')
          .inFilter('chapter_id', focusChapterIds.toList())
          .order('created_at', ascending: false)
          .limit(3);
      for (final raw in (noteRows as List<dynamic>)) {
        final map = raw as Map<String, dynamic>;
        final note = Note(
          id: map['id']?.toString() ?? '',
          title: map['title']?.toString() ?? '',
          shortAnswer: map['short_answer']?.toString() ?? '',
          detailedAnswer: map['detailed_answer']?.toString() ?? '',
          fileUrl: map['file_url']?.toString(),
        );
        if (note.id.isEmpty || note.title.isEmpty) continue;
        final chapterId = map['chapter_id']?.toString();
        final chapter = chapterId != null ? index.chapterById[chapterId] : null;
        final subject = chapterId != null ? index.subjectByChapter[chapterId] : null;
        final item = RevisionItem(
          id: '',
          type: RevisionItemType.note,
          priority: RevisionPriority.low,
          title: note.title,
          detail: note.shortAnswer,
          dueAt: DateTime.now(),
          subject: subject,
          chapter: chapter,
          note: note,
        );
        final key = _itemKey(item);
        if (seen.contains(key)) continue;
        seen.add(key);
        items.add(_RevisionSeed(item: item, itemKey: key));
      }
    }

    return items;
  }

  Future<void> _seedQueue(String userId, List<_RevisionSeed> seeds) async {
    if (seeds.isEmpty) return;
    final payload = seeds.map((seed) {
      final item = seed.item;
      return {
        'user_id': userId,
        'item_key': seed.itemKey,
        'item_type': item.type.name,
        'subject_id': item.subject?.id,
        'chapter_id': item.chapter?.id,
        'note_id': item.note?.id,
        'question_id': item.question?.id,
        'title': item.title,
        'detail': item.detail,
        'priority': _priorityValue(item.priority),
        'due_at': item.dueAt.toIso8601String(),
      };
    }).toList();

    await _client.from('revision_items').upsert(
          payload,
          onConflict: 'user_id,item_key',
          ignoreDuplicates: true,
        );
  }

  RevisionItem _itemFromRow(
    Map<String, dynamic> map,
    _SubjectIndex index,
  ) {
    final typeRaw = map['item_type']?.toString() ?? 'topic';
    final type = RevisionItemType.values.firstWhere(
      (value) => value.name == typeRaw,
      orElse: () => RevisionItemType.topic,
    );
    final priority = _priorityFromValue(map['priority'] as num?);
    final dueAt = _parseDate(map['due_at']);
    final chapterId = map['chapter_id']?.toString();
    final subjectId = map['subject_id']?.toString();
    final chapter = chapterId != null ? index.chapterById[chapterId] : null;
    Subject? subject = subjectId != null ? index.subjectById[subjectId] : null;
    if (subject == null && chapterId != null) {
      subject = index.subjectByChapter[chapterId];
    }

    return RevisionItem(
      id: map['item_key']?.toString() ?? '',
      type: type,
      priority: priority,
      title: map['title']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      dueAt: dueAt,
      subject: subject,
      chapter: chapter,
      note: null,
      question: null,
    );
  }

  String _itemKey(RevisionItem item) {
    switch (item.type) {
      case RevisionItemType.chapter:
        return 'chapter:${item.chapter?.id ?? item.title}';
      case RevisionItemType.note:
        return 'note:${item.note?.id ?? item.title}';
      case RevisionItemType.question:
        return 'question:${item.question?.id ?? item.title}';
      case RevisionItemType.topic:
        return 'topic:${item.title.toLowerCase().trim()}';
    }
  }

  int _priorityValue(RevisionPriority priority) {
    switch (priority) {
      case RevisionPriority.high:
        return 3;
      case RevisionPriority.medium:
        return 2;
      case RevisionPriority.low:
        return 1;
    }
  }

  RevisionPriority _priorityFromValue(num? raw) {
    final value = raw?.toInt() ?? 2;
    if (value >= 3) return RevisionPriority.high;
    if (value == 2) return RevisionPriority.medium;
    return RevisionPriority.low;
  }

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now().subtract(const Duration(days: 1));
    if (raw is DateTime) return raw;
    final parsed = DateTime.tryParse(raw.toString());
    return parsed ?? DateTime.now().subtract(const Duration(days: 1));
  }

  RevisionPriority _priorityForSeverity(int severity) {
    if (severity >= 4) return RevisionPriority.high;
    if (severity >= 2) return RevisionPriority.medium;
    return RevisionPriority.low;
  }

  RevisionPriority _priorityForCompletion(double completion) {
    if (completion < 35) return RevisionPriority.high;
    if (completion < 60) return RevisionPriority.medium;
    return RevisionPriority.low;
  }

  DateTime _nextDueDate(DateTime lastSeen, int severity) {
    final intervalDays = severity >= 4
        ? 1
        : severity == 3
            ? 2
            : severity == 2
                ? 4
                : 6;
    final due = lastSeen.add(Duration(days: intervalDays));
    final now = DateTime.now();
    return due.isBefore(now) ? now : due;
  }

  DateTime _nextDueForCompletion(DateTime lastActivity, double completion) {
    final intervalDays = completion < 35
        ? 0
        : completion < 60
            ? 2
            : 4;
    final due = lastActivity.add(Duration(days: intervalDays));
    final now = DateTime.now();
    return due.isBefore(now) ? now : due;
  }
}

class _SubjectIndex {
  final Map<String, Chapter> chapterById = {};
  final Map<String, Subject> subjectByChapter = {};
  final Map<String, Subject> subjectById = {};

  _SubjectIndex(List<Subject> subjects) {
    for (final subject in subjects) {
      subjectById[subject.id] = subject;
      for (final chapter in subject.chapters) {
        chapterById[chapter.id] = chapter;
        subjectByChapter[chapter.id] = subject;
      }
    }
  }
}

class _RevisionSeed {
  final RevisionItem item;
  final String itemKey;

  const _RevisionSeed({
    required this.item,
    required this.itemKey,
  });
}
