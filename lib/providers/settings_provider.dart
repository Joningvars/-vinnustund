import 'package:flutter/material.dart';
import 'package:timagatt/providers/base_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timagatt/main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsProvider extends BaseProvider {
  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('is', '');
  bool use24HourFormat = true;
  int targetHours = 173;
  int selectedTabIndex = 0;

  // Translations map
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
      'clockInPDF': 'In',
      'clockOutPDF': 'Out',
      'onBreak': 'On Break',
      'day': 'Day',
      'week': 'Week',
      'month': 'Month',
      'selectJob': 'Select Job',
      'selectJobFirst': 'Please select a job first',
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
      'cannotDeleteActiveJob': 'Cannot delete a job that is currently active',
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
      'use24HourFormat': 'Use 24-hour format',
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
      'sharedJobs': 'Shared Jobs',
      'manageSharedJobs': 'Create or join shared jobs with others',
      'joinJob': 'Join Job',
      'enterCode': 'Enter connection code',
      'publicJob': 'Public Job',
      'publicJobDescription': 'Anyone with the code can join this job',
      'privateJob': 'Private Job',
      'privateJobDescription': 'Only invited users can join this job',
      'joinRequestSent': 'Join request sent',
      'joinRequestPending': 'Your request to join this job is pending',
      'approveRequest': 'Approve',
      'denyRequest': 'Deny',
      'pendingRequests': 'Pending Requests',
      'noRequests': 'No pending requests',
      'pendingRequestsCount': '{count} pending job requests',
      'viewPendingRequests': 'View Pending Requests',
      'errorSavingEntry': 'Error saving time entry. Please try again.',
      'jobs': 'Jobs',
      'noSharedJobs': 'No shared jobs yet',
      'createSharedJob': 'Create Shared Job',
      'joinSharedJob': 'Join Shared Job',
      'jobUpdated': 'Job updated successfully',
      'deleteJobConfirmation': 'Are you sure you want to delete {jobName}?',
      'myJobs': 'My Jobs',
      'addJob': 'Add Job',
      'join': 'Join',
      'createJobDescription': 'Create your first job to start tracking time',
      'createFirstJob': 'Create First Job',
      'noJobsYet': 'No jobs yet',
      'sharedJobsPremiumFeature': 'Shared Jobs is a premium feature',
      'upgradeToAccessSharedJobs':
          'Upgrade your account to create and join shared jobs with your team',
      'upgrade': 'Upgrade',
      'enterCodeToJoin': 'Enter the connection code to join a shared job',
      'connectionCode': 'Connection Code',
      'sharedJobInfo':
          'Ask the job creator for the connection code to join their shared job',
      'createSharedJobDescription':
          'Create a shared job to collaborate with your team',
      'createNewJob': 'Create a new job',
      'jobNameRequired': 'Job name is required',
      'sharedJob': 'Shared Job',
      'sharedJobDescription':
          'Allow others to join this job with a connection code',
      'editJob': 'Edit Job',
      'save': 'Save',
      'jobColor': 'Job Color',
      'enterJobCode': 'Enter the job code',
      'jobCodeRequired': 'Job code is required',
      'invalidJobCode': 'Invalid job code',
      'jobJoined': 'Successfully joined job',
      'shareJobCode': 'Share Job Code',
      'copyCode': 'Code copied to clipboard',
      'enterConnectionCode': 'Enter the connection code to join a shared job',
      'askJobCreatorForCode':
          'Ask the job creator for the connection code to their shared job',
      'sharedJobsSelectButton': 'Shared Jobs',
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
      'createNewJob': 'Búa til nýtt verk',
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
      'selectJobFirst': 'Vinsamlegast veldu verkefni fyrst',
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
      'sharedJobs': 'Sameiginleg verkefni',
      'manageSharedJobs': 'Búa til eða tengjast sameiginlegum verkefnum',
      'joinJob': 'Tengjast verkefni',
      'enterCode': 'Sláðu inn tengikóða',
      'publicJob': 'Opið verkefni',
      'publicJobDescription': 'Allir með kóðann geta tengst þessu verkefni',
      'privateJob': 'Lokað verkefni',
      'privateJobDescription':
          'Notendur þurfa að biðja um leyfi til að tengjast',
      'joinRequestSent': 'Beiðni um aðgang send',
      'joinRequestPending':
          'Beiðni þín um að tengjast þessu verkefni er í vinnslu',
      'approveRequest': 'Samþykkja',
      'denyRequest': 'Hafna',
      'pendingRequests': 'Óafgreiddar beiðnir',
      'noRequests': 'Engar óafgreiddar beiðnir',
      'pendingRequestsCount': '{count} óafgreiddar verkefnabeiðnir',
      'viewPendingRequests': 'Skoða óafgreiddar beiðnir',
      'use24HourFormat': 'Nota 24-klukkutíma snið',
      'errorSavingEntry':
          'Villa við að vista tímafærslu. Vinsamlegast reyndu aftur.',
      'jobs': 'Verkefni',
      'noSharedJobs': 'Engin sameiginleg verkefni',
      'createSharedJob': 'Búa til sameiginlegt verkefni',
      'joinSharedJob': 'Tengjast sameiginlegu verkefni',
      'jobUpdated': 'Verki uppfært',
      'deleteJobConfirmation': 'Ertu viss um að þú viljir eyða þessu verki?',
      'myJobs': 'Mín verk',
      'addJob': 'Bæta verk',
      'join': 'Tengjast',
      'createJobDescription':
          'Búa til fyrsta verki til að byrja að fylgjast með tíma',
      'createFirstJob': 'Búa til fyrsta verk',
      'noJobsYet': 'Engin verk enn',
      'sharedJobsPremiumFeature': 'Sameiginleg verk eru ítarlegur eiginleiki',
      'upgradeToAccessSharedJobs':
          'Uppfæra reikninginn til að búa til og tengjast sameiginlegum verkum',
      'upgrade': 'Uppfæra',
      'enterCodeToJoin':
          'Sláðu inn tengikóða til að tengjast sameiginlegu verki',
      'connectionCode': 'Tengikóði',
      'sharedJobInfo':
          'Sæktu tengikóða frá verkstjóra til að tengjast verki þeirra',
      'createSharedJobDescription':
          'Búa til sameiginlegt verk til að vinna saman',
      'jobNameRequired': 'Nafn verks er nauðsynlegt',
      'sharedJob': 'Sameiginlegt verk',
      'sharedJobDescription':
          'Gera öllum kleift að tengjast verki með tengikóða',
      'editJob': 'Breyta verki',
      'save': 'Vista',
      'jobColor': 'Litur verks',
      'enterJobCode': 'Sláðu inn verkakóða',
      'jobCodeRequired': 'Verkakóði er nauðsynlegt',
      'invalidJobCode': 'Ógilt verkakóði',
      'jobJoined': 'Verki bætt við',
      'shareJobCode': 'Deila verkakóða',
      'copyCode': 'Verkakóði afritað',
      'enterConnectionCode':
          'Sláðu inn tengikóða til að tengjast sameiginlegu verki',
      'askJobCreatorForCode':
          'Biddu verkstjóra um tengikóða til að tengjast verki þeirra',
      'sharedJobsSelectButton': 'Sameiginleg verk',
    },
  };

  @override
  void onUserAuthenticated() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      // First try to load from Firebase if user is authenticated
      if (databaseService != null &&
          FirebaseAuth.instance.currentUser != null) {
        final settings = await databaseService!.loadUserSettings();

        if (settings != null) {
          // Load locale
          locale = Locale(
            settings['languageCode'] ?? 'is',
            settings['countryCode'] ?? '',
          );

          // Load time format
          use24HourFormat = settings['use24HourFormat'] ?? true;

          // Load target hours
          targetHours = settings['targetHours'] ?? 173;

          // Load theme mode
          final themeModeStr = settings['themeMode'];
          if (themeModeStr != null) {
            themeMode = _getThemeModeFromString(themeModeStr);
          }

          notifyListeners();
          return; // Exit early if we loaded from Firebase
        }
      }

      // Fall back to local storage if Firebase load failed or user not authenticated
      final prefs = await SharedPreferences.getInstance();

      // Load theme mode
      final themeModeString = prefs.getString('themeMode') ?? 'system';
      themeMode = _getThemeModeFromString(themeModeString);

      // Load locale
      final languageCode = prefs.getString('languageCode') ?? 'is';
      final countryCode = prefs.getString('countryCode') ?? '';
      locale = Locale(languageCode, countryCode);

      // Load 24-hour format
      use24HourFormat = prefs.getBool('use24HourFormat') ?? true;

      // Load target hours
      targetHours = prefs.getInt('targetHours') ?? 173;

      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
      // Use defaults if all else fails
      locale = const Locale('is', '');
      use24HourFormat = true;
      targetHours = 173;
      themeMode = ThemeMode.system;
      notifyListeners();
    }
  }

  Future<void> saveSettings({
    required Locale newLocale,
    required ThemeMode newThemeMode,
    required bool newUse24HourFormat,
    required int newTargetHours,
  }) async {
    locale = newLocale;
    themeMode = newThemeMode;
    use24HourFormat = newUse24HourFormat;
    targetHours = newTargetHours;

    // Save to Firestore if authenticated
    if (databaseService != null) {
      await databaseService!.saveUserSettings(
        languageCode: locale.languageCode,
        countryCode: locale.countryCode ?? '',
        use24HourFormat: use24HourFormat,
        targetHours: targetHours,
        themeMode: themeMode.toString(),
      );
    }

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    await prefs.setString('countryCode', locale.countryCode ?? '');
    await prefs.setBool('use24HourFormat', use24HourFormat);
    await prefs.setInt('targetHours', targetHours);
    await prefs.setString('themeMode', themeMode.toString());

    notifyListeners();
  }

  // Translation helper method
  String translate(String key) {
    final currentTranslations =
        translations[locale.languageCode] ?? translations['en']!;
    return currentTranslations[key] ?? key;
  }

  // Theme toggle method
  void toggleTheme() {
    if (themeMode == ThemeMode.light) {
      themeMode = ThemeMode.dark;
    } else if (themeMode == ThemeMode.dark) {
      themeMode = ThemeMode.system;
    } else {
      themeMode = ThemeMode.light;
    }

    saveSettings(
      newLocale: locale,
      newThemeMode: themeMode,
      newUse24HourFormat: use24HourFormat,
      newTargetHours: targetHours,
    );
  }

  // Language toggle method
  void toggleLanguage() {
    if (locale.languageCode == 'en') {
      locale = const Locale('is', '');
    } else {
      locale = const Locale('en', '');
    }

    saveSettings(
      newLocale: locale,
      newThemeMode: themeMode,
      newUse24HourFormat: use24HourFormat,
      newTargetHours: targetHours,
    );
  }

  // Time format toggle method
  void toggleTimeFormat() {
    use24HourFormat = !use24HourFormat;

    saveSettings(
      newLocale: locale,
      newThemeMode: themeMode,
      newUse24HourFormat: use24HourFormat,
      newTargetHours: targetHours,
    );
  }

  // Update target hours
  void updateTargetHours(int hours) {
    targetHours = hours;

    saveSettings(
      newLocale: locale,
      newThemeMode: themeMode,
      newUse24HourFormat: use24HourFormat,
      newTargetHours: targetHours,
    );
  }

  void setSelectedTabIndex(int index) {
    selectedTabIndex = index;
    notifyListeners();
  }

  Future<void> initializeApp() async {
    await loadSettings();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void setLocale(Locale newLocale) {
    locale = newLocale;
    _saveSettings();
    notifyListeners();
  }

  void setTimeFormat(bool use24Hour) {
    use24HourFormat = use24Hour;
    _saveSettings();
    notifyListeners();
  }

  void setTargetHours(int hours) {
    targetHours = hours;
    _saveSettings();
    notifyListeners();
  }

  // Add _saveSettings method
  Future<void> _saveSettings() async {
    await saveSettings(
      newLocale: locale,
      newThemeMode: themeMode,
      newUse24HourFormat: use24HourFormat,
      newTargetHours: targetHours,
    );
  }

  ThemeMode _getThemeModeFromString(String modeString) {
    if (modeString.contains('dark')) {
      return ThemeMode.dark;
    } else if (modeString.contains('light')) {
      return ThemeMode.light;
    } else {
      return ThemeMode.system;
    }
  }
}
