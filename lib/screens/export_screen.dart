import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:timagatt/services/pdf_export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedJobId;
  bool _isExporting = false;
  String _selectedPeriod = 'Day';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.translate('exportToPdf'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Date range selector
              Text(
                provider.translate('timeRange'),
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
                        '${provider.translate('startDate')}: ${DateFormat.yMMMd(provider.locale.languageCode).format(_startDate)}',
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
                        '${provider.translate('endDate')}: ${DateFormat.yMMMd(provider.locale.languageCode).format(_endDate)}',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.translate('filterByJob'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // All jobs button
                  _buildJobFilterButton(
                    'all',
                    provider.translate('allJobs'),
                    null,
                  ),

                  // Individual job buttons
                  ...provider.jobs.map(
                    (job) => _buildJobFilterButton(job.id, job.name, job.color),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Quick date range buttons
              Text(
                provider.translate('quickSelect'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Quick select buttons
              Container(
                padding: const EdgeInsets.only(
                  left: 4,
                  right: 4,
                  top: 2,
                  bottom: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildPeriodButton('Day', provider.translate('today')),
                    _buildPeriodButton('Week', provider.translate('thisWeek')),
                    _buildPeriodButton(
                      'Month',
                      provider.translate('thisMonth'),
                    ),
                  ],
                ),
              ),

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
                            provider.translate('exportToPdf'),
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

  Widget _buildPeriodButton(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor:
              isSelected ? Theme.of(context).colorScheme.primary : null,
          foregroundColor:
              isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          setState(() {
            _selectedPeriod = period;
            _updateDateRangeForPeriod(period);
          });
        },
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _updateDateRangeForPeriod(String period) {
    final now = DateTime.now();

    switch (period) {
      case 'Day':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Week':
        // Get the start of the week (Monday)
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        _endDate = _startDate.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        break;
      case 'Month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final provider = Provider.of<TimeClockProvider>(context, listen: false);
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = isStartDate ? DateTime(2020) : _startDate;
    final lastDate = isStartDate ? _endDate : DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: provider.locale,
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
    final provider = Provider.of<TimeClockProvider>(context, listen: false);
    setState(() {
      _isExporting = true;
    });

    try {
      final pdfService = PdfExportService(provider);

      // Filter entries by date range and job
      final entries =
          provider.timeEntries.where((entry) {
            final isInDateRange =
                (entry.clockInTime.isAfter(_startDate) ||
                    entry.clockInTime.isAtSameMomentAs(_startDate)) &&
                (entry.clockOutTime.isBefore(_endDate) ||
                    entry.clockOutTime.isAtSameMomentAs(_endDate));

            // Fix the job filter logic - "all" should include all jobs
            final matchesJob =
                _selectedJobId == 'all' || entry.jobId == _selectedJobId;

            return isInDateRange && matchesJob;
          }).toList();

      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.translate('noEntriesForExport')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        setState(() {
          _isExporting = false;
        });
        return;
      }

      // Generate period string
      final dateFormat = DateFormat.yMMMd(provider.locale.languageCode);
      final periodString =
          '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}';

      // Generate and show PDF
      final file = await pdfService.generateTimeEntriesPdf(
        entries,
        periodString,
      );

      // Show options dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(provider.translate('exportComplete')),
                content: Text(provider.translate('exportCompleteMessage')),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      OpenFile.open(file.path);
                    },
                    child: Text(provider.translate('view')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Share.shareXFiles([XFile(file.path)]);
                    },
                    child: Text(provider.translate('share')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(provider.translate('close')),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.translate('exportError')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildJobFilterButton(String jobId, String jobName, Color? jobColor) {
    final isSelected = _selectedJobId == jobId;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color:
            isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedJobId = jobId;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected
                      ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      )
                      : null,
            ),
            child: Row(
              children: [
                if (jobColor != null)
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: jobColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    jobName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
