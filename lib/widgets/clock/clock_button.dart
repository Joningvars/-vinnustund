import 'package:flutter/material.dart';
import 'package:timagatt/models/job.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class ClockButton extends StatelessWidget {
  final bool isClockedIn;
  final bool isOnBreak;
  final Job? selectedJob;
  final VoidCallback onPressed;
  final VoidCallback onBreakPressed;

  const ClockButton({
    super.key,
    required this.isClockedIn,
    required this.isOnBreak,
    required this.selectedJob,
    required this.onPressed,
    required this.onBreakPressed,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Define colors based on mode and state
    final Color backgroundColor =
        isDarkMode
            ? isClockedIn
                ? isOnBreak
                    ? Colors
                        .amber
                        .shade700 // Dark amber for break in dark mode
                    : Colors
                        .red
                        .shade700 // Dark red for clocked in dark mode
                : Theme.of(context)
                    .colorScheme
                    .primary // Use tertiary (green) from theme
            : isClockedIn
            ? isOnBreak
                ? Colors
                    .amber
                    .shade50 // Light amber for break in light mode
                : Colors
                    .red
                    .shade50 // Light red for clocked in light mode
            : Colors.green.shade50; // Light green for clocked out light mode

    // Text color based on mode
    final Color textColor =
        isDarkMode
            ? Colors
                .white // Always white text in dark mode
            : isClockedIn
            ? isOnBreak
                ? Colors.amber.shade700
                : Colors.red
            : Colors.green;

    // Icon color based on mode
    final Color iconColor =
        isDarkMode
            ? Colors
                .white // Always white icons in dark mode
            : isClockedIn
            ? isOnBreak
                ? Colors.amber.shade700
                : Colors.red
            : Colors.green.shade700;

    // Job text color
    final Color jobTextColor =
        isDarkMode
            ? Colors
                .grey
                .shade300 // Lighter grey in dark mode for better visibility
            : Colors.grey.shade600;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        provider.context ??= context;
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          // Add subtle shadow in dark mode for depth
          boxShadow:
              isDarkMode
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClockedIn
                      ? isOnBreak
                          ? provider.translate('onBreak')
                          : provider.translate('clockOut')
                      : provider.translate('clockIn'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (selectedJob != null)
                  Text(
                    selectedJob!.name,
                    style: TextStyle(color: jobTextColor),
                  ),
              ],
            ),
            Row(
              children: [
                // Add timer display when clocked in
                if (isClockedIn)
                  TimerDisplay(
                    startTime: provider.clockInTime,
                    breakStartTime: provider.breakStartTime,
                    isOnBreak: isOnBreak,
                    textColor: textColor,
                  ),

                // Break button (only visible when clocked in)
                if (isClockedIn)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onBreakPressed();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        isOnBreak
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: iconColor,
                        size: 42,
                      ),
                    ),
                  ),

                // Main clock icon
                Icon(
                  isClockedIn ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: iconColor,
                  size: 42,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Create a stateful timer display widget
class TimerDisplay extends StatefulWidget {
  final DateTime? startTime;
  final DateTime? breakStartTime;
  final bool isOnBreak;
  final Color textColor;

  const TimerDisplay({
    Key? key,
    required this.startTime,
    required this.breakStartTime,
    required this.isOnBreak,
    required this.textColor,
  }) : super(key: key);

  @override
  State<TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<TimerDisplay> {
  Timer? _timer;
  String _timeText = "00:00:00";

  @override
  void initState() {
    super.initState();
    _updateTimeText();
    _startTimer();
  }

  @override
  void didUpdateWidget(TimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTimeText();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateTimeText();
        });
      }
    });
  }

  void _updateTimeText() {
    if (widget.startTime == null) {
      _timeText = "00:00:00";
      return;
    }

    Duration elapsed;
    if (widget.isOnBreak && widget.breakStartTime != null) {
      // If on break, show the elapsed time up to the break
      elapsed = widget.breakStartTime!.difference(widget.startTime!);
    } else {
      // Otherwise show current elapsed time
      elapsed = DateTime.now().difference(widget.startTime!);
    }

    // Format the elapsed time as HH:MM:SS
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    _timeText = '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Text(
        _timeText,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: widget.textColor,
        ),
      ),
    );
  }
}
