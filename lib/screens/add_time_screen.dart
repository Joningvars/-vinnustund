import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:flutter/services.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/widgets/add_job_button.dart';
import 'package:timagatt/widgets/common/custom_app_bar.dart';
import 'package:timagatt/widgets/common/styled_dropdown.dart';

class AddTimeScreen extends StatefulWidget {
  const AddTimeScreen({super.key});

  @override
  State<AddTimeScreen> createState() => _AddTimeScreenState();
}

class _AddTimeScreenState extends State<AddTimeScreen> {
  @override
  void initState() {
    super.initState();
    // Set default selected job when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TimeEntriesProvider>(context, listen: false);
      final jobsProvider = Provider.of<JobsProvider>(context, listen: false);
      final allJobs = [...jobsProvider.jobs, ...jobsProvider.sharedJobs];

      if (allJobs.isNotEmpty && provider.selectedJob == null) {
        provider.setSelectedJob(allJobs.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeEntriesProvider>(context);
    final jobsProvider = Provider.of<JobsProvider>(context);
    final theme = Theme.of(context);

    // Combine regular and shared jobs for selection
    final allJobs = [...jobsProvider.jobs, ...jobsProvider.sharedJobs];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: CustomAppBar(title: provider.translate('addTime')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Job selector
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('selectJob'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildJobSelector(context),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Time range selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date selector
                        Text(
                          provider.translate('date'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _selectDate(context, provider),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 24),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat.yMMMMd(
                                            provider.locale.languageCode,
                                          ).format(provider.selectedDate),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.translate('startTime'),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap:
                                        () =>
                                            _selectStartTime(context, provider),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.grey.shade900
                                                : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            provider.formatTime(
                                              DateTime(
                                                provider.selectedDate.year,
                                                provider.selectedDate.month,
                                                provider.selectedDate.day,
                                                provider.startTime.hour,
                                                provider.startTime.minute,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Icon(Icons.access_time),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.translate('endTime'),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap:
                                        () => _selectEndTime(context, provider),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.grey.shade900
                                                : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            provider.formatTime(
                                              DateTime(
                                                provider.selectedDate.year,
                                                provider.selectedDate.month,
                                                provider.selectedDate.day,
                                                provider.endTime.hour,
                                                provider.endTime.minute,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Icon(Icons.access_time),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTimeDisplay(provider),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Description field
                Text(
                  provider.translate('description'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: provider.descriptionController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).cardTheme.color,
                    hintText: provider.translate('workDescriptionHint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText:
                        '${provider.descriptionController.text.length}/200',
                  ),
                  maxLines: 3,
                  maxLength: 200,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) {
                    return Text(
                      '$currentLength/$maxLength',
                      style: TextStyle(
                        color:
                            currentLength >= maxLength!
                                ? Colors.red
                                : Colors.grey,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Add button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _submitTimeEntry(context, provider),
                    style: ElevatedButton.styleFrom(
                      textStyle: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(
                        inherit: false,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    child: Text(provider.translate('submit')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartTime(
    BuildContext context,
    TimeEntriesProvider provider,
  ) async {
    HapticFeedback.selectionClick();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: provider.startTime,
    );

    if (picked != null && picked != provider.startTime) {
      provider.startTime = picked;
      setState(() {});
    }
  }

  Future<void> _selectEndTime(
    BuildContext context,
    TimeEntriesProvider provider,
  ) async {
    HapticFeedback.selectionClick();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: provider.endTime,
    );

    if (picked != null && picked != provider.endTime) {
      provider.endTime = picked;
      setState(() {});
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TimeEntriesProvider provider,
  ) async {
    HapticFeedback.selectionClick();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != provider.selectedDate) {
      provider.selectedDate = picked;
      setState(() {});
    }
  }

  void _showAddJobDialog(BuildContext context, TimeEntriesProvider provider) {
    final TextEditingController nameController = TextEditingController();
    Color selectedColor = Colors.blue;

    // Get JobsProvider to add the job
    final jobsProvider = Provider.of<JobsProvider>(context, listen: false);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(provider.translate('createJob')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: provider.translate('jobName'),
                  ),
                ),
                // Color picker UI...
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(provider.translate('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    // Create a new Job object for the TimeEntriesProvider
                    final newJob = Job(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      color: selectedColor,
                    );

                    // Add job to JobsProvider with the new signature
                    jobsProvider.addJob(
                      nameController.text,
                      selectedColor,
                      null,
                    );

                    // Set as selected job in TimeEntriesProvider
                    provider.setSelectedJob(newJob);

                    Navigator.pop(context);
                  }
                },
                child: Text(
                  provider.translate('add'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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

  void _submitTimeEntry(
    BuildContext context,
    TimeEntriesProvider provider,
  ) async {
    print('🕒 Submitting time entry...');

    if (provider.selectedJob == null) {
      // Show a message to select a job
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.translate('selectJobFirst')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // Create start and end DateTimes
    final now = DateTime.now();
    final start = DateTime(
      provider.selectedDate.year,
      provider.selectedDate.month,
      provider.selectedDate.day,
      provider.startTime.hour,
      provider.startTime.minute,
    );

    final end = DateTime(
      provider.selectedDate.year,
      provider.selectedDate.month,
      provider.selectedDate.day,
      provider.endTime.hour,
      provider.endTime.minute,
    );

    // Handle case where end time is on the next day
    final adjustedEnd =
        end.isBefore(start) ? end.add(const Duration(days: 1)) : end;

    // Create time entry
    final entry = TimeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: provider.selectedJob!.id,
      jobName: provider.selectedJob!.name,
      jobColor: provider.selectedJob!.color,
      clockInTime: start,
      clockOutTime: adjustedEnd,
      duration: adjustedEnd.difference(start),
      description: provider.descriptionController.text,
      userId: provider.userId ?? '',
      date: start,
    );

    // Save to user's entries
    final success = await provider.addTimeEntry(entry);

    // If the job is shared, also try both direct methods
    if (success &&
        provider.selectedJob!.isShared &&
        provider.selectedJob!.connectionCode != null) {
      // Try the direct save method
      final directSaveResult = await provider.saveSharedJobEntry(
        entry,
        provider.selectedJob!.connectionCode!,
      );
      print('Direct save result: $directSaveResult');

      // Try the test write method
      final testWriteResult = await provider.testFirestoreWrite(
        entry,
        provider.selectedJob!.connectionCode!,
      );
      print('Test write result: $testWriteResult');
    }

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.translate('timeEntryAdded')),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        provider.descriptionController.clear();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding time entry'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Navigate to home screen and update the UI
    provider.calculateHoursWorkedThisWeek();
    provider.notifyListeners();

    // Navigate to home tab
    provider.setSelectedTabIndex(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildTimeDisplay(TimeEntriesProvider provider) {
    // Calculate duration between start and end time
    final startDateTime = DateTime(
      provider.selectedDate.year,
      provider.selectedDate.month,
      provider.selectedDate.day,
      provider.startTime.hour,
      provider.startTime.minute,
    );

    final endDateTime = DateTime(
      provider.selectedDate.year,
      provider.selectedDate.month,
      provider.selectedDate.day,
      provider.endTime.hour,
      provider.endTime.minute,
    );

    // Handle case where end time is on the next day
    final adjustedEndDateTime =
        endDateTime.isBefore(startDateTime)
            ? endDateTime.add(const Duration(days: 1))
            : endDateTime;

    final duration = adjustedEndDateTime.difference(startDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.access_time),
          const SizedBox(width: 8),
          Text(
            '$hours ${provider.translate('klst')} $minutes ${provider.translate('mín')}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSelector(BuildContext context) {
    final jobsProvider = Provider.of<JobsProvider>(context);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);

    // Combine regular and shared jobs for selection
    final allJobs = [...jobsProvider.jobs, ...jobsProvider.sharedJobs];

    return StyledDropdown<Job>(
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
    );
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
