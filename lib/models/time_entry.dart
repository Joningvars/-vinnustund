import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeEntry {
  final String id;
  final DateTime clockInTime;
  final DateTime clockOutTime;
  final String jobId;
  final String jobName;
  final Color jobColor;
  final String? description;

  TimeEntry({
    String? id,
    required this.clockInTime,
    required this.clockOutTime,
    required this.jobId,
    required this.jobName,
    required this.jobColor,
    this.description,
  }) : id = id ?? UniqueKey().toString();

  Duration get duration => clockOutTime.difference(clockInTime);

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
      'clockInTime': clockInTime.millisecondsSinceEpoch,
      'clockOutTime': clockOutTime.millisecondsSinceEpoch,
      'jobId': jobId,
      'jobName': jobName,
      'jobColor': jobColor.value,
      'description': description,
    };
  }

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'],
      clockInTime: DateTime.fromMillisecondsSinceEpoch(json['clockInTime']),
      clockOutTime: DateTime.fromMillisecondsSinceEpoch(json['clockOutTime']),
      jobId: json['jobId'],
      jobName: json['jobName'],
      jobColor: Color(json['jobColor']),
      description: json['description'],
    );
  }
}
