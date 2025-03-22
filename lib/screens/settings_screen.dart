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
              const Text(
                'Settings',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Appearance section
              _buildSectionHeader('Appearance'),
              const SizedBox(height: 8),

              // Theme selector
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(
                    provider.themeMode == ThemeMode.system
                        ? 'System default'
                        : provider.themeMode == ThemeMode.dark
                        ? 'Dark'
                        : 'Light',
                  ),
                  trailing: DropdownButton<ThemeMode>(
                    value: provider.themeMode,
                    underline: const SizedBox(),
                    onChanged: (ThemeMode? newValue) {
                      if (newValue != null) {
                        provider.setThemeMode(newValue);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System default'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
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
