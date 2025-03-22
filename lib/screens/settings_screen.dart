import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);

    return Scaffold(
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
                  trailing: DropdownButton<ThemeMode>(
                    value: provider.themeMode,
                    underline: const SizedBox(),
                    onChanged: (ThemeMode? newValue) {
                      if (newValue != null) {
                        provider.setThemeMode(newValue);
                      }
                    },
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(provider.translate('systemDefault')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(provider.translate('light')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(provider.translate('dark')),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: const Text('Language'),
                  subtitle: Text(
                    provider.locale.languageCode == 'en'
                        ? 'English'
                        : 'Íslenska',
                  ),
                  trailing: DropdownButton<String>(
                    value: provider.locale.languageCode,
                    underline: const SizedBox(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        provider.setLocale(Locale(newValue, ''));
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'is', child: Text('Íslenska')),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Target hours settings
              _buildSectionHeader('Work Hours'),
              const SizedBox(height: 8),

              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Target Hours'),
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
              _buildSectionHeader('About'),
              const SizedBox(height: 8),

              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Version'),
                      trailing: const Text('1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Open privacy policy
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Open terms of service
                      },
                    ),
                  ],
                ),
              ),
            ],
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
}
