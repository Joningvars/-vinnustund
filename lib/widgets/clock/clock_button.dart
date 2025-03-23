import 'package:flutter/material.dart';
import 'package:time_clock/models/job.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';
import 'package:flutter/services.dart';

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

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isClockedIn) {
          // Set the context before showing the dialog
          provider.context = context;
        }
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isClockedIn
                  ? isOnBreak
                      ? Colors.amber.shade50
                      : Colors.red.shade50
                  : Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
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
                    color:
                        isClockedIn
                            ? isOnBreak
                                ? Colors.amber.shade700
                                : Colors.red
                            : Colors.green,
                  ),
                ),
                if (selectedJob != null)
                  Text(
                    selectedJob!.name,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
              ],
            ),
            Row(
              children: [
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
                        color: isOnBreak ? Colors.amber.shade700 : Colors.red,
                        size: 42,
                      ),
                    ),
                  ),

                // Main clock icon
                Icon(
                  isClockedIn ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color:
                      isClockedIn
                          ? isOnBreak
                              ? Colors.amber.shade700
                              : Colors.red
                          : Colors.green,
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
