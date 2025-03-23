import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';

class ClockDisplay extends StatefulWidget {
  const ClockDisplay({super.key});

  @override
  State<ClockDisplay> createState() => _ClockDisplayState();
}

class _ClockDisplayState extends State<ClockDisplay> {
  late Timer _refreshTimer;
  String _displayTime = '00:00:00';

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Set up a timer that only updates this widget, not the entire app
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;

    final provider = Provider.of<TimeClockProvider>(context, listen: false);
    final newTime = provider.getElapsedTimeString();

    if (newTime != _displayTime) {
      setState(() {
        _displayTime = newTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayTime,
      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
    );
  }
}
