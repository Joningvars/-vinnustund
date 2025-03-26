import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timagatt/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Add this global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class TimeClockProvider extends ChangeNotifier {
  BuildContext? context;
  bool isClockedIn = false;
  bool isOnBreak = false;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  DateTime? breakStartTime;
  Timer? _timer;
  bool isComingFromLogin = false;
  TimeOfDay startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = TimeOfDay(hour: 17, minute: 0);

  List<Job> jobs = [];

  Job? selectedJob;
  List<TimeEntry> timeEntries = [];
  int hoursWorkedThisWeek = 0;
  int targetHours = 173;
  String selectedPeriod = "Day";

  ThemeMode themeMode = ThemeMode.system;

  Locale locale = const Locale('is', '');

  bool use24HourFormat = true;

  Map<String, Map<String, String>> translations = {
    'en': {
      'home': 'Home',
      'addTime': 'Add Time',
      'history': 'History',
      'settings': 'Settings',
      'hoursWorked': 'Hours Worked',
      'totalHours': 'Total Hours',
      'clockIn': 'Clock In',
      'clockOut': 'Clock Out',
      'onBreak': 'On Break',
      'day': 'Day',
      'week': 'Week',
      'month': 'Month',
      'selectJob': 'Select Job',
      'recentEntries': 'Recent Entries',
      'viewAll': 'View All',
      'cannotChangeJob': 'Cannot change job while clocked in',
      'startTime': 'Start Time',
      'endTime': 'End Time',
      'description': 'Description',
      'enterWorkDescription': 'Enter work description',
      'submit': 'Submit',
      'timeEntryAdded': 'Time entry added successfully',
      'of': 'of',
      'hours': 'hours',
      'this': 'This',
      'hoursbyJob': 'Hours by Job',
      'today': 'Today',
      'workDescription': 'Work Description',
      'workDescriptionHint':
          'Please provide a brief description of the work completed',
      'cancel': 'Cancel',
      'createJob': 'Create Job',
      'jobName': 'Job Name',
      'selectColor': 'Select Color',
      'create': 'Create',
      'jobAdded': 'Job added successfully',
      'entries': 'entries',
      'noEntries': 'No time entries yet',
      'delete': 'Delete',
      'deleteEntry': 'Delete Entry',
      'deleteEntryConfirm': 'Are you sure you want to delete this time entry?',
      'timeEntryDeleted': 'Time entry deleted',
      'language': 'Language',
      'english': 'English',
      'icelandic': 'Íslenska',
      'cannotDeleteActiveJob': 'Cannot delete job while clocked in with it',
      'jobDeleted': 'Job deleted',
      'deleteJob': 'Delete Job',
      'deleteJobConfirm':
          'Are you sure you want to delete this job? All time entries for this job will also be deleted.',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'systemDefault': 'System Default',
      'light': 'Light',
      'dark': 'Dark',
      'workHours': 'Work Hours',
      'monthlyTargetHours': 'Monthly Target Hours',
      'about': 'About',
      'version': 'Version',
      'privacyPolicy': 'Privacy Policy',
      'termsOfService': 'Terms of Service',
      'hoursRemaining': 'hours remaining',
      'more': 'more',
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',
      'timeFormat': 'Time Format',
      'hour24': '24-hour',
      'hour12': '12-hour',
      'minutes': 'mins',
      'signOut': 'Sign Out',
      'trackYourWorkHours': 'Track Your Work Hours',
      'trackYourWorkHoursDesc':
          'Easily clock in and out to track your work hours accurately',
      'multipleJobs': 'Multiple Jobs',
      'multipleJobsDesc':
          'Track time for different jobs and projects separately',
      'detailedReports': 'Detailed Reports',
      'detailedReportsDesc':
          'View detailed reports of your work hours by day, week, or month',
      'skip': 'Skip',
      'next': 'Next',
      'getStarted': 'Get Started',
      'developer': 'Developer',
      'date': 'Date',
      'filterByJob': 'Filter by Job',
      'allJobs': 'All Jobs',
      'year': 'Year',
      'selectDate': 'Select Date',
      'allDates': 'All Dates',
      'welcomeBack': 'Welcome Back',
      'loginToContinue': 'Login to continue using the app',
      'email': 'Email',
      'password': 'Password',
      'login': 'Login',
      'emailRequired': 'Email is required',
      'passwordRequired': 'Password is required',
      'invalidEmail': 'Please enter a valid email address',
      'userDisabled': 'This user account has been disabled',
      'userNotFound': 'No user found with this email',
      'wrongPassword': 'Incorrect password',
      'invalidCredentials': 'Invalid email or password',
      'tooManyRequests': 'Too many login attempts. Please try again later',
      'networkError': 'Network error. Please check your connection',
      'loginError': 'Login error',
      'unknownError': 'An unknown error occurred',
      'register': 'Sign up',
      'forgotPassword': 'Forgot Password?',
      'enterName': 'Enter name',
      'enterEmail': 'Enter email',
      'enterPassword': 'Enter password',
      'confirmPassword': 'Confirm password',
      'passwordsDoNotMatch': 'Passwords do not match',
      'passwordResetEmailSent': 'Password reset email sent',
      'passwordTooShort': 'Password must be at least 6 characters',
      'sendResetEmail': 'Send',
      'error': 'Error',
      'name': 'Name',
      'resetPasswordDescription':
          'Enter your email to receive a password reset link',
      'resetPassword': 'Reset Password',
      'defaultJob1': 'Work 1',
      'defaultJob2': 'Work 2',
      'defaultJob3': 'Work 3',
      'jobLimitReached':
          'Maximum of 5 jobs reached. Please delete a job before adding a new one.',
      'exportToPdf': 'Export to PDF',
      'timeReport': 'Time Report',
      'summary': 'Summary',
      'timeRange': 'Time Range',
      'descriptions': 'Descriptions',
      'noEntriesForExport': 'No entries to export for this period',
      'exportComplete': 'Export Complete',
      'exportCompleteMessage': 'Your time entries have been exported to PDF',
      'view': 'View',
      'share': 'Share',
      'close': 'Close',
      'exportError': 'Error exporting entries',
      'startDate': 'Start Date',
      'endDate': 'End Date',
      'quickSelect': 'Quick Select',
      'today': 'Today',
      'thisWeek': 'This Week',
      'thisMonth': 'This Month',
      'export': 'Export',
      'add': 'Add',
    },
    'is': {
      'home': 'Heim',
      'addTime': 'Bæta við tíma',
      'history': 'Saga',
      'settings': 'Stillingar',
      'hoursWorked': 'Unnir tímar',
      'totalHours': 'Heildar tímar',
      'clockIn': 'Stimpla inn',
      'clockOut': 'Stimpla út',
      'clockInPDF': 'Inn',
      'clockOutPDF': 'Út',
      'onBreak': 'Í pásu',
      'day': 'Dagur',
      'week': 'Vika',
      'month': 'Mánuður',
      'selectJob': 'Veldu verkefni',
      'recentEntries': 'Nýlegar færslur',
      'viewAll': 'Sjá allt',
      'cannotChangeJob':
          'Ekki hægt að breyta verkefni á meðan þú ert stimplaður inn',
      'startTime': 'Upphafstími',
      'endTime': 'Lokatími',
      'description': 'Lýsing',
      'enterWorkDescription': 'Sláðu inn verklýsingu',
      'submit': 'Staðfesta',
      'timeEntryAdded': 'Tímafærslu bætt við',
      'of': 'af',
      'hours': 'klst',
      'this': 'Þessi',
      'today': 'Í dag',
      'hoursbyJob': 'Eftir verkum',
      'workDescription': 'Verklýsing',
      'workDescriptionHint': 'Sláðu inn verklýsingu',
      'cancel': 'Hætta við',
      'createJob': 'Búa til verk',
      'jobName': 'Heiti verks',
      'selectColor': 'Veldu lit',
      'create': 'Búa til',
      'jobAdded': 'Verki bætt við',
      'entries': 'færslur',
      'noEntries': 'Engar tímafærslur',
      'delete': 'Eyða',
      'deleteEntry': 'Eyða færslu',
      'deleteEntryConfirm':
          'Ertu viss um að þú viljir eyða þessari tímafærslu?',
      'timeEntryDeleted': 'Tímafærslu eytt',
      'language': 'Tungumál',
      'english': 'English',
      'icelandic': 'Íslenska',
      'cannotDeleteActiveJob':
          'Ekki hægt að eyða verki á meðan þú ert stimplaður inn á það',
      'jobDeleted': 'Verki eytt',
      'deleteJob': 'Eyða verki',
      'deleteJobConfirm':
          'Ertu viss um að þú viljir eyða þessu verki? Öllum tímafærslum fyrir þetta verk verður einnig eytt.',
      'appearance': 'Útlit',
      'theme': 'Þema',
      'systemDefault': 'Sjálfgefið kerfi',
      'light': 'Ljóst',
      'dark': 'Dökkt',
      'workHours': 'Vinnustundir',
      'monthlyTargetHours': 'Mánaðarlegt markmið',
      'about': 'Um',
      'version': 'Útgáfa',
      'privacyPolicy': 'Persónuverndarstefna',
      'termsOfService': 'Þjónustuskilmálar',
      'hoursRemaining': 'tímar eftir',
      'more': 'fleiri',
      'january': 'Janúar',
      'february': 'Febrúar',
      'march': 'Mars',
      'april': 'Apríl',
      'may': 'Maí',
      'june': 'Júní',
      'july': 'Júlí',
      'august': 'Ágúst',
      'september': 'September',
      'october': 'Október',
      'november': 'Nóvember',
      'december': 'Desember',
      'timeFormat': 'Tímasnið',
      'hour24': '24-tíma',
      'hour12': '12-tíma',
      'minutes': 'mín',
      'signOut': 'Skrá út',
      'trackYourWorkHours': 'Skráðu vinnustundir þínar',
      'trackYourWorkHoursDesc':
          'Stimpla inn og út til að fylgjast nákvæmlega með vinnustundum þínum',
      'multipleJobs': 'Mörg verkefni',
      'multipleJobsDesc':
          'Halda utan um tíma fyrir mismunandi verkefni og vinnustaði',
      'detailedReports': 'Ítarlegar skýrslur',
      'detailedReportsDesc':
          'Skoða ítarlegar skýrslur um vinnustundir þínar eftir degi, viku eða mánuði',
      'skip': 'Sleppa',
      'next': 'Áfram',
      'getStarted': 'Byrja',
      'developer': 'Þróunaraðili',
      'date': 'Dagsetning',
      'filterByJob': 'Sía eftir verkefni',
      'allJobs': 'Öll verkefni',
      'year': 'Ár',
      'selectDate': 'Veldu dagsetningu',
      'allDates': 'Allar dagsetningar',
      'welcomeBack': 'Velkomin/n aftur',
      'loginToContinue': 'Skráðu þig inn til að halda áfram',
      'email': 'Netfang',
      'password': 'Lykilorð',
      'login': 'Innskráning',
      'emailRequired': 'Netfang er nauðsynlegt',
      'passwordRequired': 'Lykilorð er nauðsynlegt',
      'invalidEmail': 'Vinsamlegast sláðu inn gilt netfang',
      'userDisabled': 'Þessi notandareikningur hefur verið gerður óvirkur',
      'userNotFound': 'Enginn notandi fannst með þessu netfangi',
      'wrongPassword': 'Rangt lykilorð',
      'invalidCredentials': 'Ógilt netfang eða lykilorð',
      'tooManyRequests':
          'Of margar innskráningartilraunir. Vinsamlegast reyndu aftur síðar',
      'networkError': 'Netvilla. Athugaðu nettenginguna þína',
      'loginError': 'Innskráningarvilla',
      'unknownError': 'Óþekkt villa kom upp',
      'register': 'Stofna aðgang',
      'forgotPassword': 'Gleymt lykilorð?',
      'enterName': 'Sláðu inn nafn',
      'enterEmail': 'Sláðu inn netfang',
      'enterPassword': 'Sláðu inn lykilorð',
      'confirmPassword': 'Staðfesta lykilorð',
      'passwordsDoNotMatch': 'Lykilorðin passa ekki',
      'passwordResetEmailSent': 'Tölvupóstur með lykilorðsstillingu sendur',
      'passwordTooShort': 'Lykilorð verður að vera minnst 6 stafir',
      'sendResetEmail': 'Senda',
      'error': 'Villa',
      'name': 'Nafn',
      'resetPasswordDescription':
          'Sláðu inn netfangið þitt til að fá lykilorðsstillingu',
      'resetPassword': 'Endursetja lykilorð',
      'defaultJob1': 'Verkefni A',
      'defaultJob2': 'Verkefni B',
      'defaultJob3': 'Verkefni C',
      'jobLimitReached':
          'Hámarki 5 verkefna náð. Vinsamlegast eyddu verkefni áður en þú bætir við nýju.',
      'exportToPdf': 'Flytja út í PDF',
      'timeReport': 'Tímaskýrsla',
      'summary': 'Samantekt',
      'timeRange': 'Tímabil',
      'descriptions': 'Lýsingar',
      'noEntriesForExport':
          'Engar færslur til að flytja út fyrir þetta tímabil',
      'exportComplete': 'Útflutningur lokið',
      'exportCompleteMessage': 'Tímafærslur þínar hafa verið fluttar út í PDF',
      'view': 'Skoða',
      'share': 'Deila',
      'close': 'Loka',
      'exportError': 'Villa við útflutning færslna',
      'startDate': 'Upphafsdagur',
      'endDate': 'Lokadagur',
      'quickSelect': 'Flýtival',
      'today': 'Í dag',
      'thisWeek': 'Þessi vika',
      'thisMonth': 'Þessi mánuður',
      'export': 'Flytja út',
      'add': 'Bæta',
    },
  };

  final TextEditingController descriptionController = TextEditingController();

  int selectedTabIndex = 0;

  DatabaseService? _databaseService;

  // Add this property to track the current user
  String? currentUserId;

  // Add this property to your TimeClockProvider class
  DateTime selectedDate = DateTime.now();

  // Add this property to track recovery attempts
  bool isRecoveryAttempted = false;

  TimeClockProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _databaseService = DatabaseService(uid: user.uid);
        loadData();
      } else {
        _databaseService = null;
      }
    });

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
    if (!isClockedIn || context == null) return;

    // Set clockOutTime but don't reset state yet
    clockOutTime = DateTime.now();
    _timer?.cancel();

    // Show description dialog
    showWorkDescriptionDialog(context!);
  }

  void showWorkDescriptionDialog(BuildContext context) {
    final TextEditingController descriptionController = TextEditingController();

    // Ensure keyboard is dismissed when dialog is shown
    FocusScope.of(context).unfocus();

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
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: translate('enterWorkDescription'),
                    filled: true,
                    fillColor: Colors.grey.shade100,
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
                        HapticFeedback.lightImpact();

                        // Reset clock state without saving
                        isClockedIn = false;
                        clockInTime = null;
                        clockOutTime = null;
                        breakStartTime = null;
                        notifyListeners();

                        Navigator.of(context).pop();
                      },
                      child: Text(
                        translate('cancel'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();

                        // Create the time entry with description
                        final entry = TimeEntry(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          jobId: selectedJob!.id,
                          jobName: selectedJob!.name,
                          jobColor: selectedJob!.color,
                          clockInTime: clockInTime!,
                          clockOutTime: clockOutTime!,
                          duration: clockOutTime!.difference(clockInTime!),
                          description: descriptionController.text,
                          date: DateFormat('yyyy-MM-dd').format(clockInTime!),
                        );

                        // Add to local list
                        timeEntries.add(entry);

                        // Save to Firebase
                        saveTimeEntryToFirebase(entry);

                        // Reset clock state
                        isClockedIn = false;
                        isOnBreak = false;
                        clockInTime = null;
                        clockOutTime = null;
                        breakStartTime = null;

                        // Update calculations
                        calculateHoursWorkedThisWeek();

                        // Notify listeners
                        notifyListeners();

                        Navigator.of(context).pop();
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
                      child: Text(translate('submit')),
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
    if (clockInTime == null) return;

    clockOutTime = DateTime.now();
    final duration = clockOutTime!.difference(clockInTime!);

    final entry = TimeEntry(
      jobId: selectedJob!.id,
      jobName: selectedJob!.name,
      jobColor: selectedJob!.color,
      clockInTime: clockInTime!,
      clockOutTime: clockOutTime!,
      duration: duration,
      description: description.isNotEmpty ? description : null,
    );

    timeEntries.add(entry);
    isClockedIn = false;
    isOnBreak = false;
    clockInTime = null;
    clockOutTime = null;
    breakStartTime = null;

    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Don't call notifyListeners() here
      // This is likely the main cause of flickering
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

  bool addManualEntry() {
    if (selectedJob == null) return false;

    // Ensure keyboard is dismissed
    if (context != null) {
      FocusScope.of(context!).unfocus();
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

    final duration = adjustedEndDateTime.difference(startDateTime);

    final entry = TimeEntry(
      jobId: selectedJob!.id,
      jobName: selectedJob!.name,
      jobColor: selectedJob!.color,
      clockInTime: startDateTime,
      clockOutTime: adjustedEndDateTime,
      duration: duration,
      description:
          descriptionController.text.isNotEmpty
              ? descriptionController.text
              : null,
    );

    timeEntries.add(entry);
    descriptionController.clear(); // Clear the description field
    calculateHoursWorkedThisWeek();
    saveData();
    notifyListeners();
    return true;
  }

  Future<void> deleteTimeEntry(String id) async {
    try {
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('timeEntries')
          .doc(id)
          .delete();

      // Show a success message (optional)
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          SnackBar(
            content: Text(translate('timeEntryDeleted')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      // The StreamBuilder will automatically update the UI
    } catch (e) {
      print('Error deleting time entry: $e');
      // Show error message (optional)
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);

    if (use24HourFormat) {
      return DateFormat('HH:mm').format(dt); // 24-hour format
    } else {
      return DateFormat('h:mm a').format(dt); // 12-hour format with AM/PM
    }
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

    // Use translated terms for hours and minutes
    final hoursText = translate('hours');
    final minutesText = translate('minutes');

    return '$hours $hoursText $minutes $minutesText';
  }

  Duration getTotalDuration() {
    return timeEntries.fold(
      Duration.zero,
      (total, entry) => total + entry.duration,
    );
  }

  void setState(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  Future<void> saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save time entries
      final entriesJson = timeEntries.map((entry) => entry.toJson()).toList();
      await prefs.setString('timeEntries', jsonEncode(entriesJson));

      // Save jobs
      final jobsJson = jobs.map((job) => job.toJson()).toList();
      await prefs.setString('jobs', jsonEncode(jobsJson));

      // Save theme settings
      prefs.setString('themeMode', themeMode.toString());
      prefs.setInt('targetHours', targetHours);

      // Save locale settings
      prefs.setString('languageCode', locale.languageCode);
      prefs.setString('countryCode', locale.countryCode ?? '');

      // Save time format preference
      prefs.setBool('use24HourFormat', use24HourFormat);

      // Save to Firestore if user is authenticated
      if (_databaseService != null) {
        await _databaseService!.saveJobs(jobs);
        await _databaseService!.saveTimeEntries(timeEntries);
        await _databaseService!.saveUserSettings(
          languageCode: locale.languageCode,
          countryCode: locale.countryCode ?? '',
          use24HourFormat: use24HourFormat,
          targetHours: targetHours,
          themeMode: themeMode.toString(),
        );
      }
    } catch (e) {
      print('Error saving data: $e');
      // You could show a snackbar or dialog here to inform the user
    }

    notifyListeners();
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

    // Load theme settings
    final themeModeStr = prefs.getString('themeMode');
    if (themeModeStr != null) {
      if (themeModeStr.contains('dark')) {
        themeMode = ThemeMode.dark;
      } else if (themeModeStr.contains('light')) {
        themeMode = ThemeMode.light;
      } else {
        themeMode = ThemeMode.system;
      }
    }

    targetHours = prefs.getInt('targetHours') ?? 173;

    // Load locale settings
    final languageCode = prefs.getString('languageCode') ?? 'is';
    final countryCode = prefs.getString('countryCode') ?? '';
    locale = Locale(languageCode, countryCode);

    // Load time format preference
    use24HourFormat = prefs.getBool('use24HourFormat') ?? true;

    // Then try to load from Firestore if user is authenticated
    if (_databaseService != null) {
      try {
        // Load jobs
        final firestoreJobs = await _databaseService!.loadJobs();
        if (firestoreJobs.isNotEmpty) {
          jobs = firestoreJobs;
        }

        // Load time entries
        final firestoreEntries = await _databaseService!.loadTimeEntries();
        if (firestoreEntries.isNotEmpty) {
          timeEntries = firestoreEntries;
        }

        // Load user settings
        final settings = await _databaseService!.loadUserSettings();
        if (settings != null) {
          locale = Locale(
            settings['languageCode'] ?? 'en',
            settings['countryCode'] ?? '',
          );
          use24HourFormat = settings['use24HourFormat'] ?? true;
          targetHours = settings['targetHours'] ?? 173;

          final themeModeStr = settings['themeMode'];
          if (themeModeStr != null) {
            if (themeModeStr.contains('dark')) {
              themeMode = ThemeMode.dark;
            } else if (themeModeStr.contains('light')) {
              themeMode = ThemeMode.light;
            } else {
              themeMode = ThemeMode.system;
            }
          }
        }
      } catch (e) {
        print('Error loading data from Firestore: $e');
        // Continue with local data if Firestore fails
      }
    }

    notifyListeners();
  }

  int getHoursWorkedForSelectedJob() {
    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    int totalMinutes = 0;
    for (var entry in timeEntries) {
      if (entry.clockInTime.isAfter(startDate)) {
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

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
    saveData();
  }

  void setTargetHours(int hours) {
    targetHours = hours;
    notifyListeners();
    saveData();
  }

  void setLocale(Locale newLocale) {
    locale = newLocale;

    // Save the locale preference
    _saveLocalePreference();

    // Update job names based on new language
    updateJobNamesForLanguage();

    notifyListeners();
  }

  void _saveLocalePreference() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('languageCode', locale.languageCode);
    prefs.setString('countryCode', locale.countryCode ?? '');
  }

  void updateJobNamesForLanguage() {
    // Only update default job names (the first three jobs)
    for (int i = 0; i < jobs.length && i < 3; i++) {
      String translationKey = 'defaultJob${i + 1}';
      if (translations[locale.languageCode]?.containsKey(translationKey) ==
          true) {
        jobs[i] = Job(
          id: jobs[i].id,
          name: translate(translationKey),
          color: jobs[i].color,
        );
      }
    }
  }

  String translate(String key) {
    try {
      // First try to use the built-in translations
      return translations[locale.languageCode]?[key] ?? key;
    } catch (e) {
      print('Translation error for key $key: $e');
      return key;
    }
  }

  void addJob(String name, Color color) {
    // Check if we've reached the job limit (5)
    if (jobs.length >= 5) {
      // Don't add more jobs and notify the user
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          SnackBar(
            content: Text(translate('jobLimitReached')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    final newJob = Job(name: name, color: color);
    jobs.add(newJob);

    // If this is the first job, select it
    if (jobs.length == 1) {
      selectedJob = newJob;
    }

    notifyListeners();
    saveData();

    if (context != null) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(translate('jobAdded')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void deleteJob(String jobId) {
    // Don't allow deleting the job if it's currently selected and clocked in
    if (isClockedIn && selectedJob?.id == jobId) {
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          SnackBar(
            content: Text(translate('cannotDeleteActiveJob')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    // Remove the job
    jobs.removeWhere((job) => job.id == jobId);

    // If the deleted job was selected, select another job if available
    if (selectedJob?.id == jobId) {
      selectedJob = jobs.isNotEmpty ? jobs.first : null;
    }

    // Remove time entries associated with this job
    timeEntries.removeWhere((entry) => entry.jobId == jobId);

    calculateHoursWorkedThisWeek();
    notifyListeners();
    saveData();

    if (context != null) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(translate('jobDeleted')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void setSelectedTabIndex(int index) {
    if (index >= 0 && index <= 4) {
      // Update to allow index 4 (5 tabs total)
      selectedTabIndex = index;
      notifyListeners();
    }
  }

  void setSelectedPeriod(String period) {
    selectedPeriod = period;
    notifyListeners();
  }

  void toggleTimeFormat() {
    use24HourFormat = !use24HourFormat;
    notifyListeners();
    saveData();
  }

  String formatTime(DateTime dateTime) {
    if (use24HourFormat) {
      return DateFormat('HH:mm').format(dateTime); // 24-hour format
    } else {
      return DateFormat('h:mm a').format(dateTime); // 12-hour format with AM/PM
    }
  }

  String formatDate(DateTime dateTime) {
    // Get the month name based on the month number
    final monthNames = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];

    final monthKey = monthNames[dateTime.month - 1]; // Arrays are 0-indexed
    final month = translate(monthKey);

    return '$month ${dateTime.day}, ${dateTime.year}';
  }

  // Add a method to get the correct period text
  String getPeriodText(String period) {
    if (period == 'Day') {
      return translate('today');
    } else {
      return '${translate('this')} ${translate(period.toLowerCase())}';
    }
  }

  // Add this method to initialize user data when they first sign up
  Future<void> initializeNewUser() async {
    if (_databaseService != null) {
      try {
        // First, create the user document if it doesn't exist
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'email': user.email,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }

        // Then save jobs and settings
        await _databaseService!.saveJobs(jobs);
        await _databaseService!.saveUserSettings(
          languageCode: locale.languageCode,
          countryCode: locale.countryCode ?? '',
          use24HourFormat: use24HourFormat,
          targetHours: targetHours,
          themeMode: themeMode.toString(),
        );
      } catch (e) {
        print('Error initializing user data: $e');
      }
    }
  }

  // Add this method to safely merge local and remote time entries
  Future<void> mergeTimeEntries() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get all entries from Firebase
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('timeEntries')
              .get();

      // Create a map of remote entries by ID for quick lookup
      final remoteEntries = <String, TimeEntry>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final entry = TimeEntry(
          id: data['id'],
          jobId: data['jobId'],
          jobName: data['jobName'],
          jobColor: Color(data['jobColor']),
          clockInTime: DateTime.parse(data['clockInTime']),
          clockOutTime: DateTime.parse(data['clockOutTime']),
          duration: Duration(minutes: data['duration']),
          description: data['description'],
        );
        remoteEntries[entry.id] = entry;
      }

      // Create a map of local entries by ID
      final localEntries = <String, TimeEntry>{};
      for (var entry in timeEntries) {
        localEntries[entry.id] = entry;
      }

      // Merge entries - keep all entries from both sources
      final mergedEntries = <TimeEntry>[];

      // Add all remote entries
      mergedEntries.addAll(remoteEntries.values);

      // Add local entries that don't exist remotely
      for (var entry in localEntries.values) {
        if (!remoteEntries.containsKey(entry.id)) {
          mergedEntries.add(entry);
          // Also save this entry to Firebase
          await saveTimeEntryToFirebase(entry);
        }
      }

      // Update the time entries list
      timeEntries = mergedEntries;

      // Log the merge results
      print(
        'Merged time entries: Local=${localEntries.length}, Remote=${remoteEntries.length}, Final=${timeEntries.length}',
      );

      // Calculate hours without notifying
      recalculateAllHours();

      // Now notify listeners
      notifyListeners();
    } catch (e) {
      print('Error merging time entries: $e');
    }
  }

  // Update the initialization to call mergeTimeEntries
  Future<void> initializeApp() async {
    try {
      // Initialize Firebase services
      _databaseService = DatabaseService(
        uid: FirebaseAuth.instance.currentUser!.uid,
      );

      // Load local data first
      await loadData();

      // Then merge with remote data
      await mergeTimeEntries();

      // Rest of your initialization...
    } catch (e) {
      print('Error initializing app: $e');
    }
  }

  // Add this method to backup all entries to local storage
  Future<void> backupEntriesToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = timeEntries.map((e) => e.toJson()).toList();
      await prefs.setString('timeEntries', jsonEncode(entriesJson));
      print('Backed up ${timeEntries.length} entries to local storage');
    } catch (e) {
      print('Error backing up entries to local storage: $e');
    }
  }

  // Add a method to get the current elapsed time
  String getElapsedTimeString() {
    if (clockInTime == null) return '00:00:00';

    final now = DateTime.now();
    final diff = now.difference(clockInTime!);

    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  // Add a method to load data without notifying listeners
  Future<void> loadDataSilently() async {
    try {
      // Load user-specific data here without triggering a rebuild
      // For example:
      // final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      // final userData = userDoc.data();
      // jobs = userData['jobs'];
      // etc.
    } catch (e) {
      print('Error loading data silently: $e');
    }
  }

  void addTimeEntry(
    Job job,
    DateTime clockInTime,
    DateTime clockOutTime,
    Duration duration,
    String? description,
  ) {
    // Create the entry with the selected date
    final entry = TimeEntry(
      jobId: job.id,
      jobName: job.name,
      jobColor: job.color,
      clockInTime: clockInTime,
      clockOutTime: clockOutTime,
      duration: duration,
      description: description,
    );

    // Check for duplicates (entries with same date and job within 1 minute)
    final duplicates =
        timeEntries
            .where(
              (e) =>
                  e.date == entry.date &&
                  e.jobId == entry.jobId &&
                  (e.clockInTime.difference(entry.clockInTime).inMinutes.abs() <
                      1),
            )
            .toList();

    // Remove any duplicates
    if (duplicates.isNotEmpty) {
      for (var dup in duplicates) {
        timeEntries.remove(dup);
      }
    }

    // Add the new entry
    timeEntries.add(entry);
    calculateHoursWorkedThisWeek();
    notifyListeners();

    // Save to Firebase
    if (_databaseService != null) {
      _databaseService!.saveTimeEntry(entry);
    } else {
      saveData(); // Fallback to local storage
    }
  }

  // Add this method to filter time entries by date
  List<TimeEntry> getTimeEntriesByDate(DateTime date) {
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return timeEntries.where((entry) => entry.date == dateString).toList();
  }

  // Add this method to get unique dates from time entries
  List<String> getUniqueDates() {
    final dates = timeEntries.map((entry) => entry.date).toSet().toList();
    dates.sort((a, b) => b.compareTo(a)); // Sort descending (newest first)
    return dates;
  }

  // Update the getTimeEntriesStream method to use Firestore directly
  Stream<List<TimeEntry>> getTimeEntriesStream() {
    if (_databaseService == null) {
      // Return an empty stream if no database service
      return Stream.value(timeEntries);
    }

    // Use FirebaseFirestore directly instead of trying to use _databaseService.collection
    return FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('timeEntries')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return TimeEntry(
              id: data['id'],
              jobId: data['jobId'],
              jobName: data['jobName'],
              jobColor: Color(data['jobColor']),
              clockInTime: DateTime.parse(data['clockInTime']),
              clockOutTime: DateTime.parse(data['clockOutTime']),
              duration: Duration(minutes: data['duration']),
              description: data['description'],
            );
          }).toList();
        });
  }

  // Update the updateTimeEntriesWithoutNotifying method to properly calculate hours
  void updateTimeEntriesWithoutNotifying(List<TimeEntry> entries) {
    timeEntries = entries;

    // Calculate hours for the selected period
    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    int totalMinutes = 0;
    for (var entry in timeEntries) {
      if (entry.clockInTime.isAfter(startDate)) {
        totalMinutes += entry.duration.inMinutes;
      }
    }

    hoursWorkedThisWeek = totalMinutes ~/ 60;
    // No notifyListeners() call here
  }

  // Update recalculateAllHours to remove the notifyListeners call
  void recalculateAllHours() {
    // Calculate hours for the selected period
    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    int totalMinutes = 0;
    for (var entry in timeEntries) {
      if (entry.clockInTime.isAfter(startDate)) {
        totalMinutes += entry.duration.inMinutes;
      }
    }

    hoursWorkedThisWeek = totalMinutes ~/ 60;
    // Remove the notifyListeners() call
  }

  // Add this method to directly save a time entry to Firebase
  Future<void> saveTimeEntryToFirebase(TimeEntry entry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Cannot save time entry: User not authenticated');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('timeEntries')
          .doc(entry.id)
          .set({
            'id': entry.id,
            'jobId': entry.jobId,
            'jobName': entry.jobName,
            'jobColor': entry.jobColor.value,
            'clockInTime': entry.clockInTime.toIso8601String(),
            'clockOutTime': entry.clockOutTime.toIso8601String(),
            'duration': entry.duration.inMinutes,
            'description': entry.description ?? '',
            'date': entry.date,
          });
      print('Time entry saved to Firebase successfully: ${entry.id}');
    } catch (e) {
      print('Error saving time entry to Firebase: $e');
    }
  }
}
