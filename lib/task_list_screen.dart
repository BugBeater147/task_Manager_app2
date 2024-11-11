import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class Task {
  String id;
  String name;
  bool isCompleted;
  List<SubTask> subTasks;

  Task({
    required this.id,
    required this.name,
    this.isCompleted = false,
    this.subTasks = const [],
  });
}

class SubTask {
  String time;
  String description;

  SubTask({required this.time, required this.description});
}

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();
  User? user;

  @override
  void initState() {
    super.initState();

    // Listen for authentication state changes
    _auth.authStateChanges().listen((User? user) {
      setState(() {
        this.user = user;
      });
    });
  }

  Future<void> _addTask(String taskName) async {
    if (taskName.isEmpty || user == null) return;

    try {
      DocumentReference taskRef = await _firestore.collection('tasks').add({
        'userId': user!.uid,
        'taskName': taskName,
        'completed': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _taskController.clear();
    } catch (e) {
      print("Error adding task: $e");
    }
  }

  Future<void> _toggleTaskCompletion(DocumentSnapshot task) async {
    try {
      await task.reference.update({'completed': !task['completed']});
    } catch (e) {
      print("Error toggling task completion: $e");
    }
  }

  Future<void> _deleteTask(DocumentSnapshot task) async {
    try {
      await task.reference.delete();
    } catch (e) {
      print("Error deleting task: $e");
    }
  }

  // Function to add nested sub-tasks
  List<SubTask> _getSubTasksForTask(String taskId) {
    // For demonstration, we use hard-coded sub-tasks.
    // You may choose to fetch these from Firebase if they are dynamic.
    return [
      SubTask(time: "9 am - 10 am", description: "HW1, Essay2"),
      SubTask(time: "12 pm - 2 pm", description: "Read Chapter 3"),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      // If user is not logged in, show the login screen
      return LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              print("User logged out");
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(labelText: 'Enter task'),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _addTask(_taskController.text),
                  child: Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('tasks')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Error fetching tasks: ${snapshot.error}");
                  return Center(child: Text("Error loading tasks"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No tasks yet.'));
                }

                return ListView(
                  children: snapshot.data!.docs.map((task) {
                    return ExpansionTile(
                      title: Row(
                        children: [
                          Checkbox(
                            value: task['completed'],
                            onChanged: (_) => _toggleTaskCompletion(task),
                          ),
                          Expanded(
                            child: Text(
                              task['taskName'],
                              style: TextStyle(
                                decoration: task['completed']
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(task),
                          ),
                        ],
                      ),
                      children: _getSubTasksForTask(task.id)
                          .map((subTask) => ListTile(
                                title: Text(subTask.time),
                                subtitle: Text(subTask.description),
                              ))
                          .toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }
}
