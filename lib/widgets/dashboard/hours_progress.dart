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

    // For the main progress indicator, use total hours
    final mainProgress = (totalHours / targetHours).clamp(0.0, 1.0);

    // Create a list of jobs with their hours and percentages
    final jobsWithPercentages =
        provider.jobs.map((job) {
          final hours = jobHours[job.id] ?? 0;
          final percentage = totalHours > 0 ? hours / totalHours : 0.0;
          return {'job': job, 'hours': hours, 'percentage': percentage};
        }).toList();

    // Sort jobs by hours (highest first)
    jobsWithPercentages.sort(
      (a, b) => (b['hours'] as int).compareTo(a['hours'] as int),
    );

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
                    child: CustomPaint(
                      painter: JobProgressPainter(
                        progress: mainProgress,
                        jobsWithPercentages: jobsWithPercentages,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      child: Container(),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalHours',
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
              Text(
                'Total Hours',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
              ...jobsWithPercentages.map((jobData) {
                final job = jobData['job'] as Job;
                final hours = jobData['hours'] as int;

                // Calculate progress relative to target hours instead of total hours
                final progressValue = (hours / targetHours).clamp(0.0, 1.0);

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
                              value: progressValue,
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

// Custom painter to draw the progress circle with job colors
class JobProgressPainter extends CustomPainter {
  final double progress;
  final List<Map<String, dynamic>> jobsWithPercentages;
  final Color backgroundColor;

  JobProgressPainter({
    required this.progress,
    required this.jobsWithPercentages,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;
    final innerRadius = radius - strokeWidth / 2;

    // Draw background circle
    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, innerRadius, backgroundPaint);

    // Draw colored segments for each job
    double startAngle =
        -90 * (3.14159 / 180); // Start from the top (in radians)

    for (var jobData in jobsWithPercentages) {
      final job = jobData['job'] as Job;
      final percentage = jobData['percentage'] as double;

      if (percentage > 0) {
        final sweepAngle = 2 * 3.14159 * percentage * progress;

        final paint =
            Paint()
              ..color = job.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.butt;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: innerRadius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );

        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
