import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/providers/time_clock_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedJobId;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(
    BuildContext context,
    TimeClockProvider provider,
  ) async {
    HapticFeedback.selectionClick();

    FocusScope.of(context).unfocus();

    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    DateTimeRange initialRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: _endDate ?? DateTime.now(),
    );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedJobId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);
    List<TimeEntry> entries = provider.timeEntries;

    // Apply date range filter
    if (_startDate != null && _endDate != null) {
      entries =
          entries.where((entry) {
            return entry.clockInTime.isAfter(_startDate!) &&
                entry.clockInTime.isBefore(
                  _endDate!.add(const Duration(days: 1)),
                );
          }).toList();
    }

    // Apply job filter
    if (_selectedJobId != null) {
      entries =
          entries.where((entry) => entry.jobId == _selectedJobId).toList();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate total hours for the filtered entries
    int totalFilteredMinutes = 0;
    for (var entry in entries) {
      totalFilteredMinutes += entry.duration.inMinutes;
    }
    final totalFilteredHours = totalFilteredMinutes ~/ 60;
    final totalFilteredRemainingMinutes = totalFilteredMinutes % 60;

    // Group entries by date
    final Map<String, List<TimeEntry>> entriesByDate = {};
    for (var entry in entries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(entry.clockInTime);
      if (!entriesByDate.containsKey(dateStr)) {
        entriesByDate[dateStr] = [];
      }
      entriesByDate[dateStr]!.add(entry);
    }

    // Sort dates in descending order (newest first)
    final sortedDates =
        entriesByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    // Format date range for display
    String dateRangeText = provider.translate('allDates');
    if (_startDate != null && _endDate != null) {
      final startFormatted = DateFormat('MMM d, yyyy').format(_startDate!);
      final endFormatted = DateFormat('MMM d, yyyy').format(_endDate!);
      dateRangeText = '$startFormatted - $endFormatted';
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title section - exactly like home screen
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.translate('history'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Clear filters button with X icon
                    if (_startDate != null || _selectedJobId != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clearFilters,
                        tooltip: provider.translate('clearFilters'),
                      ),
                  ],
                ),
              ),

              // Date range selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date range button
                    InkWell(
                      onTap: () => _selectDateRange(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateRangeText,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Job filter section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider.translate('filterByJob'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        // Total hours display
                        Text(
                          '$totalFilteredHours ${provider.translate('klst')} $totalFilteredRemainingMinutes ${provider.translate('mín')}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Job selection - exactly like home screen
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        children: [
                          // All jobs button
                          _buildPeriodButton(
                            provider.translate('allJobs'),
                            _selectedJobId == null,
                            () {
                              setState(() {
                                _selectedJobId = null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),

                          // Job buttons - using the same style as home page
                          ...provider.jobs.map((job) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildJobButton(
                                job.name,
                                _selectedJobId == job.id,
                                job.color,
                                () {
                                  setState(() {
                                    _selectedJobId =
                                        _selectedJobId == job.id
                                            ? null
                                            : job.id;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Entries list
              Expanded(
                child:
                    entriesByDate.isEmpty
                        ? Center(
                          child: Text(
                            provider.translate('noEntries'),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                        : ListView.builder(
                          itemCount: sortedDates.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final date = sortedDates[index];
                            final dateEntries = entriesByDate[date]!;

                            // Calculate total hours for this date
                            int totalMinutes = 0;
                            for (var entry in dateEntries) {
                              totalMinutes += entry.duration.inMinutes;
                            }
                            final totalHours = totalMinutes ~/ 60;
                            final remainingMinutes = totalMinutes % 60;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date header with total hours
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      provider.formatDate(DateTime.parse(date)),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '$totalHours ${provider.translate('klst')} $remainingMinutes ${provider.translate('mín')}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Time entries for this date - same card design as home page
                                ...dateEntries.map((entry) {
                                  return Dismissible(
                                    key: Key(entry.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: Colors.red,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder:
                                            (context) => Dialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  20.0,
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                      size: 48,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      provider.translate(
                                                        'deleteEntry',
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      provider.translate(
                                                        'deleteEntryConfirm',
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceEvenly,
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(
                                                                      false,
                                                                    ),
                                                            style: OutlinedButton.styleFrom(
                                                              side: BorderSide(
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade300,
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              provider
                                                                  .translate(
                                                                    'cancel',
                                                                  ),
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .grey[700],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 16,
                                                        ),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(true),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              provider
                                                                  .translate(
                                                                    'delete',
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                                    onDismissed: (direction) {
                                      provider.deleteTimeEntry(entry.id);
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Job name and duration
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Time range
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${provider.formatTime(entry.clockInTime)} - ${provider.formatTime(entry.clockOutTime)}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Description if available
                                            if (entry.description != null &&
                                                entry.description!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8.0,
                                                ),
                                                child: Text(
                                                  entry.description!,
                                                  style: TextStyle(
                                                    color:
                                                        isDarkMode
                                                            ? Colors
                                                                .grey
                                                                .shade500
                                                            : Colors
                                                                .grey
                                                                .shade700,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),

                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Period button widget that exactly matches the home page style
  Widget _buildPeriodButton(String text, bool isSelected, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? color.withOpacity(0.2)
                  : isDarkMode
                  ? Colors.grey.shade900
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                isSelected
                    ? color
                    : isDarkMode
                    ? Colors.grey.shade100
                    : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Job button widget that exactly matches the home page style
  Widget _buildJobButton(
    String text,
    bool isSelected,
    Color color,
    VoidCallback onTap,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? color.withOpacity(0.2)
                  : isDarkMode
                  ? Colors.grey.shade900
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                isSelected
                    ? color
                    : isDarkMode
                    ? Colors.grey.shade100
                    : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
