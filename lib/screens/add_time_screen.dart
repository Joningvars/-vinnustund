import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_clock/providers/time_clock_provider.dart';

class AddTimeScreen extends StatelessWidget {
  const AddTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the parent state through InheritedWidget or Provider in a real app
    final provider = Provider.of<TimeClockProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Time Entry',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Job selection
              GestureDetector(
                onTap: provider.showJobSelectionDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Job',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          if (provider.selectedJob != null) ...[
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: provider.selectedJob!.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              provider.selectedJob!.name,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ] else
                            Text(
                              'Select a job',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Start Time Selector
              GestureDetector(
                onTap: provider.selectStartTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Start Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            provider.formatTimeOfDay(provider.startTime),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // End Time Selector
              GestureDetector(
                onTap: provider.selectEndTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'End Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            provider.formatTimeOfDay(provider.endTime),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Duration display
              Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      provider.formatDuration(
                        provider.calculateManualDuration(),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Add button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: provider.addManualEntry,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Time Entry',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
