import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:time_clock/models/job.dart';
import 'package:time_clock/models/time_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeClockProvider extends ChangeNotifier {
  BuildContext? context;
  bool isClockedIn = false;
  bool isOnBreak = false;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  DateTime? breakStartTime;
  Timer? _timer;

  TimeOfDay startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = TimeOfDay(hour: 17, minute: 0);

  List<Job> jobs = [
    Job(name: "Ntv", color: Colors.blue),
    Job(name: "Livey", color: Colors.green),
    Job(name: "Maintenance", color: Colors.orange),
    Job(name: "Admin Work", color: Colors.purple),
  ];

  Job? selectedJob;
  List<TimeEntry> timeEntries = [];
  int hoursWorkedThisWeek = 0;
  final int targetHours = 173;
  String selectedPeriod = "Day";

  TimeClockProvider() {
    loadData();
  }

  void calculateHoursWorkedThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    int totalMinutes = 0;
    for (var entry in timeEntries) {
      if (entry.clockInTime.isAfter(startOfWeek)) {
        totalMinutes += entry.duration.inMinutes;
      }
    }

    hoursWorkedThisWeek = totalMinutes ~/ 60;
    notifyListeners();
  }

  void clockIn() {
    if (selectedJob == null) {
      showJobSelectionDialog();
      return;
    }

    isClockedIn = true;
    isOnBreak = false;
    clockInTime = DateTime.now();
    clockOutTime = null;
    breakStartTime = null;

    startTimer();
    notifyListeners();
  }

  void clockOut() {
    if (context == null) return;

    // Show description dialog before completing clock out
    showWorkDescriptionDialog(context!);
  }

  void showWorkDescriptionDialog(BuildContext context) {
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
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
              color: Colors.white,
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
                const Text(
                  'Work Description',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Please provide a brief description of the work completed',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Text field
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Enter work description',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.green.shade300,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  maxLines: 3,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          completeClockOut(descriptionController.text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void completeClockOut(String description) {
    final now = DateTime.now();
    isClockedIn = false;
    isOnBreak = false;
    clockOutTime = now;

    // Add the completed time entry to history
    if (clockInTime != null && selectedJob != null) {
      timeEntries.insert(
        0,
        TimeEntry(
          clockInTime: clockInTime!,
          clockOutTime: now,
          jobId: selectedJob!.id,
          jobName: selectedJob!.name,
          jobColor: selectedJob!.color,
          description: description.isNotEmpty ? description : null,
        ),
      );
    }

    stopTimer();
    calculateHoursWorkedThisWeek();
    saveData();
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
    notifyListeners();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void showJobSelectionDialog() {
    if (context == null) return;

    showCupertinoModalPopup(
      context: context!,
      builder:
          (context) => CupertinoActionSheet(
            title: const Text('Select a Job'),
            message: const Text('Choose the job you are working on'),
            actions: [
              ...jobs.map(
                (job) => CupertinoActionSheetAction(
                  onPressed: () {
                    selectedJob = job;
                    notifyListeners();
                    Navigator.pop(context);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
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
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              isDestructiveAction: true,
              child: const Text('Cancel'),
            ),
          ),
    );
  }

  Future<void> selectStartTime() async {
    if (context == null) return;

    final TimeOfDay? picked = await showTimePicker(
      context: context!,
      initialTime: startTime,
    );

    if (picked != null && picked != startTime) {
      startTime = picked;
      notifyListeners();
    }
  }

  Future<void> selectEndTime() async {
    if (context == null) return;

    final TimeOfDay? picked = await showTimePicker(
      context: context!,
      initialTime: endTime,
    );

    if (picked != null && picked != endTime) {
      endTime = picked;
      notifyListeners();
    }
  }

  void addManualEntry() {
    if (context == null || selectedJob == null) return;

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

    timeEntries.insert(
      0,
      TimeEntry(
        clockInTime: startDateTime,
        clockOutTime: adjustedEndDateTime,
        jobId: selectedJob!.id,
        jobName: selectedJob!.name,
        jobColor: selectedJob!.color,
      ),
    );

    calculateHoursWorkedThisWeek();
    saveData();
    notifyListeners();

    ScaffoldMessenger.of(context!).showSnackBar(
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
    if (context == null) return;

    timeEntries.removeWhere((entry) => entry.id == id);
    calculateHoursWorkedThisWeek();
    saveData();
    notifyListeners();

    ScaffoldMessenger.of(context!).showSnackBar(
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
    return timeEntries.fold(
      Duration.zero,
      (total, entry) => total + entry.duration,
    );
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    // Save time entries
    final entriesJson = timeEntries.map((entry) => entry.toJson()).toList();
    await prefs.setString('timeEntries', jsonEncode(entriesJson));

    // Save jobs
    final jobsJson = jobs.map((job) => job.toJson()).toList();
    await prefs.setString('jobs', jsonEncode(jobsJson));
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load time entries
    final entriesString = prefs.getString('timeEntries');
    if (entriesString != null) {
      final entriesJson = jsonDecode(entriesString) as List;
      timeEntries =
          entriesJson.map((json) => TimeEntry.fromJson(json)).toList();
    }

    // Load jobs
    final jobsString = prefs.getString('jobs');
    if (jobsString != null) {
      final jobsJson = jsonDecode(jobsString) as List;
      jobs = jobsJson.map((json) => Job.fromJson(json)).toList();

      // Make sure we have at least one job
      if (jobs.isEmpty) {
        jobs = [
          Job(name: "Project Alpha", color: Colors.blue),
          Job(name: "Client Beta", color: Colors.green),
        ];
      }
    }

    selectedJob = jobs.isNotEmpty ? jobs.first : null;
    calculateHoursWorkedThisWeek();
    notifyListeners();
  }

  int getHoursWorkedForSelectedJob() {
    if (selectedJob == null) return 0;

    final now = DateTime.now();
    DateTime? startDate;

    // Set the start date based on selected period
    if (selectedPeriod == "Day") {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (selectedPeriod == "Week") {
      startDate = now.subtract(Duration(days: now.weekday - 1));
    } else if (selectedPeriod == "Month") {
      startDate = DateTime(now.year, now.month, 1);
    }

    int totalMinutes = 0;
    for (var entry in timeEntries) {
      if (entry.jobId == selectedJob!.id &&
          entry.clockInTime.isAfter(startDate!)) {
        totalMinutes += entry.duration.inMinutes;
      }
    }

    return totalMinutes ~/ 60;
  }

  void setSelectedJob(Job job) {
    if (isClockedIn) {
      // Don't allow job changes while clocked in
      return;
    }

    selectedJob = job;
    notifyListeners();
  }

  Map<String, int> getHoursWorkedByJob() {
    final now = DateTime.now();
    DateTime? startDate;

    // Set the start date based on selected period
    if (selectedPeriod == "Day") {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (selectedPeriod == "Week") {
      startDate = now.subtract(Duration(days: now.weekday - 1));
    } else if (selectedPeriod == "Month") {
      startDate = DateTime(now.year, now.month, 1);
    } else {
      // Default to today if period is not recognized
      startDate = DateTime(now.year, now.month, now.day);
    }

    Map<String, int> jobHours = {};

    for (var job in jobs) {
      int totalMinutes = 0;
      for (var entry in timeEntries) {
        if (entry.jobId == job.id && entry.clockInTime.isAfter(startDate)) {
          totalMinutes += entry.duration.inMinutes;
        }
      }
      jobHours[job.id] = totalMinutes ~/ 60;
    }

    return jobHours;
  }
}
