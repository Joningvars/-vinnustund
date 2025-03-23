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

  TimeEntry({
    String? id,
    required this.jobId,
    required this.jobName,
    required this.jobColor,
    required this.clockInTime,
    required this.clockOutTime,
    required this.duration,
    this.description,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

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
      'clockInTime': clockInTime.millisecondsSinceEpoch,
      'clockOutTime': clockOutTime.millisecondsSinceEpoch,
      'duration': duration.inMilliseconds,
      'description': description,
    };
  }

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'],
      jobId: json['jobId'],
      jobName: json['jobName'],
      jobColor: Color(json['jobColor']),
      clockInTime: DateTime.fromMillisecondsSinceEpoch(json['clockInTime']),
      clockOutTime: DateTime.fromMillisecondsSinceEpoch(json['clockOutTime']),
      duration: Duration(milliseconds: json['duration']),
      description: json['description'],
    );
  }
}
