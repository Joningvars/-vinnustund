import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timagatt/utils/routes.dart';
import 'package:timagatt/screens/export_screen.dart';
import 'package:timagatt/screens/job/shared_jobs_screen.dart';
import 'package:timagatt/screens/job/job_requests_screen.dart';
import 'package:timagatt/services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingRequestCount();
    // Ensure settings are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsProvider>(context, listen: false).loadSettings();
    });
  }

  Future<void> _loadPendingRequestCount() async {
    final provider = Provider.of<TimeEntriesProvider>(context, listen: false);
    final count = await provider.getPendingRequestCount();
    if (mounted) {
      setState(() {
        _pendingRequestCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            Text(
              settingsProvider.translate('settings'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Add profile section at the top
            _buildProfileSection(context),

            // Existing settings sections below
            const SizedBox(height: 24),

            // Appearance section
            _buildSectionHeader(settingsProvider.translate('appearance')),
            const SizedBox(height: 8),

            // Theme selector
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(settingsProvider.translate('theme')),
                subtitle: Text(
                  settingsProvider.themeMode == ThemeMode.system
                      ? settingsProvider.translate('systemDefault')
                      : settingsProvider.themeMode == ThemeMode.dark
                      ? settingsProvider.translate('dark')
                      : settingsProvider.translate('light'),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showThemeSelector(context, settingsProvider);
                },
              ),
            ),

            const SizedBox(height: 12),

            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(settingsProvider.translate('language')),
                subtitle: Text(
                  settingsProvider.locale.languageCode == 'en'
                      ? settingsProvider.translate('english')
                      : settingsProvider.translate('icelandic'),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showLanguageSelector(context, settingsProvider);
                },
              ),
            ),

            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Consumer<SettingsProvider>(
                builder: (context, settingsProvider, child) {
                  return SwitchListTile(
                    title: Text(settingsProvider.translate('timeFormat')),
                    subtitle: Text(
                      settingsProvider.use24HourFormat
                          ? settingsProvider.translate('hour24')
                          : settingsProvider.translate('hour12'),
                    ),
                    value: settingsProvider.use24HourFormat,
                    onChanged: (value) {
                      settingsProvider.setTimeFormat(value);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Target hours settings
            _buildSectionHeader(settingsProvider.translate('workHours')),
            const SizedBox(height: 8),

            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(settingsProvider.translate('monthlyTargetHours')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: settingsProvider.targetHours.toDouble(),
                            min: 40,
                            max: 240,
                            divisions: 20,
                            label: settingsProvider.targetHours.toString(),
                            onChanged: (double value) {
                              settingsProvider.setTargetHours(value.toInt());
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${settingsProvider.targetHours} ${settingsProvider.translate('hours')}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // About section
            _buildSectionHeader(settingsProvider.translate('about')),
            const SizedBox(height: 8),

            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: Text(settingsProvider.translate('version')),
                    trailing: const Text('1.0.0'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 2, thickness: 0.5),
                  ),
                  ListTile(
                    title: Text(settingsProvider.translate('privacyPolicy')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Open privacy policy
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Divider(height: 2, thickness: 0.5),
                  ),
                  ListTile(
                    title: Text(settingsProvider.translate('termsOfService')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Open terms of service
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sign Out button
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(settingsProvider.translate('signOut')),
                leading: const Icon(Icons.logout, color: Colors.red),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _signOut(context);
                },
              ),
            ),

            const SizedBox(height: 24),

            // Shared Jobs button
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.group_work),
                title: Text(settingsProvider.translate('sharedJobs')),
                subtitle: Text(settingsProvider.translate('manageSharedJobs')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_pendingRequestCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _pendingRequestCount.toString(),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () => _navigateToSharedJobs(context),
              ),
            ),

            if (_pendingRequestCount > 0)
              Card(
                margin: const EdgeInsets.only(top: 8),
                color: Colors.red.shade50,
                child: ListTile(
                  leading: const Icon(
                    Icons.notifications_active,
                    color: Colors.red,
                  ),
                  title: Text(settingsProvider.translate('pendingRequests')),
                  subtitle: Text(
                    settingsProvider
                        .translate('pendingRequestsCount')
                        .replaceAll('{count}', _pendingRequestCount.toString()),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const JobRequestsScreen(),
                      ),
                    ).then((_) => _loadPendingRequestCount());
                  },
                ),
              ),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JobRequestsScreen(),
                  ),
                );
              },
              child: Text('View Job Requests'),
            ),

            // Add this button for testing
            ElevatedButton(
              onPressed: () async {
                final provider = Provider.of<TimeEntriesProvider>(
                  context,
                  listen: false,
                );
                await provider.checkForPendingRequests();
                await _loadPendingRequestCount();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Checked for pending requests')),
                );
              },
              child: Text('Check for Requests'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context, SettingsProvider provider) {
    // Dismiss keyboard before showing bottom sheet
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  provider.translate('theme'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Divider(height: 2, thickness: 0.5),
              ),
              ListTile(
                title: Text(provider.translate('systemDefault')),
                leading: const Icon(Icons.settings_brightness),
                trailing:
                    provider.themeMode == ThemeMode.system
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  provider.setThemeMode(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(provider.translate('light')),
                leading: const Icon(Icons.light_mode),
                trailing:
                    provider.themeMode == ThemeMode.light
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  provider.setThemeMode(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(provider.translate('dark')),
                leading: const Icon(Icons.dark_mode),
                trailing:
                    provider.themeMode == ThemeMode.dark
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  provider.setThemeMode(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageSelector(BuildContext context, SettingsProvider provider) {
    // Dismiss keyboard before showing bottom sheet
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  provider.translate('language'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Divider(height: 2, thickness: 0.5),
              ),
              ListTile(
                title: Text(provider.translate('english')),
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
                trailing:
                    provider.locale.languageCode == 'en'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  provider.setLocale(const Locale('en', ''));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(provider.translate('icelandic')),
                leading: const Text('🇮🇸', style: TextStyle(fontSize: 24)),
                trailing:
                    provider.locale.languageCode == 'is'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  provider.setLocale(const Locale('is', ''));
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _resetOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', true);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Onboarding reset. You will see it next time you restart the app.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );

    // Important: Don't log out or navigate away - just set the flag
  }

  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      // Navigate to login screen using named route
      Navigator.of(context).pushReplacementNamed(Routes.login);
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  void _navigateToSharedJobs(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SharedJobsScreen()),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile picture centered at top
            CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: Text(
                (user.displayName?.isNotEmpty == true)
                    ? user.displayName![0].toUpperCase()
                    : (user.email?.isNotEmpty == true)
                    ? user.email![0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // User name - with proper error handling
            FutureBuilder<Map<String, dynamic>?>(
              future: DatabaseService(uid: user.uid).getUserData(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text("Loading...");
                }

                String displayName;
                try {
                  final userData = snapshot.data;
                  displayName = userData?['name'] ?? user.displayName ?? '';
                  if (displayName.isEmpty) {
                    displayName = settingsProvider.translate('noName');
                  }
                } catch (e) {
                  print('Error getting user name: $e');
                  displayName =
                      user.displayName ?? settingsProvider.translate('noName');
                }

                return Text(
                  displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),

            // Email
            Text(
              user.email ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            // Email verification status
            if (user.emailVerified != true)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settingsProvider.translate('emailNotVerified'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _sendVerificationEmail(context),
                      child: Text(
                        settingsProvider.translate('verify'),
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Profile actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Edit profile button
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: Text(settingsProvider.translate('editProfile')),
                    onPressed: () => _showEditProfileDialog(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Change password button
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lock_outline),
                    label: Text(settingsProvider.translate('changePassword')),
                    onPressed: () => _showChangePasswordDialog(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final nameController = TextEditingController(text: user.displayName);

    // Get the user's name from Firestore
    DatabaseService(uid: user.uid).getUserData(user.uid).then((userData) {
      if (userData != null && userData['name'] != null) {
        nameController.text = userData['name'];
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(settingsProvider.translate('editProfile')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: settingsProvider.translate('name'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settingsProvider.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Update in Firestore
                  await DatabaseService(
                    uid: user.uid,
                  ).updateUserProfile(name: nameController.text.trim());

                  // Update display name in Firebase Auth
                  await user.updateDisplayName(nameController.text.trim());

                  Navigator.pop(context);

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        settingsProvider.translate('profileUpdated'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Force rebuild
                  setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(settingsProvider.translate('save')),
            ),
          ],
        );
      },
    );
  }

  // Add this method to send verification email
  void _sendVerificationEmail(BuildContext context) async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settingsProvider.translate('verificationEmailSent')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method to show change password dialog
  void _showChangePasswordDialog(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(settingsProvider.translate('changePassword')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  decoration: InputDecoration(
                    labelText: settingsProvider.translate('currentPassword'),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  decoration: InputDecoration(
                    labelText: settingsProvider.translate('newPassword'),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: settingsProvider.translate('confirmPassword'),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settingsProvider.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate passwords match
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        settingsProvider.translate('passwordsDoNotMatch'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    // Reauthenticate user
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text,
                    );
                    await user.reauthenticateWithCredential(credential);

                    // Change password
                    await user.updatePassword(newPasswordController.text);

                    Navigator.pop(context);

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          settingsProvider.translate('passwordChanged'),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(settingsProvider.translate('save')),
            ),
          ],
        );
      },
    );
  }
}
