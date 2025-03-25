import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:timagatt/screens/home_screen.dart';
import 'package:timagatt/screens/add_time_screen.dart';
import 'package:timagatt/screens/history_screen.dart';
import 'package:timagatt/screens/settings_screen.dart';

class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({Key? key}) : super(key: key);

  @override
  _TimeClockScreenState createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen> {
  @override
  void initState() {
    super.initState();
    // Force home tab selection on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TimeClockProvider>(context, listen: false);
      // Only set to home if coming from login (not during normal navigation)
      if (provider.isComingFromLogin) {
        provider.selectedTabIndex = 0;
        provider.isComingFromLogin = false;
        provider.notifyListeners();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);

    return Scaffold(
      body: IndexedStack(
        index: provider.selectedTabIndex,
        children: const [
          HomeScreen(),
          AddTimeScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: provider.selectedTabIndex,
        onTap: (index) {
          provider.selectedTabIndex = index;
          provider.notifyListeners();
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: provider.translate('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_circle_outline),
            label: provider.translate('addTime'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: provider.translate('history'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: provider.translate('settings'),
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
