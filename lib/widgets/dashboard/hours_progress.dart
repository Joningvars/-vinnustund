import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:timagatt/models/job.dart';
import 'dart:math' as math;

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

    // Calculate job hours directly from the time entries
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    // Calculate hours by job for the selected period
    final Map<String, int> jobHours = {};
    int totalMinutes = 0;

    for (var entry in provider.timeEntries) {
      if (entry.clockInTime.isAfter(startDate)) {
        // Add to job-specific hours
        if (!jobHours.containsKey(entry.jobId)) {
          jobHours[entry.jobId] = 0;
        }
        jobHours[entry.jobId] =
            jobHours[entry.jobId]! + entry.duration.inMinutes;

        // Add to total minutes
        totalMinutes += entry.duration.inMinutes;
      }
    }

    // Convert minutes to hours
    final totalHours = totalMinutes ~/ 60;
    print('Total hours calculated: $totalHours');

    // Convert job minutes to hours
    final jobHoursConverted = Map<String, int>.fromEntries(
      jobHours.entries.map((e) => MapEntry(e.key, e.value ~/ 60)),
    );

    // For the main progress indicator, use total hours
    final mainProgress = (totalHours / targetHours).clamp(0.0, 1.0);

    // Create a list of jobs with their hours and percentages
    final jobsWithPercentages =
        provider.jobs.map((job) {
          final hours = jobHoursConverted[job.id] ?? 0;
          final percentage = totalHours > 0 ? hours / totalHours : 0.0;
          return {'job': job, 'hours': hours, 'percentage': percentage};
        }).toList();

    // Sort jobs by hours (highest first)
    jobsWithPercentages.sort(
      (a, b) => (b['hours'] as int).compareTo(a['hours'] as int),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: AnimatedJobProgressPainter(
                      progress: mainProgress,
                      jobsWithPercentages: jobsWithPercentages,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: totalHours),
                        duration: const Duration(milliseconds: 750),
                        builder: (context, value, child) {
                          return Text(
                            '$value',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      Text(
                        '${provider.translate('of')} $targetHours ${provider.translate('hours')}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.getPeriodText(period),
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
                provider.translate('totalHours'),
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
              Text(
                provider.translate('hoursbyJob'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
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

// Add this class to create an animated progress painter
class AnimatedJobProgressPainter extends StatefulWidget {
  final List<Map<String, dynamic>> jobsWithPercentages;
  final double progress;
  final Color backgroundColor;

  const AnimatedJobProgressPainter({
    super.key,
    required this.jobsWithPercentages,
    required this.progress,
    required this.backgroundColor,
  });

  @override
  State<AnimatedJobProgressPainter> createState() =>
      _AnimatedJobProgressPainterState();
}

class _AnimatedJobProgressPainterState extends State<AnimatedJobProgressPainter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _oldProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _oldProgress = widget.progress;
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedJobProgressPainter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _oldProgress = oldWidget.progress;
      _progressAnimation = Tween<double>(
        begin: _oldProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: JobProgressPainter(
            jobsWithPercentages: widget.jobsWithPercentages,
            progress: _progressAnimation.value,
            backgroundColor: widget.backgroundColor,
          ),
          child: Container(),
        );
      },
    );
  }
}
