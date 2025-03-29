import 'package:flutter/material.dart';
import 'package:timagatt/models/job.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final provider = Provider.of<TimeEntriesProvider>(context, listen: false);
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

        if (provider.isClockedIn) {
          // Set the clock out time before showing the dialog
          provider.clockOutTime = DateTime.now();

          // Show confirmation dialog when clocking out
          _showWorkDescriptionDialog(context);
        } else {
          // Just clock in directly
          onPressed();
        }
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

  void _showWorkDescriptionDialog(BuildContext context) {
    final TextEditingController descriptionController = TextEditingController();
    final provider = Provider.of<TimeEntriesProvider>(context, listen: false);

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
              color: Theme.of(context).colorScheme.surface,
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
                  provider.translate('workDescription'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  provider.translate('workDescriptionHint'),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Text field
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: provider.translate('enterWorkDescription'),
                    filled: true,
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
                        provider.isClockedIn = false;
                        provider.clockInTime = null;
                        provider.clockOutTime = null;
                        provider.breakStartTime = null;
                        provider.notifyListeners();

                        Navigator.of(context).pop();
                      },
                      child: Text(
                        provider.translate('cancel'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();

                        // Check if required values are not null
                        if (provider.selectedJob == null ||
                            provider.clockInTime == null ||
                            provider.clockOutTime == null) {
                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                provider.translate('errorSavingEntry'),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          Navigator.of(context).pop();
                          return;
                        }

                        // Create the time entry with description
                        final entry = TimeEntry(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          jobId: provider.selectedJob!.id,
                          jobName: provider.selectedJob!.name,
                          jobColor: provider.selectedJob!.color,
                          clockInTime: provider.clockInTime!,
                          clockOutTime: provider.clockOutTime!,
                          duration: provider.clockOutTime!.difference(
                            provider.clockInTime!,
                          ),
                          description: descriptionController.text,
                          date: DateFormat(
                            'yyyy-MM-dd',
                          ).format(provider.clockInTime!),
                          userId: FirebaseAuth.instance.currentUser?.uid,
                        );

                        // Save the entry (this handles adding to local list, saving to Firebase, and local storage)
                        provider.saveTimeEntry(entry);

                        // Reset clock state
                        provider.isClockedIn = false;
                        provider.isOnBreak = false;
                        provider.clockInTime = null;
                        provider.clockOutTime = null;
                        provider.breakStartTime = null;

                        // Update calculations
                        provider.calculateHoursWorkedThisWeek();

                        // Notify listeners
                        provider.notifyListeners();

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
                      child: Text(provider.translate('submit')),
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
