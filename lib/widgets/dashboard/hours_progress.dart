import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';

class HoursProgress extends StatefulWidget {
  final double hoursWorked;
  final int targetHours;
  final String period;

  const HoursProgress({
    super.key,
    required this.hoursWorked,
    required this.targetHours,
    required this.period,
  });

  @override
  State<HoursProgress> createState() => _HoursProgressState();
}

class _HoursProgressState extends State<HoursProgress>
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
    _updateAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(HoursProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hoursWorked != widget.hoursWorked ||
        oldWidget.targetHours != widget.targetHours ||
        oldWidget.period != widget.period) {
      _updateAnimation();
      _controller.forward(from: 0.0);
    }
  }

  void _updateAnimation() {
    final progress =
        widget.targetHours > 0
            ? (widget.hoursWorked / widget.targetHours).clamp(0.0, 1.0)
            : 0.0;

    _progressAnimation = Tween<double>(
      begin: _oldProgress,
      end: progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Update old progress after animation is set up
    _oldProgress = progress;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeProvider = Provider.of<TimeEntriesProvider>(context);
    final jobsProvider = Provider.of<JobsProvider>(context);

    // Calculate job hours based on selected period
    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (widget.period) {
      case 'Day':
        startDate = DateTime(endDate.year, endDate.month, endDate.day);
        break;
      case 'Week':
        startDate = endDate.subtract(Duration(days: endDate.weekday - 1));
        break;
      case 'Month':
        startDate = DateTime(endDate.year, endDate.month, 1);
        break;
      default:
        startDate = endDate.subtract(const Duration(days: 30));
    }

    // Calculate job hours
    final jobHours = timeProvider.getHoursByJobInPeriod(startDate, endDate);

    // Create a list of jobs with their hours and percentages
    final jobsWithPercentages =
        jobHours.entries.map((entry) {
          // Get the first time entry for this job to get its name and color
          final jobEntry = timeProvider.timeEntries.firstWhere(
            (e) => e.jobId == entry.key,
            orElse:
                () => TimeEntry(
                  id: '',
                  jobId: entry.key,
                  jobName: 'Unknown Job',
                  jobColor: Colors.grey,
                  clockInTime: DateTime.now(),
                  clockOutTime: DateTime.now(),
                  duration: const Duration(),
                  date: DateTime.now(),
                  userId: '',
                ),
          );

          return {
            'job': Job(
              id: entry.key,
              name: jobEntry.jobName,
              color: jobEntry.jobColor,
            ),
            'hours': entry.value,
            'percentage':
                widget.targetHours > 0
                    ? (entry.value / widget.targetHours).clamp(0.0, 1.0)
                    : 0.0,
          };
        }).toList();

    // Sort jobs by hours (highest first)
    jobsWithPercentages.sort(
      (a, b) => (b['hours'] as double).compareTo(a['hours'] as double),
    );

    return Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Main circular progress indicator
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: JobProgressPainter(
                              progress: _progressAnimation.value,
                              jobsWithPercentages: jobsWithPercentages,
                              backgroundColor: Colors.grey.shade200,
                            ),
                            child: Container(),
                          );
                        },
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: widget.hoursWorked,
                          ),
                          duration: const Duration(milliseconds: 750),
                          builder: (context, value, child) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        Text(
                          '${timeProvider.translate('of')} ${widget.targetHours} ${timeProvider.translate('hours')}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeProvider.translate(widget.period.toLowerCase()),
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
                  timeProvider.translate('totalHours'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Job hours breakdown
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeProvider.translate('hoursbyJob'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...jobsWithPercentages.map((jobData) {
                  final job = jobData['job'] as Job;
                  final hours = jobData['hours'] as double;
                  final progressValue = jobData['percentage'] as double;

                  return AnimatedJobProgressItem(
                    job: job,
                    hours: hours,
                    progress: progressValue,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedJobProgressItem extends StatefulWidget {
  final Job job;
  final double hours;
  final double progress;

  const AnimatedJobProgressItem({
    Key? key,
    required this.job,
    required this.hours,
    required this.progress,
  }) : super(key: key);

  @override
  State<AnimatedJobProgressItem> createState() =>
      _AnimatedJobProgressItemState();
}

class _AnimatedJobProgressItemState extends State<AnimatedJobProgressItem>
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
    _updateAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedJobProgressItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _updateAnimation();
      _controller.forward(from: 0.0);
    }
  }

  void _updateAnimation() {
    _progressAnimation = Tween<double>(
      begin: _oldProgress,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _oldProgress = widget.progress;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: _progressAnimation.value,
                      strokeWidth: 4,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.job.color,
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.job.color,
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
                  widget.job.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.hours.toStringAsFixed(1)} hrs',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
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

    // Draw background circle
    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    // Draw colored segments for each job
    double startAngle =
        -90 * (3.14159 / 180); // Start from the top (in radians)

    if (jobsWithPercentages.isNotEmpty) {
      // Calculate total percentage to ensure we don't exceed the progress
      double totalPercentage = 0;
      for (final jobData in jobsWithPercentages) {
        totalPercentage += (jobData['percentage'] as double);
      }

      // Scale factor to ensure we don't exceed the progress
      final scaleFactor = totalPercentage > 0 ? progress / totalPercentage : 0;

      for (final jobData in jobsWithPercentages) {
        final job = jobData['job'] as Job;
        final percentage = (jobData['percentage'] as double) * scaleFactor;

        final sweepAngle = percentage * 2 * 3.14159;

        final jobPaint =
            Paint()
              ..color = job.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          startAngle,
          sweepAngle,
          false,
          jobPaint,
        );

        startAngle += sweepAngle;
      }
    } else {
      // If no job data, just draw a single progress arc
      final progressPaint =
          Paint()
            ..color =
                progress < 0.3
                    ? Colors.red
                    : progress < 0.7
                    ? Colors.orange
                    : Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -90 * (3.14159 / 180),
        progress * 2 * 3.14159,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(JobProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
