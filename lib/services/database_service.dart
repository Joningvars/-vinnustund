import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Color;
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid;

  DatabaseService({required this.uid});

  // Collection references
  CollectionReference get userCollection => _firestore.collection('users');
  CollectionReference get jobsCollection =>
      userCollection.doc(uid).collection('jobs');
  CollectionReference get timeEntriesCollection =>
      userCollection.doc(uid).collection('timeEntries');

  // Save jobs to Firestore
  Future<void> saveJobs(List<Job> jobs) async {
    // Delete all existing jobs first
    final snapshot = await jobsCollection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Add all jobs
    for (var job in jobs) {
      await jobsCollection.doc(job.id).set({
        'name': job.name,
        'color': job.color.value,
        'id': job.id,
      });
    }
  }

  // Save time entries to Firestore
  Future<void> saveTimeEntries(List<TimeEntry> entries) async {
    // Delete all existing entries first
    final snapshot = await timeEntriesCollection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Add all entries
    for (var entry in entries) {
      await timeEntriesCollection.doc(entry.id).set({
        'id': entry.id,
        'jobId': entry.jobId,
        'jobName': entry.jobName,
        'jobColor': entry.jobColor.value,
        'clockInTime': entry.clockInTime.toIso8601String(),
        'clockOutTime': entry.clockOutTime.toIso8601String(),
        'duration': entry.duration.inMinutes,
        'description': entry.description,
      });
    }
  }

  // Load jobs from Firestore
  Future<List<Job>> loadJobs() async {
    final snapshot = await jobsCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Job(
        id: data['id'],
        name: data['name'],
        color: ui.Color(data['color']),
      );
    }).toList();
  }

  // Load time entries from Firestore
  Future<List<TimeEntry>> loadTimeEntries() async {
    final snapshot = await timeEntriesCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return TimeEntry(
        id: data['id'],
        jobId: data['jobId'],
        jobName: data['jobName'],
        jobColor: ui.Color(data['jobColor']),
        clockInTime: DateTime.parse(data['clockInTime']),
        clockOutTime: DateTime.parse(data['clockOutTime']),
        duration: Duration(minutes: data['duration']),
        description: data['description'],
      );
    }).toList();
  }

  // Add this method to check if the user is authenticated
  bool isUserAuthenticated() {
    return FirebaseAuth.instance.currentUser != null;
  }

  // Update the saveUserSettings method
  Future<void> saveUserSettings({
    required String languageCode,
    required String countryCode,
    required bool use24HourFormat,
    required int targetHours,
    required String themeMode,
  }) async {
    if (!isUserAuthenticated()) {
      print('Cannot save settings: User not authenticated');
      return;
    }

    try {
      await userCollection.doc(uid).update({
        'settings': {
          'languageCode': languageCode,
          'countryCode': countryCode,
          'use24HourFormat': use24HourFormat,
          'targetHours': targetHours,
          'themeMode': themeMode,
        },
      });
    } catch (e) {
      print('Error saving user settings: $e');

      // If the document doesn't exist yet, create it
      if (e.toString().contains('not-found')) {
        await userCollection.doc(uid).set({
          'settings': {
            'languageCode': languageCode,
            'countryCode': countryCode,
            'use24HourFormat': use24HourFormat,
            'targetHours': targetHours,
            'themeMode': themeMode,
          },
        });
      } else {
        rethrow;
      }
    }
  }

  // Load user settings
  Future<Map<String, dynamic>?> loadUserSettings() async {
    final doc = await userCollection.doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('settings')) {
        return data['settings'];
      }
    }
    return null;
  }

  // Add this method to your DatabaseService class
  Future<void> saveTimeEntry(TimeEntry entry) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('timeEntries')
          .doc(entry.id)
          .set(entry.toJson());
    } catch (e) {
      print('Error saving time entry: $e');
      rethrow;
    }
  }
}
