import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

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
            theme:
                themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
            initialRoute: '/',
            routes: {
              '/': (context) => TaskScreen(),
              '/details': (context) => const TaskDetailsScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
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
    final allTasks = _taskBox.values.toList();
    if (_searchQuery.isEmpty) {
      return allTasks;
    } else {
      return allTasks
          .where((task) =>
              task.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
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

  void updateTask(int index, String title, String description,
      DateTime? dueDate, bool completed) {
    final task = _taskBox.getAt(index);
    if (task != null) {
      task
        ..title = title
        ..description = description
        ..completed = completed
        ..dueDate = dueDate;
      task.save();
      notifyListeners();
    }
  }

  void deleteTask(int index) {
    _taskBox.deleteAt(index);
    notifyListeners();
  }

  void deleteCompletedTasks() {
    final completedTasks =
        _taskBox.values.where((task) => task.completed).toList();
    for (var task in completedTasks) {
      task.delete();
    }
    notifyListeners();
  }

  void toggleTaskCompletion(int index) {
    final task = _taskBox.getAt(index);
    if (task != null) {
      task.completed = !task.completed;
      task.save();
      notifyListeners();
    }
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF36363E),
        title: const Text(
          'To-Do List',
          style: TextStyle(
            color: Color(0xFFFBFEF9),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Container(
              width: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
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
      body: Consumer<TaskProvider>(builder: (context, provider, child) {
        return ListView.builder(
          itemCount: provider.tasks.length,
          itemBuilder: (context, index) {
            final task = provider.tasks[index];
            return ListTile(
              title: Text(
                task.title,
                style: TextStyle(
                  fontSize: 20,
                  decoration: task.completed
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              subtitle: Text(
                task.dueDate != null
                    ? 'Due: ${task.dueDate!.toLocal()}'
                    : 'No due date',
              ),
              trailing: IconButton(
                icon: Icon(
                  task.completed
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                onPressed: () {
                  provider.toggleTaskCompletion(index);
                },
              ),
              onLongPress: () {
                provider.deleteTask(index);
              },
              onTap: () {
                Navigator.pushNamed(context, '/details', arguments: task);
              },
            );
          },
        );
      }),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              titleController.clear();
              descriptionController.clear();
              DateTime? selectedDate;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Add Task'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      TextField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                    ],
                  ),
                  actions: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final dueDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (dueDate != null) {
                              selectedDate = dueDate;
                            }
                          },
                          child: const Text('Pick Due Date'),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Provider.of<TaskProvider>(context,
                                        listen: false)
                                    .addTask(
                                  titleController.text,
                                  descriptionController.text,
                                  selectedDate,
                                );
                                Navigator.pop(context);
                              },
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () {
              Provider.of<TaskProvider>(context, listen: false)
                  .deleteCompletedTasks();
            },
            child: const Icon(Icons.delete),
          ),
        ],
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${task.title}', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text('Description: ${task.description}'),
            const SizedBox(height: 8),
            Text('Due Date: ${task.dueDate?.toLocal() ?? 'No due date'}'),
            const SizedBox(height: 8),
            Text('Completed: ${task.completed ? "Yes" : "No"}'),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Dark Mode', style: TextStyle(fontSize: 18)),
            Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
            ),
          ],
        ),
      ),
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
