import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatefulWidget {
  const TaskManagerApp({super.key});

  @override
  State<TaskManagerApp> createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends State<TaskManagerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _changeTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: TaskListPage(
        themeMode: _themeMode,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

// Task Categories
enum TaskCategory {
  work,
  personal,
  shopping,
  health,
  education,
  other,
}

String categoryLabel(TaskCategory cat) {
  switch (cat) {
    case TaskCategory.work:
      return 'Praca';
    case TaskCategory.personal:
      return 'Osobiste';
    case TaskCategory.shopping:
      return 'Zakupy';
    case TaskCategory.health:
      return 'Zdrowie';
    case TaskCategory.education:
      return 'Edukacja';
    case TaskCategory.other:
      return 'Inne';
  }
}

// Task Model
class TaskItem {
  final String id;
  String name;
  bool completed;
  bool favorite;
  TaskCategory category;
  String? priority;
  String? notes;
  DateTime createdAt;
  DateTime? dueDate;

  TaskItem({
    String? id,
    required this.name,
    this.completed = false,
    this.favorite = false,
    this.category = TaskCategory.other,
    this.priority,
    this.notes,
    DateTime? createdAt,
    this.dueDate,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'completed': completed,
        'favorite': favorite,
        'category': category.name,
        'priority': priority,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
      };

  factory TaskItem.fromMap(Map<String, dynamic> m) {
    final map = Map<String, dynamic>.from(m);
    TaskCategory parseCat(String? v) {
      return TaskCategory.values.firstWhere(
        (c) => c.name == v,
        orElse: () => TaskCategory.other,
      );
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return TaskItem(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? '',
      completed: map['completed'] == true,
      favorite: map['favorite'] == true,
      category: parseCat(map['category']?.toString()),
      priority: map['priority']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      dueDate: parseDate(map['dueDate']),
    );
  }
}

// Main Task List Page
class TaskListPage extends StatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;

  const TaskListPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final List<TaskItem> _items = [];
  final List<TaskItem> _archived = [];
  String _search = '';

  // Dialog controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priorityCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  TaskCategory _selectedCategory = TaskCategory.other;
  DateTime? _selectedDueDate;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priorityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getStringList('tasks') ?? [];
    final archivedJson = prefs.getStringList('archived') ?? [];

    setState(() {
      _items.clear();
      _items.addAll(
          tasksJson.map((s) => TaskItem.fromMap(jsonDecode(s))).toList());
      _archived.clear();
      _archived.addAll(
          archivedJson.map((s) => TaskItem.fromMap(jsonDecode(s))).toList());
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'tasks', _items.map((t) => jsonEncode(t.toMap())).toList());
    await prefs.setStringList(
        'archived', _archived.map((t) => jsonEncode(t.toMap())).toList());
  }

  void _resetDialogFields() {
    _nameCtrl.clear();
    _priorityCtrl.clear();
    _notesCtrl.clear();
    _selectedCategory = TaskCategory.other;
    _selectedDueDate = null;
    _favorite = false;
  }

  void _addItem() {
    final t = _nameCtrl.text.trim();
    if (t.isEmpty) return;

    setState(() {
      _items.insert(
        0,
        TaskItem(
          name: t,
          favorite: _favorite,
          category: _selectedCategory,
          priority: _priorityCtrl.text.trim().isEmpty
              ? null
              : _priorityCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          dueDate: _selectedDueDate,
        ),
      );
    });
    _resetDialogFields();
    _saveData();
  }

  void _openAddDialog() {
    _resetDialogFields();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_task, color: Colors.blue),
              SizedBox(width: 8),
              Text('Dodaj zadanie'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task name
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Nazwa zadania',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _favorite ? Icons.star : Icons.star_border,
                        color: _favorite ? Colors.amber : null,
                      ),
                      onPressed: () {
                        setDialogState(() => _favorite = !_favorite);
                        setState(() => _favorite = !_favorite);
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Category
                const Text('Kategoria', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<TaskCategory>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: TaskCategory.values
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(categoryLabel(c))))
                        .toList(),
                    onChanged: (c) {
                      setDialogState(() => _selectedCategory = c ?? TaskCategory.other);
                      setState(() => _selectedCategory = c ?? TaskCategory.other);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Priority
                TextField(
                  controller: _priorityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Priorytet',
                    hintText: 'Wysoki, Średni, Niski',
                    prefixIcon: Icon(Icons.flag),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notatki',
                    hintText: 'Dodatkowe informacje...',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                const Divider(),
                const SizedBox(height: 8),

                // Due date
                OutlinedButton.icon(
                  icon: Icon(
                    _selectedDueDate != null
                        ? Icons.check_circle
                        : Icons.calendar_today,
                    color: _selectedDueDate != null ? Colors.green : null,
                  ),
                  label: Text(_selectedDueDate == null
                      ? 'Wybierz termin'
                      : '📅 Do: ${_selectedDueDate!.day}.${_selectedDueDate!.month}.${_selectedDueDate!.year}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: _selectedDueDate != null
                        ? Colors.green.shade50
                        : null,
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => _selectedDueDate = date);
                      setState(() => _selectedDueDate = date);
                    }
                  },
                ),
                if (_selectedDueDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Usuń'),
                      onPressed: () {
                        setDialogState(() => _selectedDueDate = null);
                        setState(() => _selectedDueDate = null);
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anuluj'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              onPressed: () {
                _addItem();
                Navigator.of(ctx).pop();
              },
              label: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }

  List<TaskItem> get _filteredItems {
    if (_search.isEmpty) return _items;
    return _items
        .where((i) => i.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final completedCount = _items.where((i) => i.completed).length;
    final total = _items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskFlow'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.task_alt, size: 48, color: Colors.white),
                  const SizedBox(height: 10),
                  const Text(
                    'TaskFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$total zadań',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ustawienia'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      themeMode: widget.themeMode,
                      onThemeChanged: widget.onThemeChanged,
                      archivedCount: _archived.length,
                      onClearArchived: () {
                        setState(() => _archived.clear());
                        _saveData();
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('O aplikacji'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'TaskFlow',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.task_alt, size: 48),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Szukaj zadania...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Wszystkie', total.toString(), Icons.list_alt),
                _buildStatCard('Do zrobienia', (total - completedCount).toString(),
                    Icons.pending_actions),
                _buildStatCard('Ukończone', completedCount.toString(),
                    Icons.check_circle),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Task list
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt,
                            size: 100, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Brak zadań',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dodaj pierwsze zadanie',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Dismissible(
                        key: Key(item.id),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          setState(() {
                            _items.remove(item);
                            _archived.add(item);
                          });
                          _saveData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Zadanie usunięte'),
                              action: SnackBarAction(
                                label: 'Cofnij',
                                onPressed: () {
                                  setState(() {
                                    _archived.remove(item);
                                    _items.insert(index, item);
                                  });
                                  _saveData();
                                },
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: item.completed,
                              onChanged: (val) {
                                setState(() => item.completed = val ?? false);
                                _saveData();
                              },
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                decoration: item.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(categoryLabel(item.category)),
                                if (item.dueDate != null)
                                  Text(
                                    '📅 ${item.dueDate!.day}.${item.dueDate!.month}.${item.dueDate!.year}',
                                    style: TextStyle(
                                      color: item.dueDate!.isBefore(DateTime.now())
                                          ? Colors.red
                                          : Colors.blue,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                item.favorite ? Icons.star : Icons.star_border,
                                color: item.favorite ? Colors.amber : null,
                              ),
                              onPressed: () {
                                setState(() => item.favorite = !item.favorite);
                                _saveData();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        child: const Icon(Icons.add),
        tooltip: 'Dodaj zadanie',
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Settings Page
class SettingsPage extends StatelessWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;
  final int archivedCount;
  final VoidCallback onClearArchived;

  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.archivedCount,
    required this.onClearArchived,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Motyw',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Jasny'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (mode) => onThemeChanged(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Ciemny'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (mode) => onThemeChanged(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Systemowy'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (mode) => onThemeChanged(mode!),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Wyczyść archiwum'),
            subtitle: Text('Archiwum: $archivedCount zadań'),
            trailing: ElevatedButton(
              onPressed: archivedCount == 0 ? null : onClearArchived,
              child: const Text('Wyczyść'),
            ),
          ),
        ],
      ),
    );
  }
}
