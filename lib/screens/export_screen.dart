import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:timagatt/services/pdf_export_service.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/widgets/common/styled_dropdown.dart';
import 'package:timagatt/models/job.dart';

class ExportScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String? jobId;

  const ExportScreen({
    Key? key,
    required this.startDate,
    required this.endDate,
    this.jobId,
  }) : super(key: key);

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isExporting = false;
  String? _exportError;
  bool _includeBreaks = true;
  bool _groupByJob = true;
  bool _includeDescription = true;
  String? selectedJobId;

  @override
  void initState() {
    super.initState();
    // Initialize with the date range passed from history screen
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    selectedJobId = widget.jobId;
  }

  @override
  Widget build(BuildContext context) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          timeEntriesProvider.translate('exportToPdf'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date range selector
              Text(
                timeEntriesProvider.translate('timeRange'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Start date picker
              InkWell(
                onTap: () => _selectDate(context, true),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${timeEntriesProvider.translate('startDate')}: ${DateFormat.yMMMd(timeEntriesProvider.locale.languageCode).format(_startDate)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color:
                            isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // End date picker
              InkWell(
                onTap: () => _selectDate(context, false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${timeEntriesProvider.translate('endDate')}: ${DateFormat.yMMMd(timeEntriesProvider.locale.languageCode).format(_endDate)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color:
                            isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Job filter
              _buildJobFilter(),

              const SizedBox(height: 32),

              // Quick date range buttons
              _buildQuickSelectButtons(),

              const SizedBox(height: 40),

              // Export button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _isExporting ? null : _exportToPdf,
                  child:
                      _isExporting
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            timeEntriesProvider.translate('exportToPdf'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSelectButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Provider.of<TimeEntriesProvider>(context).translate('quickSelect'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildQuickSelectButton(
              Provider.of<TimeEntriesProvider>(context).translate('today'),
              () {
                final now = DateTime.now();
                setState(() {
                  _startDate = DateTime(now.year, now.month, now.day);
                  _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                });
              },
            ),
            const SizedBox(width: 8),
            _buildQuickSelectButton(
              Provider.of<TimeEntriesProvider>(context).translate('thisWeek'),
              () {
                final now = DateTime.now();
                // Find the first day of the week (Monday)
                final firstDayOfWeek = now.subtract(
                  Duration(days: now.weekday - 1),
                );
                // Find the last day of the week (Sunday)
                final lastDayOfWeek = firstDayOfWeek.add(
                  const Duration(days: 6),
                );

                setState(() {
                  _startDate = DateTime(
                    firstDayOfWeek.year,
                    firstDayOfWeek.month,
                    firstDayOfWeek.day,
                  );
                  _endDate = DateTime(
                    lastDayOfWeek.year,
                    lastDayOfWeek.month,
                    lastDayOfWeek.day,
                    23,
                    59,
                    59,
                  );
                });
              },
            ),
            const SizedBox(width: 8),
            _buildQuickSelectButton(
              Provider.of<TimeEntriesProvider>(context).translate('thisMonth'),
              () {
                final now = DateTime.now();
                // First day of current month
                final firstDay = DateTime(now.year, now.month, 1);
                // Last day of current month
                final lastDay = DateTime(
                  now.year,
                  now.month + 1,
                  0,
                  23,
                  59,
                  59,
                );

                setState(() {
                  _startDate = firstDay;
                  _endDate = lastDay;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickSelectButton(String text, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
          highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = isStartDate ? DateTime(2020) : _startDate;
    final lastDate = isStartDate ? _endDate : DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: timeEntriesProvider.locale,
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _exportToPdf() async {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isExporting = true;
      _exportError = null;
    });

    try {
      final pdfService = PdfExportService(timeEntriesProvider);
      await pdfService.exportTimeEntries(
        context,
        _startDate,
        _endDate,
        includeBreaks: _includeBreaks,
        groupByJob: _groupByJob,
        includeDescription: _includeDescription,
        jobId: selectedJobId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(timeEntriesProvider.translate('exportSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _exportError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildJobFilter() {
    final jobsProvider = Provider.of<JobsProvider>(context);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);

    // Combine regular and shared jobs for selection
    final allJobs = [...jobsProvider.jobs, ...jobsProvider.sharedJobs];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          timeEntriesProvider.translate('filterByJob'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StyledDropdown<String?>(
          value: selectedJobId,
          onChanged: (String? newValue) {
            setState(() {
              selectedJobId = newValue;
            });
          },
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(timeEntriesProvider.translate('allJobs')),
            ),
            ...allJobs.map<DropdownMenuItem<String?>>((Job job) {
              return DropdownMenuItem<String?>(
                value: job.id,
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
          ],
        ),
      ],
    );
  }
}
