import 'package:flutter/material.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/widgets/clock/clock_button.dart';
import 'package:timagatt/widgets/dashboard/hours_progress.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:timagatt/services/pdf_export_service.dart';
import 'package:intl/intl.dart';
import 'package:timagatt/widgets/add_job_button.dart';
import 'package:timagatt/widgets/common/styled_dropdown.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final jobsProvider = Provider.of<JobsProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // Add a recovery mechanism
    if (timeEntriesProvider.timeEntries.isEmpty &&
        !timeEntriesProvider.isRecoveryAttempted) {
      // Try to recover entries from Firebase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        timeEntriesProvider.loadTimeEntries();
      });
    }

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Text(
              timeEntriesProvider.formatDate(DateTime.now()),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              timeEntriesProvider.translate('hoursWorked'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                _buildPeriodSelector(
                  timeEntriesProvider.translate('today'),
                  timeEntriesProvider.selectedPeriod == 'Day',
                  timeEntriesProvider,
                  context,
                ),
                _buildPeriodSelector(
                  timeEntriesProvider.translate('week'),
                  timeEntriesProvider.selectedPeriod == 'Week',
                  timeEntriesProvider,
                  context,
                ),
                _buildPeriodSelector(
                  timeEntriesProvider.translate('month'),
                  timeEntriesProvider.selectedPeriod == 'Month',
                  timeEntriesProvider,
                  context,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<TimeEntry>>(
          stream: timeEntriesProvider.getTimeEntriesStream(),
          builder: (context, snapshot) {
            // Only process data when there's an actual change
            if (snapshot.hasData &&
                snapshot.connectionState == ConnectionState.active) {
              // Use a key to prevent infinite updates
              final entriesKey = snapshot.data!.fold<String>(
                '',
                (prev, entry) =>
                    '$prev${entry.id}:${entry.duration.inMinutes},',
              );

              // Only update if the entries have actually changed
              if (timeEntriesProvider.lastProcessedEntriesKey != entriesKey) {
                // Use a post-frame callback to avoid rebuilding during build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Update entries without triggering excessive calculations
                  timeEntriesProvider.updateTimeEntriesWithoutNotifying(
                    snapshot.data!,
                    entriesKey,
                  );

                  // Calculate hours only when entries change, not every second
                  timeEntriesProvider.calculateHoursWorkedThisWeek();
                });
              }
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hours progress
                          HoursProgress(
                            hoursWorked:
                                timeEntriesProvider
                                    .getHoursWorkedForSelectedJob(),
                            targetHours: calculatePeriodTarget(
                              timeEntriesProvider.selectedPeriod,
                              timeEntriesProvider.targetHours,
                            ),
                            period: timeEntriesProvider.selectedPeriod,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildJobSelector(jobsProvider, context),
                  ),

                  Container(
                    margin: const EdgeInsets.all(16.0),
                    child: ClockButton(
                      onBreakPressed: timeEntriesProvider.toggleBreak,
                      isClockedIn: timeEntriesProvider.isClockedIn,
                      isOnBreak: timeEntriesProvider.isOnBreak,
                      selectedJob: timeEntriesProvider.selectedJob,
                      onPressed: () {
                        if (timeEntriesProvider.isClockedIn) {
                          timeEntriesProvider.clockOut(context);
                        } else {
                          timeEntriesProvider.clockIn(context);
                        }
                      },
                    ),
                  ),
                  // Recent time entries section
                  Container(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                timeEntriesProvider.translate('recentEntries'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Navigate to the history tab (index 2)
                                  timeEntriesProvider.setSelectedTabIndex(2);
                                },
                                child: Text(
                                  timeEntriesProvider.translate('viewAll'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildRecentEntries(context, timeEntriesProvider),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
    String text,
    bool isSelected,
    TimeEntriesProvider provider,
    BuildContext context,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          provider.setState(() {
            provider.selectedPeriod =
                text == provider.translate('today')
                    ? 'Day'
                    : text == provider.translate('week')
                    ? 'Week'
                    : 'Month';
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : isDarkMode
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Widget _buildJobSelector(JobsProvider jobsProvider, BuildContext context) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    // Combine regular and shared jobs for selection
    final allJobs = [...jobsProvider.jobs, ...jobsProvider.sharedJobs];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            settingsProvider.translate('selectJob'),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
        StyledDropdown<Job>(
          value:
              timeEntriesProvider.selectedJob ??
              (allJobs.isNotEmpty ? allJobs.first : null),
          onChanged: (Job? newValue) {
            if (newValue != null) {
              timeEntriesProvider.selectedJob = newValue;
              jobsProvider.setSelectedJob(newValue);
            }
          },
          items:
              allJobs.map<DropdownMenuItem<Job>>((Job job) {
                return DropdownMenuItem<Job>(
                  key: ValueKey(job.id),
                  value: job,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: job.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(job.name),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentEntries(
    BuildContext context,
    TimeEntriesProvider provider,
  ) {
    // Get the most recent entries (limit to 3)
    final recentEntries =
        provider.timeEntries
            .where(
              (entry) => entry.clockOutTime != null,
            ) // Ensure completed entries
            .toList();

    // Sort by most recent first
    recentEntries.sort((a, b) => b.clockOutTime.compareTo(a.clockOutTime));

    final entriesToShow = recentEntries.take(3).toList();

    if (entriesToShow.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            provider.translate('noEntries'),
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      children:
          entriesToShow
              .map((entry) => _buildRecentEntry(entry, provider))
              .toList(),
    );
  }

  Widget _buildRecentEntry(TimeEntry entry, TimeEntriesProvider provider) {
    final job = provider.getJobById(entry.jobId);
    final hours = entry.duration.inHours;
    final minutes = entry.duration.inMinutes % 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Job color indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: job?.color ?? Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // Job name and date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job?.name ?? provider.translate('unknownJob'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd(
                      provider.locale.languageCode,
                    ).format(entry.clockInTime),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Duration
            Text(
              '$hours ${provider.translate('klst')} $minutes ${provider.translate('mín')}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteJobDialog(
    BuildContext context,
    JobsProvider jobsProvider,
    Job job,
  ) {
    // Unfocus any text field to dismiss keyboard
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
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
              color: Theme.of(context).cardColor,
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
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  jobsProvider.translate('deleteJob'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  jobsProvider.translate('deleteJobConfirm'),
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        jobsProvider.translate('cancel'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        jobsProvider.deleteJob(job.id);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(jobsProvider.translate('delete')),
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

  int calculatePeriodTarget(String period, int monthlyTarget) {
    if (period == 'Day') {
      // Assuming 22 working days per month
      return (monthlyTarget / 22).round();
    } else if (period == 'Week') {
      // Assuming 4.33 weeks per month
      return (monthlyTarget / 4.33).round();
    }
    return monthlyTarget; // For 'Month'
  }
}

class AnimatedJobButton extends StatefulWidget {
  final Job job;
  final bool isSelected;
  final VoidCallback onTap;

  const AnimatedJobButton({
    Key? key,
    required this.job,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  State<AnimatedJobButton> createState() => _AnimatedJobButtonState();
}

class _AnimatedJobButtonState extends State<AnimatedJobButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    widget.isSelected
                        ? widget.job.color.withOpacity(0.2)
                        : Colors.grey.shade100,
                border: Border.all(
                  color:
                      widget.isSelected
                          ? widget.job.color
                          : Colors.grey.shade300,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.job.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.job.name,
                    style: TextStyle(
                      color:
                          widget.isSelected
                              ? widget.job.color
                              : Colors.grey.shade700,
                      fontWeight:
                          widget.isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void _showAddJobDialog(BuildContext context, JobsProvider jobsProvider) {
  final TextEditingController nameController = TextEditingController();
  Color selectedColor = Colors.blue;

  // List of colors to choose from
  final List<Color> colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
  ];

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              jobsProvider.translate('createJob'),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: jobsProvider.translate('jobName'),
                    labelStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(jobsProvider.translate('selectColor')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      colors.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedColor = color;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                      : null,
                            ),
                            child:
                                isSelected
                                    ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                    : null,
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  jobsProvider.translate('cancel'),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    jobsProvider.addJob(
                      nameController.text,
                      selectedColor,
                      null,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  jobsProvider.translate('create'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
