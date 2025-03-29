import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? userId;
  final String? userName;

  TimeEntry({
    String? id,
    required this.jobId,
    required this.jobName,
    required this.jobColor,
    required this.clockInTime,
    required this.clockOutTime,
    required this.duration,
    this.description,
    String? date,
    this.userId,
    this.userName,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       date = date ?? DateFormat('yyyy-MM-dd').format(clockInTime);

  // Format the date for display
  String get formattedDate {
    final dateObj = DateFormat('yyyy-MM-dd').parse(date);
    return DateFormat.yMMMd().format(dateObj);
  }

  // Format clock in time
  String get formattedClockIn {
    return DateFormat.jm().format(clockInTime);
  }

  // Format clock out time
  String get formattedClockOut {
    return DateFormat.jm().format(clockOutTime);
  }

  // Format duration
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'jobName': jobName,
      'jobColor': jobColor.value,
      'clockInTime': clockInTime.toIso8601String(),
      'clockOutTime': clockOutTime.toIso8601String(),
      'duration': duration.inMinutes,
      'description': description ?? '',
      'date': date,
      'userId': userId,
      'userName': userName,
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
      date: json['date'],
      userId: json['userId'],
      userName: json['userName'],
    );
  }

  static TimeEntry fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimeEntry(
      id: data['id'] ?? doc.id,
      jobId: data['jobId'] ?? '',
      jobName: data['jobName'] ?? 'Unknown Job',
      jobColor: Color(data['jobColor'] ?? Colors.grey.value),
      clockInTime: DateTime.parse(data['clockInTime']),
      clockOutTime: DateTime.parse(data['clockOutTime']),
      duration: Duration(minutes: data['duration']),
      description: data['description'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
    );
  }

  double get durationInHours {
    if (clockOutTime == null) return 0;
    final duration = clockOutTime!.difference(clockInTime);
    return duration.inMinutes / 60;
  }

  DateTime get startTime => clockInTime;
  DateTime get endTime => clockOutTime ?? DateTime.now();
}
