import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<TimeEntry> _entries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<TimeEntriesProvider>(context, listen: false);

      if (widget.job.isShared && widget.job.connectionCode != null) {
        // For shared jobs, fetch entries from the shared job collection
        print(
          '🔍 Fetching entries for shared job: ${widget.job.name} with code: ${widget.job.connectionCode}',
        );

        final snapshot =
            await FirebaseFirestore.instance
                .collection('sharedJobs')
                .doc(widget.job.connectionCode)
                .collection('entries')
                .orderBy('timestamp', descending: true)
                .get();

        print(
          '📊 Found ${snapshot.docs.length} entries for shared job: ${widget.job.connectionCode}',
        );

        final entries =
            snapshot.docs
                .map((doc) {
                  try {
                    return TimeEntry.fromJson(doc.data());
                  } catch (e) {
                    print('❌ Error parsing entry: $e');
                    return null;
                  }
                })
                .where((entry) => entry != null)
                .cast<TimeEntry>()
                .toList();

        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      } else {
        // For regular jobs, use the provider to get entries
        final entries = await provider.getEntriesForJob(widget.job.id);
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading entries: $e');
      setState(() {
        _isLoading = false;
      });
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

  Future<List<TimeEntry>> _fetchSharedJobEntries() async {
    if (widget.job.connectionCode == null) {
      return [];
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(widget.job.connectionCode)
              .collection('entries')
              .orderBy('clockInTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TimeEntry(
          id: data['id'],
          jobId: data['jobId'],
          jobName: data['jobName'],
          jobColor: Color(data['jobColor']),
          clockInTime: DateTime.parse(data['clockInTime']),
          clockOutTime: DateTime.parse(data['clockOutTime']),
          duration: Duration(minutes: data['duration']),
          description: data['description'],
          date: data['date'],
          userId: data['userId'],
          userName: data['userName'],
        );
      }).toList();
    } catch (e) {
      print('Error fetching shared job entries: $e');
      return [];
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
              : _entries.isEmpty
              ? Center(
                child: Text(
                  timeEntriesProvider.translate('noTimeEntries'),
                  style: const TextStyle(fontSize: 16),
                ),
              )
              : ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return TimeEntryListItem(
                    entry: entry,
                    job: widget.job,
                    showUserName: widget.job.isShared,
                    onDelete: () => _loadEntries(),
                  );
                },
              ),
    );
  }

  Widget _buildTimeEntriesList() {
    if (widget.job.isShared) {
      return FutureBuilder<List<TimeEntry>>(
        future: Provider.of<TimeEntriesProvider>(
          context,
          listen: false,
        ).fetchSharedJobTimeEntries(widget.job),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading time entries: ${snapshot.error}'),
            );
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return Center(child: Text('No time entries yet'));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return TimeEntryListItem(
                entry: entry,
                job: widget.job,
                showUserName: true, // Show who created the entry
                onDelete: () => _loadEntries(),
              );
            },
          );
        },
      );
    } else {
      // Regular job - show only the current user's entries
      final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
      final jobEntries = timeEntriesProvider.getEntriesForJob(widget.job.id);

      if (jobEntries.isEmpty) {
        return Center(child: Text('No time entries yet'));
      }

      return ListView.builder(
        itemCount: jobEntries.length,
        itemBuilder: (context, index) {
          final entry = jobEntries[index];
          return TimeEntryListItem(
            entry: entry,
            job: widget.job,
            showUserName: false,
            onDelete: () => _loadEntries(),
          );
        },
      );
    }
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
                      _loadEntries();

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

  void _confirmDeleteEntry(BuildContext context, TimeEntry entry) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(timeEntriesProvider.translate('deleteEntry')),
            content: Text(timeEntriesProvider.translate('deleteEntryConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(timeEntriesProvider.translate('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await timeEntriesProvider.deleteTimeEntry(entry.id);

                    // Refresh data
                    _loadEntries();

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

class TimeEntryListItem extends StatelessWidget {
  final TimeEntry entry;
  final Job job;
  final bool showUserName;
  final VoidCallback onDelete;

  const TimeEntryListItem({
    Key? key,
    required this.entry,
    required this.job,
    this.showUserName = false,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnEntry = entry.userId == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: job.color,
          child: Icon(Icons.access_time, color: Colors.white),
        ),
        title: Row(
          children: [
            Text(
              '${timeFormat.format(entry.clockInTime)} - ${entry.clockOutTime != null ? timeFormat.format(entry.clockOutTime!) : 'Now'}',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '${entry.durationInHours.toStringAsFixed(1)}h',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(entry.clockInTime)),
            if (entry.description != null && entry.description!.isNotEmpty)
              Text(
                entry.description!,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (showUserName && entry.userName != null)
              Text(
                'By: ${entry.userName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing:
            isOwnEntry
                ? PopupMenuButton(
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editTimeEntry(context, entry);
                    } else if (value == 'delete') {
                      _confirmDeleteEntry(context, entry);
                    }
                  },
                )
                : null,
      ),
    );
  }

  void _editTimeEntry(BuildContext context, TimeEntry entry) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );
    final descriptionController = TextEditingController(
      text: entry.description,
    );

    TimeOfDay startTime = TimeOfDay(
      hour: entry.clockInTime.hour,
      minute: entry.clockInTime.minute,
    );

    TimeOfDay endTime = TimeOfDay(
      hour: entry.clockOutTime?.hour ?? DateTime.now().hour,
      minute: entry.clockOutTime?.minute ?? DateTime.now().minute,
    );

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
              title: const Text('Edit Time Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    ListTile(
                      title: const Text('Date'),
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
                      title: const Text('Start Time'),
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
                      title: const Text('End Time'),
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
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Time entry updated'),
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
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteEntry(BuildContext context, TimeEntry entry) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(timeEntriesProvider.translate('deleteEntry')),
            content: Text(timeEntriesProvider.translate('deleteEntryConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(timeEntriesProvider.translate('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await timeEntriesProvider.deleteTimeEntry(entry.id);

                    // Call the callback instead of _loadEntries
                    onDelete();

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
