import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const MissingSupabaseConfigApp());
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const StudentSurvivorApp());
}

class StudentSurvivorApp extends StatelessWidget {
  const StudentSurvivorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Survivor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const TodoPage(),
    );
  }
}

class MissingSupabaseConfigApp extends StatelessWidget {
  const MissingSupabaseConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Survivor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
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

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _titleController = TextEditingController();
  final _supabase = Supabase.instance.client;

  Stream<List<TodoItem>> _todosStream() {
    return _supabase
        .from('todos')
        .stream(primaryKey: ['id'])
        .order('id')
        .map((rows) => rows.map(TodoItem.fromMap).toList());
  }

  Future<void> _addTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Enter a task first.');
      return;
    }

    try {
      await _supabase.from('todos').insert({'title': title});
      _titleController.clear();
    } catch (error) {
      _showMessage('Failed to add task: $error');
    }
  }

  Future<void> _toggleTodo(TodoItem item, bool? value) async {
    try {
      await _supabase
          .from('todos')
          .update({'is_done': value ?? false})
          .eq('id', item.id);
    } catch (error) {
      _showMessage('Failed to update task: $error');
    }
  }

  Future<void> _deleteTodo(TodoItem item) async {
    try {
      await _supabase.from('todos').delete().eq('id', item.id);
    } catch (error) {
      _showMessage('Failed to delete task: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Survivor'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'New task',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addTodo,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<TodoItem>>(
              stream: _todosStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final todos = snapshot.data ?? [];
                if (todos.isEmpty) {
                  return const Center(child: Text('No tasks yet.'));
                }

                return ListView.separated(
                  itemCount: todos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = todos[index];
                    return ListTile(
                      leading: Checkbox(
                        value: item.isDone,
                        onChanged: (value) => _toggleTodo(item, value),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTodo(item),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TodoItem {
  final int id;
  final String title;
  final bool isDone;
  final DateTime? createdAt;

  const TodoItem({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
  });

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final parsedId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    final rawCreatedAt = map['created_at'];
    final createdAt = rawCreatedAt == null
        ? null
        : DateTime.tryParse(rawCreatedAt.toString());

    return TodoItem(
      id: parsedId,
      title: map['title']?.toString() ?? 'Untitled',
      isDone: map['is_done'] == true,
      createdAt: createdAt,
    );
  }
}
