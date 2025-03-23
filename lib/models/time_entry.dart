import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeEntry {
  final String id;
  final String jobId;
  final String jobName;
  final Color jobColor;
  final DateTime clockInTime;
  final DateTime clockOutTime;
  final Duration duration;
  final String? description;
  final String date;

  TimeEntry({
    String? id,
    required this.jobId,
    required this.jobName,
    required this.jobColor,
    required this.clockInTime,
    required this.clockOutTime,
    required this.duration,
    this.description,
  }) : this.id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       this.date =
           "${clockInTime.year}-${clockInTime.month.toString().padLeft(2, '0')}-${clockInTime.day.toString().padLeft(2, '0')}";

  String get formattedDate => DateFormat('MMM d, yyyy').format(clockInTime);

  String get formattedClockIn => DateFormat('h:mm a').format(clockInTime);

  String get formattedClockOut => DateFormat('h:mm a').format(clockOutTime);

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours hrs $minutes mins';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'jobName': jobName,
      'jobColor': jobColor.value,
      'clockInTime': clockInTime.toIso8601String(),
      'clockOutTime': clockOutTime.toIso8601String(),
      'duration': duration.inMinutes,
      'description': description,
      'date': date,
    };
  }

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'],
      jobId: json['jobId'],
      jobName: json['jobName'],
      jobColor: Color(json['jobColor']),
      clockInTime: DateTime.parse(json['clockInTime']),
      clockOutTime: DateTime.parse(json['clockOutTime']),
      duration: Duration(minutes: json['duration']),
      description: json['description'],
    );
  }
}
