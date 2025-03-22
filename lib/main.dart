import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:time_clock/models/time_entry.dart';
import 'package:time_clock/models/job.dart';
import 'package:time_clock/screens/home_screen.dart';
import 'package:time_clock/screens/add_time_screen.dart';
import 'package:time_clock/screens/history_screen.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimeClockProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Time Clock',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          cardTheme: CardTheme(
            elevation: 0,
            color: Colors.grey.shade50,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.orange,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const TimeClockScreen(),
      ),
    );
  }
}

class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({super.key});

  @override
  State<TimeClockScreen> createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool isClockedIn = false;
  bool isOnBreak = false;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  DateTime? breakStartTime;

  // For the time range selector
  TimeOfDay startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = TimeOfDay(hour: 17, minute: 0);

  // For the animated button
  late AnimationController _animationController;
  Timer? _timer;

  // For job tracking
  List<Job> _jobs = [
    Job(name: "Project Alpha", color: Colors.blue),
    Job(name: "Client Beta", color: Colors.green),
    Job(name: "Maintenance", color: Colors.orange),
    Job(name: "Admin Work", color: Colors.purple),
  ];

  Job? _selectedJob;

  // Mock data for time entries
  final List<TimeEntry> _timeEntries = [];

  // For the circular progress
  int _hoursWorkedThisWeek = 0;
  final int _targetHours = 173;

  // For period selection
  String _selectedPeriod = "Day";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _selectedJob = _jobs.first;

    // Initialize with some mock data
    _timeEntries.addAll([
      TimeEntry(
        clockInTime: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
        clockOutTime: DateTime.now().subtract(const Duration(days: 1)),
        jobId: _jobs[0].id,
        jobName: _jobs[0].name,
        jobColor: _jobs[0].color,
      ),
      TimeEntry(
        clockInTime: DateTime.now().subtract(const Duration(days: 2, hours: 9)),
        clockOutTime: DateTime.now().subtract(
          const Duration(days: 2, hours: 1),
        ),
        jobId: _jobs[1].id,
        jobName: _jobs[1].name,
        jobColor: _jobs[1].color,
      ),
    ]);

    _calculateHoursWorkedThisWeek();
  }

  void _calculateHoursWorkedThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    int totalMinutes = 0;
    for (var entry in _timeEntries) {
      if (entry.clockInTime.isAfter(startOfWeek)) {
        totalMinutes += entry.duration.inMinutes;
      }
    }

    setState(() {
      _hoursWorkedThisWeek = totalMinutes ~/ 60;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void clockIn() {
    if (_selectedJob == null) {
      _showJobSelectionDialog();
      return;
    }

    setState(() {
      isClockedIn = true;
      isOnBreak = false;
      clockInTime = DateTime.now();
      clockOutTime = null;
      breakStartTime = null;
    });

    _animationController.repeat(reverse: false);
    _startTimer();
  }

  void clockOut() {
    final now = DateTime.now();
    setState(() {
      isClockedIn = false;
      isOnBreak = false;
      clockOutTime = now;

      // Add the completed time entry to history
      if (clockInTime != null && _selectedJob != null) {
        _timeEntries.insert(
          0,
          TimeEntry(
            clockInTime: clockInTime!,
            clockOutTime: now,
            jobId: _selectedJob!.id,
            jobName: _selectedJob!.name,
            jobColor: _selectedJob!.color,
          ),
        );

        _calculateHoursWorkedThisWeek();
      }
    });

    _animationController.stop();
    _timer?.cancel();
    _timer = null;
    setState(() {});
  }

  void toggleBreak() {
    if (!isClockedIn) return;

    setState(() {
      isOnBreak = !isOnBreak;
      if (isOnBreak) {
        breakStartTime = DateTime.now();
        _timer?.cancel();
      } else {
        breakStartTime = null;
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (clockInTime != null && !isOnBreak) {
        final diff = DateTime.now().difference(clockInTime!);
        final hours = diff.inHours.toString().padLeft(2, '0');
        final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {});
      }
    });
  }

  void _showJobSelectionDialog() {
    showCupertinoModalPopup(
      context: context,
      builder:
          (context) => CupertinoActionSheet(
            title: const Text('Select a Job'),
            message: const Text('Choose the job you are working on'),
            actions: [
              ..._jobs.map(
                (job) => CupertinoActionSheetAction(
                  onPressed: () {
                    setState(() {
                      _selectedJob = job;
                    });
                    Navigator.pop(context);
                    if (!isClockedIn) {
                      clockIn();
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: job.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(job.name),
                    ],
                  ),
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddJobDialog();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline),
                    SizedBox(width: 8),
                    Text('Add New Job'),
                  ],
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              isDestructiveAction: true,
              child: const Text('Cancel'),
            ),
          ),
    );
  }

  void _showAddJobDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Add New Job'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Job Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Color:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                                Colors.blue,
                                Colors.green,
                                Colors.orange,
                                Colors.purple,
                                Colors.red,
                                Colors.teal,
                              ]
                              .map(
                                (color) => GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedColor = color;
                                    });
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            selectedColor == color
                                                ? Colors.black
                                                : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        final newJob = Job(
                          name: nameController.text,
                          description:
                              descController.text.isEmpty
                                  ? null
                                  : descController.text,
                          color: selectedColor,
                        );

                        setState(() {
                          _jobs.add(newJob);
                          _selectedJob = newJob;
                        });

                        Navigator.pop(context);
                        if (!isClockedIn) {
                          clockIn();
                        }
                      }
                    },
                    child: const Text('Add Job'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != startTime) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != endTime) {
      setState(() {
        endTime = picked;
      });
    }
  }

  void addManualEntry() {
    if (_selectedJob == null) {
      _showJobSelectionDialog();
      return;
    }

    final now = DateTime.now();
    final startDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );
    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      endTime.hour,
      endTime.minute,
    );

    // Handle case where end time is on the next day
    final adjustedEndDateTime =
        endDateTime.isBefore(startDateTime)
            ? endDateTime.add(const Duration(days: 1))
            : endDateTime;

    setState(() {
      _timeEntries.insert(
        0,
        TimeEntry(
          clockInTime: startDateTime,
          clockOutTime: adjustedEndDateTime,
          jobId: _selectedJob!.id,
          jobName: _selectedJob!.name,
          jobColor: _selectedJob!.color,
        ),
      );

      _calculateHoursWorkedThisWeek();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Time entry added successfully'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void deleteTimeEntry(String id) {
    setState(() {
      _timeEntries.removeWhere((entry) => entry.id == id);
      _calculateHoursWorkedThisWeek();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Time entry deleted'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    final format = DateFormat.jm(); // 6:00 PM format
    return format.format(dt);
  }

  String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Not set';
    return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
  }

  Duration calculateDuration() {
    if (clockInTime == null) return Duration.zero;

    final end = clockOutTime ?? DateTime.now();
    return end.difference(clockInTime!);
  }

  Duration calculateManualDuration() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      endTime.hour,
      endTime.minute,
    );

    // Handle case where end time is on the next day
    if (end.isBefore(start)) {
      return end.add(const Duration(days: 1)).difference(start);
    }

    return end.difference(start);
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours hrs $minutes mins';
  }

  Duration getTotalDuration() {
    return _timeEntries.fold(
      Duration.zero,
      (total, entry) => total + entry.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context, listen: false);
    provider.context = context;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [HomeScreen(), AddTimeScreen(), HistoryScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add Time',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
