import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// Define color constants
const Color lightGrey = Color(0xFFEFF1F3);
const Color darkGrey = Color(0xFF696773);
const Color teal = Color(0xFF009FB7);
const Color yellow = Color(0xFFFED766);
const Color dark = Color(0xFF272727);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(DateTimeAdapter());
  try {
    await Hive.openBox<Task>('tasks');
  } catch (e) {
    print("Error opening Hive box: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            routes: {
              '/': (context) => TaskScreen(),
              '/details': (context) => const TaskDetailsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/edit': (context) => const TaskEditScreen(),
            },
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primaryColor: lightGrey,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightGrey,
        titleTextStyle: TextStyle(
          color: dark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: teal,
        foregroundColor: yellow,
      ),
      scaffoldBackgroundColor: lightGrey,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: dark,
      appBarTheme: const AppBarTheme(
        backgroundColor: dark,
        titleTextStyle: TextStyle(
          color: lightGrey,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: yellow,
      ),
      scaffoldBackgroundColor: dark,
    );
  }
}

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  late String title;

  @HiveField(1)
  late String description;

  @HiveField(2)
  late bool completed;

  @HiveField(3)
  DateTime? dueDate;
}

class TaskProvider extends ChangeNotifier {
  final Box<Task> _taskBox = Hive.box<Task>('tasks');
  String _searchQuery = '';

  List<Task> get tasks {
    if (_searchQuery.isEmpty) {
      return _taskBox.values.toList();
    } else {
      return _taskBox.values.where((task) {
        return task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            task.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  void addTask(String title, String description, DateTime? dueDate) {
    final task = Task()
      ..title = title
      ..description = description
      ..completed = false
      ..dueDate = dueDate;
    _taskBox.add(task);
    notifyListeners();
  }

  void deleteTask(int index) {
    _taskBox.deleteAt(index);
    notifyListeners();
  }

  void deleteCompletedTasks() {
    _taskBox.values.where((task) => task.completed).toList().forEach((task) {
      task.delete();
    });
    notifyListeners();
  }

  void toggleTaskCompletion(Task task) {
    task.completed = !task.completed;
    task.save();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
}

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

class TaskScreen extends StatelessWidget {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  TaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'To-Do List',
          style: TextStyle(color: isDarkMode ? lightGrey : dark),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Container(
              width: 170,
              decoration: BoxDecoration(
                color: isDarkMode ? lightGrey : dark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: isDarkMode ? teal : yellow),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: (value) {
                  Provider.of<TaskProvider>(context, listen: false)
                      .setSearchQuery(value);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            itemCount: provider.tasks.length,
            itemBuilder: (context, index) {
              final task = provider.tasks[index];
              return TaskListItem(task: task, isDarkMode: isDarkMode);
            },
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(context, isDarkMode),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, bool isDarkMode) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: () {
            titleController.clear();
            descriptionController.clear();
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Add Task',
                  style: TextStyle(color: isDarkMode ? lightGrey : dark),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle:
                            TextStyle(color: isDarkMode ? lightGrey : dark),
                      ),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle:
                            TextStyle(color: isDarkMode ? lightGrey : dark),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Cancel',
                        style: TextStyle(color: isDarkMode ? lightGrey : dark)),
                  ),
                  TextButton(
                    onPressed: () {
                      Provider.of<TaskProvider>(context, listen: false).addTask(
                          titleController.text,
                          descriptionController.text,
                          null);
                      Navigator.pop(context);
                    },
                    child: Text('Done',
                        style: TextStyle(color: isDarkMode ? yellow : teal)),
                  ),
                ],
              ),
            );
          },
          child: Icon(Icons.add, color: isDarkMode ? teal : yellow),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          onPressed: () {
            Provider.of<TaskProvider>(context, listen: false)
                .deleteCompletedTasks();
          },
          child: Icon(Icons.delete, color: isDarkMode ? teal : yellow),
        ),
      ],
    );
  }
}

class TaskListItem extends StatelessWidget {
  final Task task;
  final bool isDarkMode;

  const TaskListItem({Key? key, required this.task, required this.isDarkMode})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 20,
            color: isDarkMode ? lightGrey : dark,
            decoration: task.completed
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Text(
          task.description.isNotEmpty ? task.description : 'No description',
          style: TextStyle(color: isDarkMode ? lightGrey : dark),
        ),
        trailing: Checkbox(
          value: task.completed,
          onChanged: (value) {
            Provider.of<TaskProvider>(context, listen: false)
                .toggleTaskCompletion(task);
          },
        ),
        onLongPress: () {
          Provider.of<TaskProvider>(context, listen: false)
              .deleteTask(task.key);
        },
        onTap: () {
          Navigator.pushNamed(context, '/details', arguments: task);
        },
      ),
    );
  }
}

class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final task = ModalRoute.of(context)!.settings.arguments as Task;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(context, '/edit', arguments: task);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              task.description.isNotEmpty ? task.description : 'No description',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key});

  @override
  _TaskEditScreenState createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late TextEditingController titleController;
  late TextEditingController notesController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final task = ModalRoute.of(context)!.settings.arguments as Task;
    titleController = TextEditingController(text: task.title);
    notesController = TextEditingController(text: task.description);
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final task = ModalRoute.of(context)!.settings.arguments as Task;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              task.title = titleController.text;
              task.description = notesController.text;
              task.save();
              Navigator.pop(context); // Go back to TaskDetailsScreen
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
        return ListTile(
          title: const Text('Dark Mode'),
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
          ),
        );
      }),
    );
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    return Task()
      ..title = reader.readString()
      ..description = reader.readString()
      ..completed = reader.readBool()
      ..dueDate = reader.read() as DateTime?;
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeBool(obj.completed);
    writer.write(obj.dueDate);
  }
}

class DateTimeAdapter extends TypeAdapter<DateTime> {
  @override
  final int typeId = 1;

  @override
  DateTime read(BinaryReader reader) {
    return DateTime.fromMillisecondsSinceEpoch(reader.readInt());
  }

  @override
  void write(BinaryWriter writer, DateTime obj) {
    writer.writeInt(obj.millisecondsSinceEpoch);
  }
}
