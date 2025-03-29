import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobOverviewScreen extends StatefulWidget {
  final Job job;

  const JobOverviewScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<JobOverviewScreen> createState() => _JobOverviewScreenState();
}

class _JobOverviewScreenState extends State<JobOverviewScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedUserId;
  List<String> _userIds = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
        context,
        listen: false,
      );

      // Load all entries for this job
      await timeEntriesProvider.loadAllEntriesForJob(widget.job.id);

      // Get unique user IDs from entries
      final entries = timeEntriesProvider.getAllEntriesForJob(widget.job.id);
      final userIds =
          entries
              .where((e) => e.userId != null)
              .map((e) => e.userId!)
              .toSet()
              .toList();

      // Get user names
      if (userIds.isNotEmpty) {
        _userNames = await timeEntriesProvider.getUserNames(userIds);

        // Update entries with missing userNames
        for (var entry in entries.where((e) => e.userName == null)) {
          if (entry.userId != null && _userNames.containsKey(entry.userId)) {
            // Create updated entry with userName
            final updatedEntry = TimeEntry(
              id: entry.id,
              jobId: entry.jobId,
              jobName: entry.jobName,
              jobColor: entry.jobColor,
              clockInTime: entry.clockInTime,
              clockOutTime: entry.clockOutTime,
              duration: entry.duration,
              description: entry.description,
              userId: entry.userId,
              userName: _userNames[entry.userId],
            );

            // Update the entry
            await timeEntriesProvider.updateTimeEntry(updatedEntry);
          }
        }
      }

      // Set default user filter to current user
      _selectedUserId = FirebaseAuth.instance.currentUser?.uid;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading job data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = DateTimeRange(start: _startDate, end: _endDate);

    final pickedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.job.color,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDateRange != null) {
      setState(() {
        _startDate = pickedDateRange.start;
        _endDate = pickedDateRange.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final jobsProvider = Provider.of<JobsProvider>(context);
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = widget.job.creatorId == currentUserId;

    // Format dates
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();

    // Get filtered entries
    final allEntries = timeEntriesProvider.getAllEntriesForJob(widget.job.id);

    // Filter by date range
    final entriesInDateRange =
        allEntries.where((entry) {
          return entry.clockInTime.isAfter(_startDate) &&
              entry.clockInTime.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

    // Filter by selected user if applicable
    final entries =
        _selectedUserId != null
            ? entriesInDateRange
                .where((e) => e.userId == _selectedUserId)
                .toList()
            : entriesInDateRange;

    // Sort by date (newest first)
    entries.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));

    // Calculate total hours
    final totalHours = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.durationInHours,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.name),
        backgroundColor: widget.job.color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Navigate to edit job screen
                Navigator.pushNamed(
                  context,
                  '/edit_job',
                  arguments: {'job': widget.job},
                );
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Header with job info
                  Container(
                    color: widget.job.color.withOpacity(0.1),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Job details
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: widget.job.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.job.name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (widget.job.description != null)
                                    Text(
                                      widget.job.description!,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Date range selector
                        InkWell(
                          onTap: _selectDateRange,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.date_range, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // User filter dropdown
                        if (_userIds.length > 1)
                          DropdownButtonFormField<String?>(
                            value: _selectedUserId,
                            decoration: InputDecoration(
                              labelText: timeEntriesProvider.translate(
                                'filterByUser',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  timeEntriesProvider.translate('allUsers'),
                                ),
                              ),
                              ..._userIds.map((userId) {
                                return DropdownMenuItem<String?>(
                                  value: userId,
                                  child: Text(_userNames[userId] ?? userId),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedUserId = value;
                              });
                            },
                          ),

                        const SizedBox(height: 16),

                        // Total hours
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                timeEntriesProvider.translate('totalHours'),
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                '${totalHours.toStringAsFixed(1)} ${timeEntriesProvider.translate('hours')}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Entries list
                  Expanded(
                    child:
                        entries.isEmpty
                            ? Center(
                              child: Text(
                                timeEntriesProvider.translate('noEntries'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            )
                            : ListView.builder(
                              itemCount: entries.length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final userName =
                                    entry.userName ??
                                    _userNames[entry.userId] ??
                                    'Unknown User';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header row with date and user name
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 16,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  DateFormat.yMMMd().format(
                                                    entry.clockInTime,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person,
                                                  size: 16,
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .secondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  userName,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .secondary,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Time information
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${timeFormat.format(entry.clockInTime)} - ${timeFormat.format(entry.clockOutTime ?? DateTime.now())}',
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${entry.durationInHours.toStringAsFixed(1)} ${timeEntriesProvider.translate('hours')}',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          theme
                                                              .colorScheme
                                                              .primary,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Description if available
                                        if (entry.description != null &&
                                            entry.description!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.description,
                                                size: 16,
                                                color: Colors.grey.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  entry.description!,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade700,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }

  void _showEditEntryDialog(TimeEntry entry) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    // Create controllers with initial values
    final descriptionController = TextEditingController(
      text: entry.description,
    );

    // Initial time values
    TimeOfDay startTime = TimeOfDay(
      hour: entry.clockInTime.hour,
      minute: entry.clockInTime.minute,
    );

    TimeOfDay endTime = TimeOfDay(
      hour: entry.clockOutTime?.hour ?? DateTime.now().hour,
      minute: entry.clockOutTime?.minute ?? DateTime.now().minute,
    );

    // Selected date
    DateTime selectedDate = DateTime(
      entry.clockInTime.year,
      entry.clockInTime.month,
      entry.clockInTime.day,
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(timeEntriesProvider.translate('editTimeEntry')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    ListTile(
                      title: Text(timeEntriesProvider.translate('date')),
                      subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),

                    const Divider(),

                    // Start time picker
                    ListTile(
                      title: Text(timeEntriesProvider.translate('startTime')),
                      subtitle: Text(startTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (time != null) {
                          setState(() {
                            startTime = time;
                          });
                        }
                      },
                    ),

                    // End time picker
                    ListTile(
                      title: Text(timeEntriesProvider.translate('endTime')),
                      subtitle: Text(endTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (time != null) {
                          setState(() {
                            endTime = time;
                          });
                        }
                      },
                    ),

                    const Divider(),

                    // Description field
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: timeEntriesProvider.translate('description'),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(timeEntriesProvider.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Create updated entry
                    final updatedEntry = TimeEntry(
                      id: entry.id,
                      jobId: entry.jobId,
                      jobName: entry.jobName,
                      jobColor: entry.jobColor,
                      clockInTime: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        startTime.hour,
                        startTime.minute,
                      ),
                      clockOutTime: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        endTime.hour,
                        endTime.minute,
                      ),
                      duration: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        endTime.hour,
                        endTime.minute,
                      ).difference(
                        DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          startTime.hour,
                          startTime.minute,
                        ),
                      ),
                      description: descriptionController.text,
                      userId: entry.userId,
                    );

                    try {
                      await timeEntriesProvider.updateTimeEntry(updatedEntry);
                      Navigator.pop(context);

                      // Refresh data
                      _loadData();

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            timeEntriesProvider.translate('timeEntryUpdated'),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text(timeEntriesProvider.translate('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteEntry(TimeEntry entry) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(timeEntriesProvider.translate('deleteEntry')),
            content: Text(timeEntriesProvider.translate('deleteEntryConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(timeEntriesProvider.translate('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await timeEntriesProvider.deleteTimeEntry(entry.id);

                    // Refresh data
                    _loadData();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          timeEntriesProvider.translate('timeEntryDeleted'),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(timeEntriesProvider.translate('delete')),
              ),
            ],
          ),
    );
  }
}
