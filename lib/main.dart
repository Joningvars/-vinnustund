import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/screens/export_screen.dart';
import 'package:timagatt/screens/home_screen.dart';
import 'package:timagatt/screens/add_time_screen.dart';
import 'package:timagatt/screens/history_screen.dart';
import 'package:timagatt/screens/jobs_screen.dart';
import 'package:timagatt/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timagatt/screens/auth/login_screen.dart';
import 'package:timagatt/utils/routes.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timagatt/screens/onboarding_screen.dart';
import 'package:timagatt/localization/app_localizations.dart';
import 'package:timagatt/screens/splash_screen.dart';
import 'package:timagatt/utils/theme/darkmode.dart';
import 'package:timagatt/utils/theme/lightmode.dart';
import 'package:flutter/services.dart';
import 'package:timagatt/widgets/custom_nav_bar.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';

// Add this line to define the navigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for all locales
  await initializeDateFormatting();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = prefs.getBool('showOnboarding') ?? true;

  // Initialize providers
  final settingsProvider = SettingsProvider();
  final timeEntriesProvider = TimeEntriesProvider();
  final jobsProvider = JobsProvider();
  final sharedJobsProvider = SharedJobsProvider();

  // Initialize providers
  await settingsProvider.initializeApp();
  await timeEntriesProvider.initializeApp();
  await jobsProvider.initializeApp();
  await sharedJobsProvider.initializeApp();

  // Connect the providers
  sharedJobsProvider.setSettingsProvider(settingsProvider);
  timeEntriesProvider.setSettingsProvider(settingsProvider);
  timeEntriesProvider.setJobsProvider(jobsProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, TimeEntriesProvider>(
          create: (context) => TimeEntriesProvider(),
          update: (context, settingsProvider, timeEntriesProvider) {
            timeEntriesProvider ??= TimeEntriesProvider();
            timeEntriesProvider.setSettingsProvider(settingsProvider);
            return timeEntriesProvider;
          },
        ),
        ChangeNotifierProxyProvider2<
          SettingsProvider,
          TimeEntriesProvider,
          JobsProvider
        >(
          create: (context) => JobsProvider(),
          update: (
            context,
            settingsProvider,
            timeEntriesProvider,
            jobsProvider,
          ) {
            jobsProvider ??= JobsProvider();
            jobsProvider.setSettingsProvider(settingsProvider);
            jobsProvider.setTimeEntriesProvider(timeEntriesProvider);
            return jobsProvider;
          },
        ),
        ChangeNotifierProvider.value(value: sharedJobsProvider),
      ],
      child: MyApp(showOnboarding: showOnboarding),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;

  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'Tímagátt',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settingsProvider.themeMode,
      navigatorKey: navigatorKey,

      // Add localization support
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('is', ''), // Icelandic
      ],
      locale: settingsProvider.locale,

      // Define all routes
      routes: {
        Routes.splash: (context) => const SplashScreen(),
        Routes.onboarding: (context) => const OnboardingScreen(),
        Routes.login: (context) => const LoginScreen(),
        Routes.main: (context) => const TimeClockScreen(),
        Routes.home: (context) => const HomeScreen(),
        Routes.addTime: (context) => const AddTimeScreen(),
        Routes.history: (context) => const HistoryScreen(),
        Routes.settings: (context) => const SettingsScreen(),
        '/jobs': (context) => const JobsScreen(),
      },

      // Determine initial route
      initialRoute: showOnboarding ? Routes.onboarding : Routes.splash,

      // Handle route generation for dynamic routes
      onGenerateRoute: (settings) {
        if (settings.name == Routes.main) {
          // Force home tab when navigating to main screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            settingsProvider.notifyListeners();
          });
          return MaterialPageRoute(builder: (_) => const TimeClockScreen());
        }
        return null;
      },
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
  final List<Job> _jobs = [
    Job(id: "1", name: "Project Alpha", color: Colors.blue),
    Job(id: "2", name: "Client Beta", color: Colors.green),
    Job(id: "3", name: "Maintenance", color: Colors.orange),
    Job(id: "4", name: "Admin Work", color: Colors.purple),
  ];

  Job? _selectedJob;

  // Mock data for time entries
  final List<TimeEntry> _timeEntries = [];

  // For the circular progress
  int _hoursWorkedThisWeek = 0;
  final int _targetHours = 173;

  // For period selection
  final String _selectedPeriod = "Day";

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
        duration: Duration(hours: 8),
      ),
      TimeEntry(
        clockInTime: DateTime.now().subtract(const Duration(days: 1)),
        clockOutTime: DateTime.now().subtract(const Duration(days: 1)),
        jobId: _jobs[1].id,
        jobName: _jobs[1].name,
        jobColor: _jobs[1].color,
        duration: Duration(hours: 8),
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
            duration: Duration(hours: 8),
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
                          id: '${_jobs.length + 1}',
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
          duration: Duration(hours: 8),
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
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      body: IndexedStack(
        index: settingsProvider.selectedTabIndex,
        children: const [
          HomeScreen(),
          AddTimeScreen(),
          HistoryScreen(),
          JobsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: CustomNavBar(
        currentIndex: settingsProvider.selectedTabIndex,
        onTap: (index) {
          // Dismiss keyboard when switching tabs
          FocusScope.of(context).unfocus();
          settingsProvider.setSelectedTabIndex(index);
        },
        activeColor: Theme.of(context).primaryColor,
        inactiveColor: Colors.grey,
        indicatorColor: Theme.of(context).primaryColor,
        indicatorHeight: 1,
        items: [
          CustomNavBarItem(
            title: settingsProvider.translate('home'),
            icon: Icons.home_outlined,
          ),
          CustomNavBarItem(
            title: settingsProvider.translate('add'),
            icon: Icons.add_circle_outline,
          ),
          CustomNavBarItem(
            title: settingsProvider.translate('history'),
            icon: Icons.history_outlined,
          ),
          CustomNavBarItem(
            title: settingsProvider.translate('jobs'),
            icon: Icons.work_history_outlined,
          ),
          CustomNavBarItem(
            title: settingsProvider.translate('settings'),
            icon: Icons.settings_outlined,
          ),
        ],
      ),
    );
  }
}

class NavBarIndicatorPainter extends CustomPainter {
  final int position;
  final int itemCount;
  final Color color;

  NavBarIndicatorPainter({
    required this.position,
    required this.itemCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final itemWidth = size.width / itemCount;
    final indicatorWidth = itemWidth - 16;

    final left = position * itemWidth + (itemWidth - indicatorWidth) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, indicatorWidth, 2),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(NavBarIndicatorPainter oldDelegate) {
    return position != oldDelegate.position ||
        color != oldDelegate.color ||
        itemCount != oldDelegate.itemCount;
  }
}
