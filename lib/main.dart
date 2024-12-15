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
            theme: ThemeData(
              primaryColor: const Color(0xFF94C5CC),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF000100),
                titleTextStyle: TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: const Color(0xFF94C5CC),
              ),
              scaffoldBackgroundColor: const Color(0xFFF8F8F8),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: const Color(0xFF94C5CC),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF000100),
                titleTextStyle: TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: const Color(0xFF94C5CC),
              ),
              scaffoldBackgroundColor: const Color(0xFF000100),
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
              task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              task.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
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
  final TextEditingController searchController = TextEditingController();

  TaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Container(
              width: 170,
              decoration: BoxDecoration(
                color: const Color(0xFFB4D2E7),
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
            Color backgroundColor = task.completed
                ? const Color.fromARGB(255, 62, 172, 66)
                : const Color.fromARGB(255, 204, 58, 58); // Use a green color for completed tasks

            return Container(
  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8), // Add margin
  decoration: BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(20), // Add border radius
    // border: Border.all(
    //   color: task.completed ? const Color.fromARGB(255, 23, 230, 30) : Colors.grey, // Border color
    //   width: 2, // Border width
    // ),
  ),
  child: ListTile(
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
    trailing: Checkbox(
      value: task.completed,
      onChanged: (value) {
        provider.toggleTaskCompletion(task);
      },
    ),
    onLongPress: () {
      provider.deleteTask(index);
    },
    onTap: () {
      Navigator.pushNamed(context, '/details', arguments: task);
    },
  ),
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
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB4D2E7)),
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
                                  '', // Empty description
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/edit',
                arguments: task,
              );
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
            const SizedBox(height: 10),
            Text(
              task.dueDate != null
                  ? 'Due Date: ${task.dueDate!.toLocal()}'
                  : 'No due date',
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
  DateTime? selectedDueDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final task = ModalRoute.of(context)!.settings.arguments as Task;
    titleController = TextEditingController(text: task.title);
    notesController = TextEditingController(text: task.description);
    selectedDueDate = task.dueDate;
  }

  @override
  Widget build(BuildContext context) {
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
              task.dueDate = selectedDueDate;
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
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDueDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (selectedDate != null) {
                  setState(() {
                    selectedDueDate = selectedDate;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedDueDate != null
                          ? 'Due Date: ${selectedDueDate!.toLocal()}'
                          : 'No due date',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.blue),
                  ],
                ),
              ),
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
