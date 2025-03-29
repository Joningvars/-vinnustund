import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/providers/base_provider.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TimeEntriesProvider extends BaseProvider {
  List<TimeEntry> timeEntries = [];
  bool isClockedIn = false;
  bool isOnBreak = false;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  DateTime? breakStartTime;
  Timer? _timer;
  int hoursWorkedThisWeek = 0;
  DateTime selectedDate = DateTime.now();
  final TextEditingController descriptionController = TextEditingController();
  SettingsProvider? _settingsProvider;
  Job? selectedJob;
  TimeOfDay startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = TimeOfDay(hour: 17, minute: 0);
  JobsProvider? _jobsProvider;
  bool isRecoveryAttempted = false;
  String selectedPeriod = 'Day';
  int targetHours = 160; // Default monthly target hours
  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('en', '');
  bool use24HourFormat = false;
  bool isComingFromLogin = true;
  int selectedTabIndex = 0;
  String lastProcessedEntriesKey = '';
  DateTime _lastCalculationTime = DateTime(2000);

  // Add this static flag at the class level
  static bool _isCalculating = false;

  // Add a flag to track if we're currently loading
  bool _isLoadingEntries = false;

  // Add this field to store all job entries
  final Map<String, List<TimeEntry>> _allJobEntries = {};

  @override
  void onUserAuthenticated() {
    loadTimeEntries();
  }

  @override
  void onUserLoggedOut() {
    timeEntries = [];
    isClockedIn = false;
    isOnBreak = false;
    clockInTime = null;
    clockOutTime = null;
    breakStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadTimeEntries() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingEntries) {
      print('⏱️ Already loading time entries, skipping duplicate call');
      return;
    }

    _isLoadingEntries = true;
    print('⏱️ Loading time entries...');

    try {
      if (databaseService != null) {
        final loadedEntries = await databaseService!.loadTimeEntries();

        // Check if entries are different before updating
        final currentEntriesJson = jsonEncode(
          timeEntries.map((e) => e.toJson()).toList(),
        );
        final loadedEntriesJson = jsonEncode(
          loadedEntries.map((e) => e.toJson()).toList(),
        );

        if (currentEntriesJson != loadedEntriesJson) {
          print('⏱️ New time entries loaded, updating');
          timeEntries = loadedEntries;

          // Only calculate if we have entries
          if (timeEntries.isNotEmpty) {
            calculateHoursWorkedThisWeek();
          } else {
            hoursWorkedThisWeek = 0;
          }

          notifyListeners();
        } else {
          print('⏱️ No changes in time entries, skipping update');
        }
      } else {
        // Load from local storage
        final prefs = await SharedPreferences.getInstance();
        final entriesJson = prefs.getString('timeEntries');

        // Only process if we haven't processed this exact data before
        if (entriesJson != null && entriesJson != lastProcessedEntriesKey) {
          lastProcessedEntriesKey = entriesJson;

          final List<dynamic> decoded = jsonDecode(entriesJson);
          timeEntries =
              decoded.map((item) => TimeEntry.fromJson(item)).toList();

          // Only calculate if we have entries
          if (timeEntries.isNotEmpty) {
            calculateHoursWorkedThisWeek();
          } else {
            hoursWorkedThisWeek = 0;
          }

          notifyListeners();
        }
      }

      // After loading entries, update missing user names
      await updateMissingUserNames();
    } catch (e) {
      print('Error loading time entries: $e');
    } finally {
      _isLoadingEntries = false;
    }
  }

  void calculateHoursWorkedThisWeek() {
    print('⏱️ Calculating hours worked this week...');
    print('⏱️ STACK TRACE: ${StackTrace.current}');

    // Early return if no entries
    if (timeEntries.isEmpty) {
      print('⏱️ No time entries found, setting hours to 0');
      hoursWorkedThisWeek = 0;
      super.notifyListeners();
      return;
    }

    // Get the start of the current week (Monday)
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDate = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    // Calculate total hours for the week
    double totalHours = 0;

    for (var entry in timeEntries) {
      // Skip entries without clock out time
      if (entry.clockOutTime == null) continue;

      // Skip entries not in current week
      if (!entry.clockInTime.isAfter(startDate) ||
          !entry.clockInTime.isBefore(now))
        continue;

      // Add hours from this entry
      totalHours += entry.duration.inMinutes / 60;
    }

    print('⏱️ Calculated total hours: $totalHours');
    hoursWorkedThisWeek = totalHours.round();
    super.notifyListeners();
  }

  void clockIn(BuildContext context) {
    if (isClockedIn) return;

    final jobsProvider = Provider.of<JobsProvider>(context, listen: false);
    selectedJob = jobsProvider.selectedJob;
    if (selectedJob == null) return;

    isClockedIn = true;
    clockInTime = DateTime.now();

    // Start a timer to update the UI without triggering calculations
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Only notify listeners without triggering calculations
      // This is a lightweight update just for the clock display
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          // Use a try-catch to handle potential state disposal
          super
              .notifyListeners(); // Call the parent's notifyListeners to avoid our overrides
        } catch (e) {
          // Ignore errors if the widget is disposed
        }
      });
    });

    // Update Firestore if authenticated
    if (databaseService != null) {
      databaseService!.updateUserClockState(
        isClockedIn: true,
        clockInTime: clockInTime,
        jobId: selectedJob!.id,
      );
    }

    notifyListeners();
  }

  void clockOut(BuildContext context, {String description = ''}) {
    if (!isClockedIn) return;

    if (selectedJob == null) {
      final jobsProvider = Provider.of<JobsProvider>(context, listen: false);
      selectedJob = jobsProvider.selectedJob;
    }

    if (selectedJob == null) return;

    isClockedIn = false;
    clockOutTime = DateTime.now();
    _timer?.cancel();

    // Create a time entry
    final currentUser = FirebaseAuth.instance.currentUser;
    final entry = TimeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: selectedJob!.id,
      jobName: selectedJob!.name,
      jobColor: selectedJob!.color,
      clockInTime: clockInTime!,
      clockOutTime: clockOutTime!,
      duration: clockOutTime!.difference(clockInTime!),
      description: description,
      userId: currentUser?.uid,
      userName: currentUser?.displayName ?? 'User',
    );

    timeEntries.add(entry);

    // Sort entries by date (newest first)
    timeEntries.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));

    // Save to Firestore if authenticated
    if (databaseService != null) {
      databaseService!.updateUserClockState(
        isClockedIn: false,
        clockOutTime: clockOutTime,
      );

      databaseService!.saveTimeEntry(entry);
    }

    // Save to local storage
    saveTimeEntriesToLocalStorage();

    // Reset state
    clockInTime = null;
    clockOutTime = null;
    descriptionController.clear();

    calculateHoursWorkedThisWeek();
    notifyListeners();
  }

  void toggleBreak() {
    if (!isClockedIn) return;

    isOnBreak = !isOnBreak;

    if (isOnBreak) {
      breakStartTime = DateTime.now();
    } else {
      breakStartTime = null;
    }

    // Update Firestore if authenticated
    if (databaseService != null) {
      databaseService!.updateUserBreakState(isOnBreak, breakStartTime);
    }

    notifyListeners();
  }

  Future<void> addManualTimeEntry(
    BuildContext context,
    DateTime startTime,
    DateTime endTime,
    String description,
  ) async {
    // Make sure we have a selected job
    if (selectedJob == null) {
      final jobsProvider = Provider.of<JobsProvider>(context, listen: false);
      selectedJob = jobsProvider.selectedJob;

      if (selectedJob == null) {
        print('No job selected for time entry');
        return;
      }
    }

    // Get the current user ID
    String? userId = null;
    if (databaseService != null &&
        databaseService!.getCurrentUserId() != null) {
      userId = databaseService!.getCurrentUserId();
    }

    final entry = TimeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: selectedJob!.id,
      jobName: selectedJob!.name,
      jobColor: selectedJob!.color,
      clockInTime: startTime,
      clockOutTime: endTime,
      duration: endTime.difference(startTime),
      description: description,
      userId: userId, // Add the user ID here
    );

    timeEntries.add(entry);

    // Sort entries by date (newest first)
    timeEntries.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));

    // Save to Firestore if authenticated
    if (databaseService != null) {
      await databaseService!.saveTimeEntry(entry);
    }

    // Save to local storage
    await saveTimeEntriesToLocalStorage();

    calculateHoursWorkedThisWeek();
    notifyListeners();
  }

  Future<void> deleteTimeEntry(String entryId) async {
    // Remove from local list
    timeEntries.removeWhere((entry) => entry.id == entryId);

    try {
      // Delete from Firebase if available
      if (databaseService != null) {
        await databaseService!.deleteTimeEntry(entryId);
      }
    } catch (e) {
      print('Error deleting from Firebase: $e');
      // Continue with local deletion even if Firebase fails
    }

    // Always save to local storage
    await saveTimeEntriesToLocalStorage();

    // Update calculations
    calculateHoursWorkedThisWeek();
  }

  Future<void> saveTimeEntriesToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = jsonEncode(
      timeEntries.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString('timeEntries', entriesJson);
  }

  // Get time entries for a specific job
  List<TimeEntry> getEntriesForJob(String jobId) {
    return timeEntries.where((entry) => entry.jobId == jobId).toList();
  }

  // Get time entries for a specific date range
  List<TimeEntry> getEntriesForDateRange(DateTime start, DateTime end) {
    return timeEntries.where((entry) {
      return entry.clockInTime.isAfter(start) &&
          entry.clockInTime.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  // Get time entries for a shared job
  Future<List<TimeEntry>> getSharedJobTimeEntries(String jobId) async {
    try {
      return await databaseService!.getSharedJobTimeEntries(jobId);
    } catch (e) {
      print('Error getting shared job time entries: $e');
      rethrow;
    }
  }

  Duration getElapsedTime() {
    if (!isClockedIn || clockInTime == null) {
      return Duration.zero;
    }

    final now = DateTime.now();
    return now.difference(clockInTime!);
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> initializeApp() async {
    await loadTimeEntries();
  }

  void setSettingsProvider(SettingsProvider provider) {
    _settingsProvider = provider;
  }

  String translate(String key) {
    if (_settingsProvider != null) {
      return _settingsProvider!.translate(key);
    }
    return key; // Just return the key if settings provider not available
  }

  String formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dt = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    final format =
        _settingsProvider?.use24HourFormat == true
            ? DateFormat.Hm() // 24-hour format
            : DateFormat.jm(); // 12-hour format
    return format.format(dt);
  }

  void setSelectedJob(Job? job) {
    if (job != null) {
      selectedJob = job;
      notifyListeners();
    }
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

  void setJobsProvider(JobsProvider provider) {
    _jobsProvider = provider;
  }

  List<Job> get jobs => _jobsProvider?.jobs ?? [];

  // Add formatTime method
  String formatTime(DateTime dateTime) {
    final format =
        _settingsProvider?.use24HourFormat == true
            ? DateFormat.Hm() // 24-hour format
            : DateFormat.jm(); // 12-hour format
    return format.format(dateTime);
  }

  // Add formatDate method
  String formatDate(DateTime dateTime) {
    return DateFormat.yMMMd(locale.languageCode).format(dateTime);
  }

  Stream<List<TimeEntry>> getTimeEntriesStream() {
    if (databaseService != null) {
      return databaseService!.getTimeEntriesStream();
    }
    // Return an empty stream if not authenticated
    return Stream.value([]);
  }

  void updateTimeEntriesWithoutNotifying(
    List<TimeEntry> newEntries,
    String entriesKey,
  ) {
    timeEntries = newEntries;
    lastProcessedEntriesKey = entriesKey;
    notifyListeners();
  }

  double getHoursWorkedForSelectedJob() {
    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        // Get start of week (Monday)
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    // Filter entries by date and job
    final filteredEntries =
        timeEntries.where((entry) {
          final isAfterStart =
              entry.clockInTime.isAfter(startDate) ||
              entry.clockInTime.isAtSameMomentAs(startDate);
          final isBeforeNow = entry.clockInTime.isBefore(now);
          final isSelectedJob =
              _jobsProvider?.selectedJob == null ||
              entry.jobId == _jobsProvider?.selectedJob?.id;

          return isAfterStart && isBeforeNow && isSelectedJob;
        }).toList();

    // Calculate total hours
    final totalMinutes = filteredEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.duration.inMinutes,
    );

    return totalMinutes / 60.0;
  }

  void setSelectedTabIndex(int index) {
    if (_settingsProvider != null) {
      _settingsProvider!.setSelectedTabIndex(index);
    }
  }

  // Add setState method to mimic StatefulWidget's setState
  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  Future<int> getPendingRequestCount() async {
    if (databaseService != null) {
      return await databaseService!.getPendingRequestCount();
    }
    return 0;
  }

  Future<void> checkForPendingRequests() async {
    if (databaseService != null) {
      await databaseService!.checkForPendingRequests();
    }
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    if (_settingsProvider != null) {
      _settingsProvider!.setThemeMode(mode);
    }
    notifyListeners();
  }

  void setLocale(Locale newLocale) {
    locale = newLocale;
    if (_settingsProvider != null) {
      _settingsProvider!.setLocale(newLocale);
    }
    notifyListeners();
  }

  void toggleTimeFormat() {
    use24HourFormat = !use24HourFormat;
    if (_settingsProvider != null) {
      _settingsProvider!.setTimeFormat(use24HourFormat);
    }
    notifyListeners();
  }

  void setTargetHours(int hours) {
    targetHours = hours;
    if (_settingsProvider != null) {
      _settingsProvider!.setTargetHours(hours);
    }
    notifyListeners();
  }

  // Add initializeNewUser method
  Future<void> initializeNewUser() async {
    // Create default jobs
    if (_jobsProvider != null && _jobsProvider!.jobs.isEmpty) {
      final defaultJobs = [
        Job(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: translate('work'),
          color: Colors.blue,
        ),
        Job(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          name: translate('personal'),
          color: Colors.green,
        ),
      ];

      for (var job in defaultJobs) {
        _jobsProvider!.addJob(job.name, job.color, null);
      }
    }

    // Set default settings
    themeMode = ThemeMode.system;
    locale = const Locale('en', '');
    use24HourFormat = false;
    targetHours = 160;

    notifyListeners();
  }

  // Add getElapsedTimeString method
  String getElapsedTimeString() {
    final duration = getElapsedTime();
    return formatDuration(duration);
  }

  // Add this method to TimeEntriesProvider class
  Map<String, double> getHoursByJobInPeriod(
    DateTime startDate,
    DateTime endDate,
  ) {
    // Early return if no time entries exist
    if (timeEntries.isEmpty) return {};

    final Map<String, double> hoursByJob = {};

    // Get all jobs with time entries in the period
    final jobIds =
        timeEntries
            .where(
              (entry) =>
                  entry.clockInTime.isAfter(startDate) &&
                  entry.clockInTime.isBefore(endDate) &&
                  entry.clockOutTime != null,
            )
            .map((entry) => entry.jobId)
            .toSet();

    // Early return if no jobs found
    if (jobIds.isEmpty) return {};

    for (var jobId in jobIds) {
      hoursByJob[jobId] = calculateHoursForJob(jobId, startDate, endDate);
    }

    return hoursByJob;
  }

  // Add this method to the TimeEntriesProvider class
  Job? getJobById(String jobId) {
    final jobsProvider = Provider.of<JobsProvider>(
      navigatorKey.currentContext!,
      listen: false,
    );
    try {
      return jobsProvider.jobs.firstWhere((job) => job.id == jobId);
    } catch (e) {
      return null; // Return null if job not found
    }
  }

  // Update the showDescriptionDialog method to match exactly the provided style
  Future<void> showDescriptionDialog(BuildContext context) async {
    // Unfocus any text field to dismiss keyboard
    FocusScope.of(context).unfocus();

    final TextEditingController descController = TextEditingController();
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: Colors.green.shade700,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  translate('workDescription'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  translate('workDescriptionHint'),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Text field
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    hintText: translate('enterWorkDescription'),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      child: Text(
                        translate('skip'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(translate('save')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      descriptionController.text = descController.text;
    }
  }

  // Update this method to handle shared jobs
  Future<void> saveTimeEntry(TimeEntry entry) async {
    timeEntries.add(entry);
    notifyListeners();

    // Save to Firebase if available
    if (databaseService != null) {
      try {
        // First, check if this is for a shared job
        final jobsProvider = _jobsProvider;
        if (jobsProvider != null) {
          final job = jobsProvider.jobs.firstWhere(
            (j) => j.id == entry.jobId,
            orElse: () => Job(id: '', name: '', color: Colors.grey),
          );

          if (job.id.isNotEmpty && job.isShared) {
            print('Saving time entry for shared job: ${job.id}');
          }
        }

        await databaseService!.saveTimeEntry(entry);
      } catch (e) {
        print('Error saving time entry to Firebase: $e');
      }
    }

    // Always save to local storage as backup
    await saveTimeEntriesToLocalStorage();
  }

  // Override notifyListeners to prevent excessive calculations
  @override
  void notifyListeners() {
    print('⏱️ notifyListeners called in TimeEntriesProvider');

    // Skip calculations if no time entries exist
    if (timeEntries.isEmpty) {
      print('⏱️ No time entries, skipping calculations');
      super.notifyListeners();
      return;
    }

    // Skip calculations if they were recently performed
    final now = DateTime.now();
    if (now.difference(_lastCalculationTime).inMilliseconds < 1000) {
      print('⏱️ Calculations performed recently, skipping');
      // Just call the parent's notifyListeners without calculating
      super.notifyListeners();
      return;
    }

    // Skip if already calculating to prevent recursion
    if (_isCalculating) {
      print('⏱️ Already calculating, preventing recursive call');
      super.notifyListeners();
      return;
    }

    print('⏱️ Performing calculations...');
    // Otherwise, calculate hours and then notify
    _lastCalculationTime =
        now; // Update the timestamp first to prevent recursion

    _isCalculating = true; // Set flag before calculating
    calculateHoursWorkedThisWeek();
    _isCalculating = false; // Reset flag after calculating

    // Note: calculateHoursWorkedThisWeek already calls super.notifyListeners()
  }

  // Add this optimization to prevent endless loops when calculating hours
  double calculateHoursForJob(
    String jobId,
    DateTime startDate,
    DateTime endDate,
  ) {
    print(
      '⏱️ Calculating hours for job $jobId between $startDate and $endDate',
    );

    // Early return if no time entries exist
    if (timeEntries.isEmpty) {
      print('⏱️ No time entries found, returning 0 hours');
      return 0.0;
    }

    final entries =
        timeEntries
            .where(
              (entry) =>
                  entry.jobId == jobId &&
                  entry.clockInTime.isAfter(startDate) &&
                  entry.clockInTime.isBefore(endDate),
            )
            .toList();

    // Early return if no matching entries
    if (entries.isEmpty) {
      print('⏱️ No matching entries found for job $jobId, returning 0 hours');
      return 0.0;
    }

    double totalHours = 0;
    for (var entry in entries) {
      final duration = entry.clockOutTime.difference(entry.clockInTime);
      totalHours += duration.inMinutes / 60;
    }

    print('⏱️ Calculated $totalHours hours for job $jobId');
    return totalHours;
  }

  // Add this method to efficiently check if there are any time entries
  bool get hasTimeEntries => timeEntries.isNotEmpty;

  // Load all entries for a specific job (including entries from other users)
  Future<void> loadAllEntriesForJob(String jobId) async {
    if (databaseService == null) return;

    try {
      final entries = await databaseService!.loadAllEntriesForJob(jobId);

      // Store these entries separately from the user's own entries
      _allJobEntries[jobId] = entries;

      notifyListeners();
    } catch (e) {
      print('Error loading all entries for job $jobId: $e');
      rethrow;
    }
  }

  // Get all entries for a specific job
  List<TimeEntry> getAllEntriesForJob(String jobId) {
    return _allJobEntries[jobId] ?? [];
  }

  // Get user names for a list of user IDs
  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    if (databaseService == null) return {};

    try {
      final userNames = await databaseService!.getUserNames(userIds);
      print('Got user names: $userNames for userIds: $userIds');
      return userNames;
    } catch (e) {
      print('Error getting user names: $e');
      return {};
    }
  }

  // Add this method to update an existing time entry
  Future<void> updateTimeEntry(TimeEntry updatedEntry) async {
    // Find and update the entry in the local list
    final index = timeEntries.indexWhere((e) => e.id == updatedEntry.id);
    if (index >= 0) {
      // Preserve the userName if it exists in the original entry
      final existingUserName = timeEntries[index].userName;
      if (existingUserName != null && updatedEntry.userName == null) {
        updatedEntry = TimeEntry(
          id: updatedEntry.id,
          jobId: updatedEntry.jobId,
          jobName: updatedEntry.jobName,
          jobColor: updatedEntry.jobColor,
          clockInTime: updatedEntry.clockInTime,
          clockOutTime: updatedEntry.clockOutTime,
          duration: updatedEntry.duration,
          description: updatedEntry.description,
          userId: updatedEntry.userId,
          userName: existingUserName, // Preserve the existing userName
        );
      }

      timeEntries[index] = updatedEntry;
      notifyListeners();
    }

    // Update in Firebase
    if (databaseService != null) {
      try {
        await databaseService!.updateTimeEntry(updatedEntry);
      } catch (e) {
        print('Error updating time entry: $e');
        rethrow;
      }
    }

    // Update in local storage
    await saveTimeEntriesToLocalStorage();
  }

  Future<void> addTimeEntry(
    Job job,
    DateTime startTime,
    DateTime endTime,
    String? description,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user data to include the name
      String? userName;
      if (databaseService != null) {
        final userData = await databaseService!.getUserData(user.uid);
        userName = userData?['name'] ?? user.displayName;
      }

      final duration = endTime.difference(startTime);
      final entry = TimeEntry(
        jobId: job.id,
        jobName: job.name,
        jobColor: job.color,
        clockInTime: startTime,
        clockOutTime: endTime,
        duration: duration,
        description: description,
        userId: user.uid,
        userName: userName, // Include the user's name
      );

      timeEntries.add(entry);
      notifyListeners();

      // Save to Firebase
      if (databaseService != null) {
        await databaseService!.saveTimeEntry(entry);
      }

      // Save to local storage
      await saveTimeEntriesToLocalStorage();
    } catch (e) {
      print('Error adding time entry: $e');
      rethrow;
    }
  }

  // Add this method to update userNames for entries that don't have them
  Future<void> updateMissingUserNames() async {
    if (databaseService == null) return;

    // Get entries without userName
    final entriesWithoutNames =
        timeEntries.where((e) => e.userName == null).toList();
    if (entriesWithoutNames.isEmpty) return;

    // Get unique user IDs
    final userIds = entriesWithoutNames.map((e) => e.userId).toSet().toList();
    if (userIds.isEmpty) return;

    // Get user names
    final userNames = await getUserNames(userIds.cast<String>());

    // Update entries
    for (final entry in entriesWithoutNames) {
      if (entry.userId != null && userNames.containsKey(entry.userId)) {
        final updatedEntry = TimeEntry(
          id: entry.id,
          jobId: entry.jobId,
          jobName: entry.jobName,
          jobColor: entry.jobColor,
          clockInTime: entry.clockInTime,
          clockOutTime: entry.clockOutTime,
          duration: entry.duration,
          description: entry.description,
          userId: entry.userId,
          userName: userNames[entry.userId],
        );

        await updateTimeEntry(updatedEntry);
      }
    }
  }

  // When creating a time entry from clock in/out
  Future<void> createTimeEntryFromClockIn() async {
    if (clockInTime == null || clockOutTime == null || selectedJob == null) {
      print('⚠️ Cannot create time entry: missing required data');
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      print(
        '👤 Current user: ${user?.uid}, displayName: ${user?.displayName}, email: ${user?.email}',
      );

      if (user == null) {
        print('❌ No authenticated user found');
        return;
      }

      // Get the user's name from their profile
      String? userName;
      if (databaseService != null) {
        print('🔍 Getting user data for ${user.uid}');
        final userData = await databaseService!.getUserData(user.uid);
        print('📄 User data retrieved: $userData');
        userName = userData?['name']; // Get name from user document
        print('👤 Using userName: $userName');
      } else {
        print('⚠️ Database service is null');
      }

      final duration = clockOutTime!.difference(clockInTime!);
      final entry = TimeEntry(
        jobId: selectedJob!.id,
        jobName: selectedJob!.name,
        jobColor: selectedJob!.color,
        clockInTime: clockInTime!,
        clockOutTime: clockOutTime!,
        duration: duration,
        description: descriptionController.text.trim(),
        userId: user.uid,
        userName: userName, // Include the user's name
      );

      timeEntries.add(entry);

      // Save to Firebase
      if (databaseService != null) {
        await databaseService!.saveTimeEntry(entry);
      }

      // Save to local storage
      await saveTimeEntriesToLocalStorage();

      notifyListeners();
    } catch (e) {
      print('Error creating time entry: $e');
    }
  }
}
