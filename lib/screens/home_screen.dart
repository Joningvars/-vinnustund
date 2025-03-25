import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/widgets/clock/clock_button.dart';
import 'package:timagatt/widgets/dashboard/hours_progress.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);
    // Add a recovery mechanism
    if (provider.timeEntries.isEmpty && !provider.isRecoveryAttempted) {
      // Try to recover entries from Firebase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.mergeTimeEntries();
        provider.isRecoveryAttempted = true;
      });
    }

    // Add a recovery mechanism
    if (provider.timeEntries.isEmpty && !provider.isRecoveryAttempted) {
      // Try to recover entries from Firebase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.mergeTimeEntries();
        provider.isRecoveryAttempted = true;
      });
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<TimeEntry>>(
          stream: provider.getTimeEntriesStream(),
          builder: (context, snapshot) {
            // When the stream updates, update the timeEntries list without notifying
            if (snapshot.hasData) {
              // Update the entries without triggering a rebuild
              provider.updateTimeEntriesWithoutNotifying(snapshot.data!);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Text(
                    provider.formatDate(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.translate('hoursWorked'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Period selector
                  Row(
                    children: [
                      _buildPeriodSelector(
                        provider.translate('today'),
                        provider.selectedPeriod == 'Day',
                        provider,
                        context,
                      ),
                      _buildPeriodSelector(
                        provider.translate('week'),
                        provider.selectedPeriod == 'Week',
                        provider,
                        context,
                      ),
                      _buildPeriodSelector(
                        provider.translate('month'),
                        provider.selectedPeriod == 'Month',
                        provider,
                        context,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Hours progress
                  HoursProgress(
                    hoursWorked: provider.getHoursWorkedForSelectedJob(),
                    targetHours: calculatePeriodTarget(
                      provider.selectedPeriod,
                      provider.targetHours,
                    ),
                    period: provider.selectedPeriod,
                  ),

                  const SizedBox(height: 24),

                  // Job selector
                  _buildJobSelector(provider, context),

                  const SizedBox(height: 16),

                  // Clock in/out section with integrated break button
                  ClockButton(
                    onBreakPressed: provider.toggleBreak,
                    isClockedIn: provider.isClockedIn,
                    isOnBreak: provider.isOnBreak,
                    selectedJob: provider.selectedJob,
                    onPressed: () {
                      if (provider.isClockedIn) {
                        provider.clockOut();
                      } else {
                        provider.clockIn();
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // Recent time entries
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.translate('recentEntries'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to the history tab (index 2)
                          provider.setSelectedTabIndex(2);
                        },
                        child: Text(provider.translate('viewAll')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRecentEntries(context, provider),
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
    TimeClockProvider provider,
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
                    : Colors.transparent,
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

  Widget _buildJobSelector(TimeClockProvider provider, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              provider.translate('selectJob'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _showAddJobDialog(context, provider),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text(provider.translate('createJob')),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              provider.jobs.map((job) {
                final isSelected = provider.selectedJob?.id == job.id;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (provider.isClockedIn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(provider.translate('cannotChangeJob')),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      return;
                    }
                    provider.setSelectedJob(job);
                  },
                  onLongPress: () {
                    HapticFeedback.heavyImpact();
                    _showDeleteJobConfirmation(context, provider, job);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? job.color.withOpacity(0.2)
                              : isDarkMode
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected
                                ? job.color
                                : isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      job.name,
                      style: TextStyle(
                        color:
                            isSelected
                                ? job.color
                                : isDarkMode
                                ? Colors.grey.shade100
                                : Colors.grey.shade700,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  void _showAddJobDialog(BuildContext context, TimeClockProvider provider) {
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
                    Text(
                      provider.translate('createJob'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Job name field
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: provider.translate('jobName'),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Color selector
                    Text(
                      provider.translate('selectColor'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
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
                            if (nameController.text.trim().isNotEmpty) {
                              provider.addJob(
                                nameController.text.trim(),
                                selectedColor,
                              );
                              Navigator.of(context).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(provider.translate('create')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentEntries(BuildContext context, TimeClockProvider provider) {
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

  Widget _buildRecentEntry(TimeEntry entry, TimeClockProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: entry.jobColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.jobName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  provider.formatDuration(entry.duration),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${provider.formatTime(entry.clockInTime)} - ${provider.formatTime(entry.clockOutTime)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteJobConfirmation(
    BuildContext context,
    TimeClockProvider provider,
    Job job,
  ) {
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
                  provider.translate('deleteJob'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  provider.translate('deleteJobConfirm'),
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
                        provider.translate('cancel'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        provider.deleteJob(job.id);
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
                      child: Text(provider.translate('delete')),
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
