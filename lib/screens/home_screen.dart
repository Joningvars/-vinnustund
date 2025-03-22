import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_clock/models/job.dart';
import 'package:time_clock/models/time_entry.dart';
import 'package:time_clock/widgets/clock/clock_button.dart';
import 'package:time_clock/widgets/clock/break_button.dart';
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
              const Text(
                'Hours Worked',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              // Period selector
              Row(
                children: [
                  _buildPeriodSelector(
                    'Day',
                    provider.selectedPeriod == 'Day',
                    provider,
                    context,
                  ),
                  _buildPeriodSelector(
                    'Week',
                    provider.selectedPeriod == 'Week',
                    provider,
                    context,
                  ),
                  _buildPeriodSelector(
                    'Month',
                    provider.selectedPeriod == 'Month',
                    provider,
                    context,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Hours progress
              Center(
                child: HoursProgress(
                  hoursWorked: provider.getHoursWorkedForSelectedJob(),
                  targetHours: provider.targetHours,
                  period: provider.selectedPeriod,
                ),
              ),

              const SizedBox(height: 32),

              // Job selection
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
              _buildRecentEntries(provider, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
    String title,
    bool isSelected,
    TimeClockProvider provider,
    BuildContext context,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          provider.setState(() {
            provider.selectedPeriod = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobSelector(TimeClockProvider provider, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Job',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Simple list of job buttons
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              provider.jobs.map((job) {
                final isSelected = provider.selectedJob?.id == job.id;
                final isDisabled = provider.isClockedIn;

                return InkWell(
                  onTap:
                      isDisabled
                          ? () {
                            // Show a message that job can't be changed while clocked in
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cannot change job while clocked in',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          : () {
                            provider.selectedJob = job;
                            provider.notifyListeners();
                          },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: MediaQuery.of(context).size.width / 2 - 21,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? job.color.withOpacity(0.2)
                              : isDisabled
                              ? Colors.grey.shade200
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          isSelected
                              ? Border.all(color: job.color, width: 1)
                              : null,
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: job.color.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Opacity(
                      opacity: isDisabled && !isSelected ? 0.6 : 1.0,
                      child: Row(
                        children: [
                          // Color circle with more space
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: job.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: job.color.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child:
                                isSelected
                                    ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              job.name,
                              style: TextStyle(
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color:
                                    isSelected
                                        ? job.color
                                        : isDisabled
                                        ? Colors.grey.shade600
                                        : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentEntries(TimeClockProvider provider, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Entries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...provider.timeEntries
            .take(3)
            .map((entry) => _buildTimeEntryCard(entry, provider)),
      ],
    );
  }

  Widget _buildTimeEntryCard(TimeEntry entry, TimeClockProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: entry.jobColor,
              child: Text(
                entry.jobName.substring(0, 1),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(entry.jobName),
            subtitle: Text(entry.formattedDate),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.formattedDuration,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${entry.formattedClockIn} - ${entry.formattedClockOut}'),
              ],
            ),
          ),
          if (entry.description != null && entry.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 4),
                  const Text(
                    'Description:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.description!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
