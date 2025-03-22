import 'package:flutter/material.dart';
import 'package:time_clock/models/job.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';

class ClockButton extends StatelessWidget {
  final bool isClockedIn;
  final Job? selectedJob;
  final VoidCallback onPressed;

  const ClockButton({
    super.key,
    required this.isClockedIn,
    required this.selectedJob,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context, listen: false);

    return GestureDetector(
      onTap: () {
        if (isClockedIn) {
          // Set the context before showing the dialog
          provider.context = context;
        }
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isClockedIn ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClockedIn ? 'Clock Out' : 'Clock In',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isClockedIn ? Colors.red : Colors.green,
                  ),
                ),
                if (selectedJob != null)
                  Text(
                    selectedJob!.name,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
              ],
            ),
            Icon(
              isClockedIn ? Icons.logout : Icons.login,
              color: isClockedIn ? Colors.red : Colors.green,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
