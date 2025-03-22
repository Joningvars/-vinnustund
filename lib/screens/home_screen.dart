import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_clock/models/job.dart';
import 'package:time_clock/models/time_entry.dart';
import 'package:time_clock/widgets/clock/clock_button.dart';
import 'package:time_clock/widgets/dashboard/hours_progress.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Text(
                DateFormat('MMMM d, yyyy').format(DateTime.now()),
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
                targetHours: provider.targetHours,
                period: provider.selectedPeriod,
              ),

              const SizedBox(height: 24),

              // Job selector
              _buildJobSelector(provider, context),

              const SizedBox(height: 16),

              // Clock in/out section with integrated break button
              ClockButton(
                isClockedIn: provider.isClockedIn,
                isOnBreak: provider.isOnBreak,
                selectedJob: provider.selectedJob,
                onPressed:
                    provider.isClockedIn ? provider.clockOut : provider.clockIn,
                onBreakPressed: provider.toggleBreak,
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
                      // Navigate to history tab
                      DefaultTabController.of(context).animateTo(2);
                    },
                    child: Text(provider.translate('viewAll')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...provider.timeEntries
                  .take(3)
                  .map((entry) => _buildTimeEntryCard(entry, provider))
                  .toList(),
            ],
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          provider.translate('selectJob'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? job.color.withOpacity(0.2)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? job.color : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isSelected ? job.color : Colors.grey.shade700,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      child: Text(job.name),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeEntryCard(TimeEntry entry, TimeClockProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: entry.jobColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.jobName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(entry.clockInTime),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  provider.formatDuration(entry.duration),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('h:mm a').format(entry.clockInTime)} - ${DateFormat('h:mm a').format(entry.clockOutTime)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
