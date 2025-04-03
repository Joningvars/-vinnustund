import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:timagatt/providers/time_entries_provider.dart';
import 'dart:math' as math;
import 'dart:typed_data';

class PdfExportService {
  final TimeEntriesProvider provider;
  final PdfColor textColor = PdfColor.fromHex('#212121');

  PdfExportService(this.provider);

  Future<File> generateTimeEntriesPdf(
    List<TimeEntry> entries,
    String period,
  ) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(
          await rootBundle.load('assets/fonts/Comfortaa/Comfortaa-Regular.ttf'),
        ),
        bold: pw.Font.ttf(
          await rootBundle.load('assets/fonts/Comfortaa/Comfortaa-Bold.ttf'),
        ),
      ),
    );

    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/icons/logo.png')).buffer.asUint8List(),
    );

    // Define colors for a modern, minimalist design
    final primaryColor = PdfColor.fromHex('#3D5AFE');
    final accentColor = PdfColor.fromHex('#00C853');
    final bgColor = PdfColors.white;
    final lightGrey = PdfColor.fromHex('#F5F5F5');
    final mediumGrey = PdfColor.fromHex('#9E9E9E');

    // Sort entries by date (newest first)
    entries.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));

    // Calculate total hours
    final totalDuration = entries.fold<Duration>(
      Duration.zero,
      (total, entry) => total + entry.duration,
    );
    final totalHours = totalDuration.inHours;
    final totalMinutes = totalDuration.inMinutes % 60;

    // Add a single page with header and table
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              // Header with logo and title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logoImage, width: 40, height: 40),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'Tímagátt',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    period,
                    style: pw.TextStyle(fontSize: 14, color: mediumGrey),
                  ),
                ],
              ),

              // Summary row
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 15),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            provider.translate('timeReport'),
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            provider.translate('totalHours') +
                                ': ' +
                                '$totalHours,${totalMinutes.toString().padLeft(2, '0')}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: primaryColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Text(
                      provider.translate('entries') +
                          ': ' +
                          entries.length.toString(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Title for entries
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 5, bottom: 10),
                child: pw.Text(
                  provider.locale.languageCode == 'is'
                      ? 'Vinnu færslur'
                      : provider.translate('timeEntries'),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: lightGrey, width: 1),
              ),
              child: pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: pw.BorderSide(color: lightGrey, width: 0.5),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.0), // Date
                  1: const pw.FlexColumnWidth(1.2), // Job
                  2: const pw.FlexColumnWidth(0.8), // Clock In
                  3: const pw.FlexColumnWidth(0.8), // Clock Out
                  4: const pw.FlexColumnWidth(0.6), // Hours
                  5: const pw.FlexColumnWidth(2.0), // Description
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(8),
                        topRight: pw.Radius.circular(8),
                      ),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          provider.translate('date'),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          provider.locale.languageCode == 'is'
                              ? 'Verk'
                              : provider.translate('job'),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          provider.translate('clockInPDF'),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          provider.translate('clockOutPDF'),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          provider.locale.languageCode == 'is'
                              ? 'Klst'
                              : provider.translate('hours'),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          provider.translate('description'),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final timeEntry = entry.value;
                    final hours = timeEntry.duration.inHours;
                    final minutes = timeEntry.duration.inMinutes % 60;
                    final dateFormat = DateFormat.yMd(
                      provider.locale.languageCode,
                    );
                    final timeFormat =
                        provider.use24HourFormat
                            ? DateFormat.Hm(provider.locale.languageCode)
                            : DateFormat.jm(provider.locale.languageCode);

                    // Alternate row colors for better readability
                    final isEven = index % 2 == 0;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color:
                            isEven
                                ? bgColor
                                : PdfColor(
                                  lightGrey.red,
                                  lightGrey.green,
                                  lightGrey.blue,
                                  0.5,
                                ),
                      ),
                      children: [
                        // Date
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            dateFormat.format(timeEntry.clockInTime),
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        // Job - Fixed to show text properly
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            timeEntry.jobName,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: primaryColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        // Clock In
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            timeFormat.format(timeEntry.clockInTime),
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        // Clock Out
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            timeFormat.format(timeEntry.clockOutTime),
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        // Hours - Fixed to show text properly
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '$hours,${minutes.toString().padLeft(2, '0')}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: primaryColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        // Description
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            timeEntry.description?.isNotEmpty == true
                                ? timeEntry.description!
                                : '-',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color:
                                  timeEntry.description?.isNotEmpty == true
                                      ? textColor
                                      : mediumGrey,
                              fontStyle:
                                  timeEntry.description?.isNotEmpty == true
                                      ? pw.FontStyle.normal
                                      : pw.FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // Save the PDF
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/time_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> exportTimeEntries(
    BuildContext context,
    DateTime startDate,
    DateTime endDate, {
    bool includeBreaks = true,
    bool groupByJob = true,
    bool includeDescription = true,
    String? jobId,
  }) async {
    // Adjust date ranges to include full days
    final adjustedStartDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0,
      0,
      0,
    );
    final adjustedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );

    // Filter entries by date range and optionally by job
    final filteredEntries =
        provider.timeEntries.where((entry) {
          // Check if entry is within date range
          final entryDate = entry.clockInTime;
          final isInDateRange =
              entryDate.isAfter(adjustedStartDate) &&
              (entry.clockOutTime?.isBefore(adjustedEndDate) ??
                  entryDate.isBefore(adjustedEndDate));

          // If jobId is specified, filter by job
          final isMatchingJob = jobId == null || entry.jobId == jobId;

          return isInDateRange && isMatchingJob;
        }).toList();

    // Sort entries by date
    filteredEntries.sort((a, b) => a.clockInTime.compareTo(b.clockInTime));

    if (filteredEntries.isEmpty) {
      throw Exception(provider.translate('noEntriesForExport'));
    }

    try {
      // Generate period string for the report
      String periodString;
      final dateFormat = DateFormat.yMMMd(provider.locale.languageCode);

      // Format date range for the report title
      periodString =
          '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';

      // Generate PDF
      final file = await generateTimeEntriesPdf(filteredEntries, periodString);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Success message
                    Text(
                      provider.translate('exportComplete'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      provider.translate('exportCompleteMessage'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // View button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            OpenFile.open(file.path);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  provider.translate('view'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Share button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Share.shareXFiles([XFile(file.path)]);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.share,
                                  color: Colors.purple,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  provider.translate('share'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Close button
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close, color: Colors.grey, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  provider.translate('close'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${provider.translate('exportError')}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<String?> generateTimeReport(
    BuildContext context,
    List<TimeEntry> entries,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Filter entries by date range
    final filteredEntries =
        entries.where((entry) {
          return entry.clockInTime.isAfter(startDate) &&
              entry.clockInTime.isBefore(endDate.add(const Duration(days: 1)));
        }).toList();

    // Sort entries by date
    filteredEntries.sort((a, b) => a.clockInTime.compareTo(b.clockInTime));

    // Check if there are entries to export
    if (filteredEntries.isEmpty) {
      return null;
    }

    // Generate period string for the report
    final dateFormat = DateFormat.yMMMd(provider.locale.languageCode);
    final periodString =
        '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';

    // Load the app logo
    final ByteData logoData = await rootBundle.load('assets/icons/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

    // Define theme colors
    final primaryColor = PdfColor.fromHex('#4CAF50'); // Green primary color
    final accentColor = PdfColor.fromHex('#2196F3'); // Blue accent color
    final backgroundColor = PdfColor.fromHex(
      '#F5F5F5',
    ); // Light gray background

    // Generate PDF document
    final pdf = pw.Document();

    // Add content to PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryColor, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 40,
                      height: 40,
                      child: pw.Image(logoImage),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Tímagátt',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.Text(
                          provider.translate('timeReport'),
                          style: pw.TextStyle(fontSize: 14, color: accentColor),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateTime.now().toString().substring(0, 10),
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      periodString,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Summary section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: backgroundColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: primaryColor.lighter, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    provider.translate('summary'),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${provider.translate('totalHours')}:',
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.Text(
                        _calculateTotalHours(filteredEntries),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${provider.translate('entries')}:',
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.Text(
                        filteredEntries.length.toString(),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Entries table
            pw.Text(
              provider.translate('entries'),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildDetailedTimeEntriesTable(
              filteredEntries,
              primaryColor,
              accentColor,
            ),
          ];
        },
      ),
    );

    // Save the PDF file
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/time_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  // Helper method to build a more detailed time entries table with rounded corners
  pw.Widget _buildDetailedTimeEntriesTable(
    List<TimeEntry> entries,
    PdfColor primaryColor,
    PdfColor accentColor,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: primaryColor.lighter, width: 1),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Table(
          border: pw.TableBorder.symmetric(
            inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2), // Date
            1: const pw.FlexColumnWidth(3), // Job
            2: const pw.FlexColumnWidth(2), // Start
            3: const pw.FlexColumnWidth(2), // End
            4: const pw.FlexColumnWidth(1), // Hours
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: primaryColor.lighter),
              children: [
                _buildTableCell(
                  provider.translate('date'),
                  isHeader: true,
                  textColor: primaryColor.darker,
                ),
                _buildTableCell(
                  provider.translate('selectJob'),
                  isHeader: true,
                  textColor: primaryColor.darker,
                ),
                _buildTableCell(
                  provider.translate('clockInPDF'),
                  isHeader: true,
                  textColor: primaryColor.darker,
                ),
                _buildTableCell(
                  provider.translate('clockOutPDF'),
                  isHeader: true,
                  textColor: primaryColor.darker,
                ),
                _buildTableCell(
                  provider.translate('hours'),
                  isHeader: true,
                  textColor: primaryColor.darker,
                ),
              ],
            ),
            // Data rows
            ...entries.map((entry) {
              final hours = entry.duration.inMinutes / 60;
              final hoursStr = hours.toStringAsFixed(1);

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color:
                      entries.indexOf(entry) % 2 == 0
                          ? PdfColors.white
                          : PdfColor.fromHex('#F9F9F9'),
                ),
                children: [
                  _buildTableCell(
                    DateFormat('MMM d, yyyy').format(entry.clockInTime),
                  ),
                  _buildTableCell(entry.jobName),
                  _buildTableCell(
                    DateFormat('h:mm a').format(entry.clockInTime),
                  ),
                  _buildTableCell(
                    DateFormat('h:mm a').format(entry.clockOutTime),
                  ),
                  _buildTableCell(
                    hoursStr,
                    alignment: pw.Alignment.centerRight,
                    textColor: accentColor,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // Helper method to build a table cell with optional text color
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Align(
        alignment: alignment,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: isHeader ? pw.FontWeight.bold : null,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // Helper method to calculate total hours
  String _calculateTotalHours(List<TimeEntry> entries) {
    int totalMinutes = 0;
    for (var entry in entries) {
      totalMinutes += entry.duration.inMinutes;
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    return '$hours ${provider.translate('klst')} $minutes ${provider.translate('mín')}';
  }

  Future<File> generateJobReportPdf(
    String jobId,
    String jobName,
    List<TimeEntry> entries,
    List<Map<String, dynamic>> expenses,
  ) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(
          await rootBundle.load('assets/fonts/Comfortaa/Comfortaa-Regular.ttf'),
        ),
        bold: pw.Font.ttf(
          await rootBundle.load('assets/fonts/Comfortaa/Comfortaa-Bold.ttf'),
        ),
      ),
    );

    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/icons/logo.png')).buffer.asUint8List(),
    );

    // Define colors for a modern, minimalist design
    final primaryColor = PdfColor.fromHex('#3D5AFE');
    final accentColor = PdfColor.fromHex('#00C853');
    final bgColor = PdfColors.white;
    final lightGrey = PdfColor.fromHex('#F5F5F5');
    final mediumGrey = PdfColor.fromHex('#9E9E9E');

    // Sort entries by date (newest first)
    entries.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));
    expenses.sort(
      (a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])),
    );

    // Calculate totals
    final totalDuration = entries.fold<Duration>(
      Duration.zero,
      (total, entry) => total + entry.duration,
    );
    final totalHours = totalDuration.inHours;
    final totalMinutes = totalDuration.inMinutes % 60;
    final totalExpenses = expenses.fold<double>(
      0,
      (total, expense) => total + (expense['amount'] as num).toDouble(),
    );

    // Add a single page with header and tables
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              // Header with logo and title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logoImage, width: 40, height: 40),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'Tímagátt',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 14, color: mediumGrey),
                  ),
                ],
              ),

              // Job title and summary
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 15),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      jobName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          provider.translate('totalHours') +
                              ': ' +
                              '$totalHours,${totalMinutes.toString().padLeft(2, '0')}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: primaryColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          provider.translate('totalExpenses') +
                              ': ' +
                              '${totalExpenses.toStringAsFixed(2)} kr',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: accentColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Time Entries Section
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    provider.translate('timeEntries'),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: lightGrey, width: 1),
                    ),
                    child: pw.Table(
                      border: pw.TableBorder.symmetric(
                        inside: pw.BorderSide(color: lightGrey, width: 0.5),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.0), // Date
                        1: const pw.FlexColumnWidth(1.0), // User
                        2: const pw.FlexColumnWidth(0.8), // Clock In
                        3: const pw.FlexColumnWidth(0.8), // Clock Out
                        4: const pw.FlexColumnWidth(0.6), // Hours
                        5: const pw.FlexColumnWidth(2.0), // Description
                      },
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            borderRadius: pw.BorderRadius.only(
                              topLeft: pw.Radius.circular(8),
                              topRight: pw.Radius.circular(8),
                            ),
                          ),
                          children: [
                            _buildTableHeader(provider.translate('date')),
                            _buildTableHeader(provider.translate('name')),
                            _buildTableHeader(provider.translate('clockInPDF')),
                            _buildTableHeader(
                              provider.translate('clockOutPDF'),
                            ),
                            _buildTableHeader(provider.translate('hours')),
                            _buildTableHeader(
                              provider.translate('description'),
                            ),
                          ],
                        ),
                        // Data rows
                        ...entries.map(
                          (entry) => pw.TableRow(
                            children: [
                              _buildTableCellForJobReport(
                                DateFormat(
                                  'yyyy-MM-dd',
                                ).format(entry.clockInTime),
                              ),
                              _buildTableCellForJobReport(
                                entry.userName ?? 'Unknown',
                              ),
                              _buildTableCellForJobReport(
                                DateFormat('HH:mm').format(entry.clockInTime),
                              ),
                              _buildTableCellForJobReport(
                                DateFormat('HH:mm').format(entry.clockOutTime),
                              ),
                              _buildTableCellForJobReport(
                                '${entry.duration.inHours},${(entry.duration.inMinutes % 60).toString().padLeft(2, '0')}',
                              ),
                              _buildTableCellForJobReport(
                                entry.description ?? '',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Expenses Section
            pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    provider.translate('expenses'),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: lightGrey, width: 1),
                    ),
                    child: pw.Table(
                      border: pw.TableBorder.symmetric(
                        inside: pw.BorderSide(color: lightGrey, width: 0.5),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.0), // Date
                        1: const pw.FlexColumnWidth(1.0), // User
                        2: const pw.FlexColumnWidth(1.0), // Amount
                        3: const pw.FlexColumnWidth(2.0), // Description
                      },
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: accentColor,
                            borderRadius: pw.BorderRadius.only(
                              topLeft: pw.Radius.circular(8),
                              topRight: pw.Radius.circular(8),
                            ),
                          ),
                          children: [
                            _buildTableHeader(provider.translate('date')),
                            _buildTableHeader(provider.translate('name')),
                            _buildTableHeader(provider.translate('amount')),
                            _buildTableHeader(
                              provider.translate('description'),
                            ),
                          ],
                        ),
                        // Data rows
                        ...expenses.map(
                          (expense) => pw.TableRow(
                            children: [
                              _buildTableCellForJobReport(
                                DateFormat(
                                  'yyyy-MM-dd',
                                ).format(DateTime.parse(expense['date'])),
                              ),
                              _buildTableCellForJobReport(
                                expense['userName'] ?? 'Unknown',
                              ),
                              _buildTableCellForJobReport(
                                '${(expense['amount'] as num).toStringAsFixed(2)} kr',
                              ),
                              _buildTableCellForJobReport(
                                expense['description'] ?? '',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // Save the PDF
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/$jobName-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildTableCellForJobReport(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, color: textColor)),
    );
  }
}

// Add extension methods for PdfColor to provide lighter and darker variants
extension PdfColorExtension on PdfColor {
  PdfColor get lighter => PdfColor(
    math.min(1, this.red / 255 + 0.2),
    math.min(1, this.green / 255 + 0.2),
    math.min(1, this.blue / 255 + 0.2),
  );

  PdfColor get darker => PdfColor(
    math.max(0, this.red / 255 - 0.2),
    math.max(0, this.green / 255 - 0.2),
    math.max(0, this.blue / 255 - 0.2),
  );
}
