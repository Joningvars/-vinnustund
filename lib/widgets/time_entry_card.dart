import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';

class TimeEntryCard extends StatelessWidget {
  final TimeEntry entry;
  final VoidCallback? onDelete;

  const TimeEntryCard({Key? key, required this.entry, this.onDelete})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final hours = entry.duration.inHours;
    final minutes = entry.duration.inMinutes % 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _editTimeEntry(context),
        onLongPress: () => _deleteTimeEntry(context),
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.jobColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.userName ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$hours ${timeEntriesProvider.translate('klst')} $minutes ${timeEntriesProvider.translate('mín')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${timeEntriesProvider.formatTime(entry.clockInTime)} - ${timeEntriesProvider.formatTime(entry.clockOutTime)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (entry.description != null &&
                            entry.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.description!,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTimeEntry(BuildContext context) async {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    final startTimeController = TextEditingController(
      text: timeEntriesProvider.formatTime(entry.clockInTime),
    );
    final endTimeController = TextEditingController(
      text: timeEntriesProvider.formatTime(entry.clockOutTime),
    );
    final descriptionController = TextEditingController(
      text: entry.description ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
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
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      color: Colors.blue.shade700,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    timeEntriesProvider.translate('editEntry'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeEntriesProvider.translate('editEntryDescription'),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: startTimeController,
                    decoration: InputDecoration(
                      labelText: timeEntriesProvider.translate('startTime'),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(entry.clockInTime),
                      );
                      if (time != null) {
                        final now = DateTime.now();
                        final newDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          time.hour,
                          time.minute,
                        );
                        startTimeController.text = timeEntriesProvider
                            .formatTime(newDateTime);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: endTimeController,
                    decoration: InputDecoration(
                      labelText: timeEntriesProvider.translate('endTime'),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(entry.clockOutTime),
                      );
                      if (time != null) {
                        final now = DateTime.now();
                        final newDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          time.hour,
                          time.minute,
                        );
                        endTimeController.text = timeEntriesProvider.formatTime(
                          newDateTime,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: timeEntriesProvider.translate('description'),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          timeEntriesProvider.translate('cancel'),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(timeEntriesProvider.translate('save')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (result == true) {
      final startTime = timeEntriesProvider.parseTime(startTimeController.text);
      final endTime = timeEntriesProvider.parseTime(endTimeController.text);

      final updatedEntry = TimeEntry(
        id: entry.id,
        jobId: entry.jobId,
        jobName: entry.jobName,
        jobColor: entry.jobColor,
        clockInTime: startTime,
        clockOutTime: endTime,
        duration: endTime.difference(startTime),
        description:
            descriptionController.text.isEmpty
                ? null
                : descriptionController.text,
        userId: entry.userId,
        userName: entry.userName,
        date: entry.date,
      );

      await timeEntriesProvider.updateTimeEntry(updatedEntry);
    }
  }

  Future<void> _deleteTimeEntry(BuildContext context) async {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
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
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade700,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    timeEntriesProvider.translate('deleteEntry'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    timeEntriesProvider.translate('deleteEntryConfirm'),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          timeEntriesProvider.translate('cancel'),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
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
                        child: Text(timeEntriesProvider.translate('delete')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirmed == true && onDelete != null) {
      onDelete!();
    }
  }
}
