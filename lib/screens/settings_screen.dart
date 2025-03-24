import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';
import 'package:flutter/services.dart';
import 'package:time_clock/screens/auth/login_screen.dart';
import 'package:time_clock/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);

    return GestureDetector(
      // Dismiss keyboard when tapping anywhere on the screen
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.translate('settings'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Appearance section
                _buildSectionHeader(provider.translate('appearance')),
                const SizedBox(height: 8),

                // Theme selector
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(provider.translate('theme')),
                    subtitle: Text(
                      provider.themeMode == ThemeMode.system
                          ? provider.translate('systemDefault')
                          : provider.themeMode == ThemeMode.dark
                          ? provider.translate('dark')
                          : provider.translate('light'),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showThemeSelector(context, provider);
                    },
                  ),
                ),

                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(provider.translate('language')),
                    subtitle: Text(
                      provider.locale.languageCode == 'en'
                          ? provider.translate('english')
                          : provider.translate('icelandic'),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showLanguageSelector(context, provider);
                    },
                  ),
                ),

                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(provider.translate('timeFormat')),
                    subtitle: Text(
                      provider.use24HourFormat
                          ? provider.translate('hour24')
                          : provider.translate('hour12'),
                    ),
                    trailing: Switch(
                      value: provider.use24HourFormat,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        provider.toggleTimeFormat();
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Target hours settings
                _buildSectionHeader(provider.translate('workHours')),
                const SizedBox(height: 8),

                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider.translate('monthlyTargetHours')),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: provider.targetHours.toDouble(),
                                min: 40,
                                max: 240,
                                divisions: 20,
                                label: provider.targetHours.toString(),
                                onChanged: (double value) {
                                  provider.setTargetHours(value.toInt());
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${provider.targetHours} hrs',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // About section
                _buildSectionHeader(provider.translate('about')),
                const SizedBox(height: 8),

                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(provider.translate('version')),
                        trailing: const Text('1.0.0'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 2, thickness: 1.2),
                      ),
                      ListTile(
                        title: Text(provider.translate('privacyPolicy')),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Open privacy policy
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Divider(height: 2, thickness: 1.2),
                      ),
                      ListTile(
                        title: Text(provider.translate('termsOfService')),
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
                    title: Text(provider.translate('signOut')),
                    leading: const Icon(Icons.logout, color: Colors.red),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _logout(context);
                    },
                  ),
                ),

                // Add this in the build method, near the bottom of your settings list
                _buildSectionHeader(provider.translate('developer')),
                const SizedBox(height: 8),

                // Reset onboarding button
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text('Reset Onboarding'),
                    subtitle: Text('Show the onboarding screens again'),
                    trailing: const Icon(Icons.refresh),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _resetOnboarding(context);
                    },
                  ),
                ),
              ],
            ),
          ),
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

  void _showThemeSelector(BuildContext context, TimeClockProvider provider) {
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
                child: const Divider(height: 2, thickness: 1.2),
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

  void _showLanguageSelector(BuildContext context, TimeClockProvider provider) {
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
                child: const Divider(height: 2, thickness: 1.2),
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
    await prefs.setBool('onboardingComplete', false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Onboarding reset. Restart the app to see it.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _logout(BuildContext context) async {
    try {
      await AuthService().signOut();

      // Navigate back to login screen and clear all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }
}
