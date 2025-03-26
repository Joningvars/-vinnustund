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

class PdfExportService {
  final TimeClockProvider provider;

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
    final textColor = PdfColor.fromHex('#212121');
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

  Future<void> exportTimeEntries(BuildContext context, String period) async {
    // Get entries based on selected period
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime.now(); // Add end date for better filtering

    switch (period) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Week':
        // Get the start of the week (Monday)
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(
          Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        // Last day of the month
        final nextMonth = now.month < 12 ? now.month + 1 : 1;
        final nextYear = now.month < 12 ? now.year : now.year + 1;
        endDate = DateTime(
          nextYear,
          nextMonth,
          1,
        ).subtract(Duration(seconds: 1));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    // Add debug prints to help identify the issue
    print('Exporting entries for period: $period');
    print('Start date: $startDate');
    print('End date: $endDate');
    print('Total entries: ${provider.timeEntries.length}');

    // Filter entries for the selected period with improved logic
    final entries =
        provider.timeEntries.where((entry) {
          final entryDate = entry.clockInTime;
          final isAfterStart =
              entryDate.isAfter(startDate) ||
              entryDate.isAtSameMomentAs(startDate);
          final isBeforeEnd =
              entryDate.isBefore(endDate) ||
              entryDate.isAtSameMomentAs(endDate);

          final included = isAfterStart && isBeforeEnd;

          // Debug print for each entry
          print('Entry date: $entryDate, included: $included');

          return included;
        }).toList();

    print('Filtered entries count: ${entries.length}');

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
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate period string for the report
      String periodString;
      final dateFormat = DateFormat.yMMMd(provider.locale.languageCode);

      switch (period) {
        case 'Day':
          periodString = dateFormat.format(now);
          break;
        case 'Week':
          final endOfWeek = startDate.add(Duration(days: 6));
          periodString =
              '${dateFormat.format(startDate)} - ${dateFormat.format(endOfWeek)}';
          break;
        case 'Month':
          periodString = DateFormat.yMMMM(
            provider.locale.languageCode,
          ).format(now);
          break;
        default:
          periodString = dateFormat.format(now);
      }

      // Generate PDF
      final file = await generateTimeEntriesPdf(entries, periodString);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success dialog with modern styling
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
                color: Theme.of(context).cardColor,
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
                                color: Theme.of(context).primaryColor,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.translate('view'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
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
                              Icon(Icons.share, color: Colors.purple, size: 28),
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
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
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
