import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';
import 'package:time_clock/models/job.dart';

class HoursProgress extends StatelessWidget {
  final int hoursWorked;
  final int targetHours;
  final String period;

  const HoursProgress({
    super.key,
    required this.hoursWorked,
    required this.targetHours,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);
    final jobHours = provider.getHoursWorkedByJob();
    final totalHours = jobHours.values.fold(0, (sum, hours) => sum + hours);

    // Ensure progress value is between 0.0 and 1.0
    final mainProgress = (hoursWorked / targetHours).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Main circular progress indicator
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: mainProgress,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        provider.selectedJob?.color ?? Colors.blue,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$hoursWorked',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'of $targetHours hours',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This $period',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (provider.selectedJob != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: provider.selectedJob!.color,
                      radius: 8,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.selectedJob!.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: provider.selectedJob!.color,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Job hours breakdown
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hours by Job',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...provider.jobs.map((job) {
                final hours = jobHours[job.id] ?? 0;
                // Ensure percentage is between 0.0 and 1.0
                final percentage =
                    totalHours > 0 ? (hours / totalHours).clamp(0.0, 1.0) : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: percentage,
                              strokeWidth: 4,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                job.color,
                              ),
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: job.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$hours hrs',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }
}
