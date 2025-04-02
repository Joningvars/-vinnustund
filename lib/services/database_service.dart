import 'dart:ui' as ui;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timagatt/models/expense.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String uid;

  DatabaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    required this.uid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // Collection references
  CollectionReference get userCollection => _firestore.collection('users');
  CollectionReference get jobsCollection =>
      userCollection.doc(uid).collection('jobs');
  CollectionReference get timeEntriesCollection =>
      userCollection.doc(uid).collection('timeEntries');

  // Add this property at the top of the DatabaseService class
  User? get currentUser => FirebaseAuth.instance.currentUser;

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
    try {
      final snapshot = await jobsCollection.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;

        // Make sure color is properly converted from int to Color
        final colorValue =
            data?['color'] is int
                ? data!['color']
                : Colors.blue.value; // Default color if missing

        return Job(
          id: doc.id,
          name: data?['name'] ?? 'Unnamed Job',
          color: Color(colorValue),
          creatorId: data?['creatorId'],
          connectionCode: data?['connectionCode'],
          isShared: data?['isShared'] ?? false,
          isPublic: data?['isPublic'] ?? true,
        );
      }).toList();
    } catch (e) {
      print('Error loading jobs: $e');
      return [];
    }
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
        date: DateTime.parse(data['clockInTime']),
        userId: data['userId'] ?? uid,
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
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('💾 Saving time entry with ID: ${entry.id}');
      print(
        '👤 Entry user info - userId: ${entry.userId}, userName: ${entry.userName}',
      );

      // If userName is null, try to get it from the user document
      String? userName = entry.userName;
      if (userName == null) {
        print('🔍 userName is null, fetching from user document');
        final userData = await getUserData(user.uid);
        userName = userData?['name'];
        print('👤 Retrieved userName from document: $userName');
      }

      // Create a new entry with the userName included
      final updatedEntry = TimeEntry(
        id: entry.id,
        jobId: entry.jobId,
        jobName: entry.jobName,
        jobColor: entry.jobColor,
        clockInTime: entry.clockInTime,
        clockOutTime: entry.clockOutTime,
        duration: entry.duration,
        description: entry.description,
        userId: entry.userId ?? user.uid,
        userName: userName,
        date: entry.clockInTime,
      );

      // Convert to JSON with the userName included
      final data = updatedEntry.toJson();
      print('💾 Saving entry with data: $data');

      // Always save to user's collection first
      await _firestore
          .collection('users')
          .doc(updatedEntry.userId ?? user.uid)
          .collection('timeEntries')
          .doc(updatedEntry.id)
          .set(data);
      print('✅ Time entry saved to user collection: ${entry.id}');

      // Check if this is a shared job
      final jobDoc = await jobsCollection.doc(entry.jobId).get();
      if (jobDoc.exists) {
        final jobData = jobDoc.data() as Map<String, dynamic>?;
        if (jobData?['isShared'] ?? false) {
          // For shared jobs, also save to the shared job's entries collection
          final connectionCode = jobData?['connectionCode'];
          if (connectionCode != null) {
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('entries')
                .doc(updatedEntry.id)
                .set(data);
            print('✅ Time entry saved to shared job: ${entry.id}');
          }
        }
      }
    } catch (e) {
      print('❌ Error saving time entry: $e');
      rethrow;
    }
  }

  // Add this method to the DatabaseService class
  Future<void> updateUserBreakState(
    bool isOnBreak,
    DateTime? breakStartTime,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnBreak': isOnBreak,
        'breakStartTime': breakStartTime?.toIso8601String() ?? '',
      });
    } catch (e) {
      print('Error updating break state: $e');
    }
  }

  // Add methods to handle shared jobs
  Future<Job?> createSharedJob({
    required String name,
    required Color color,
    required bool isPublic,
  }) async {
    try {
      print('🎯 Creating shared job in Firestore');
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create a new document in the sharedJobs collection
      final docRef = await _firestore.collection('sharedJobs').add({
        'name': name,
        'color': color.value,
        'isPublic': isPublic,
        'creatorId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Created shared job with ID: ${docRef.id}');

      // Create a new job in the user's jobs collection
      final job = Job(
        id: docRef.id, // Use the Firestore document ID as the job ID
        name: name,
        color: color,
        isShared: true,
        isPublic: isPublic,
        creatorId: userId,
        connectedUsers: [userId],
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('jobs')
          .doc(docRef.id)
          .set(job.toJson());

      print('✅ Added job to user\'s collection');
      return job;
    } catch (e) {
      print('❌ Error creating shared job: $e');
      rethrow;
    }
  }

  Future<void> joinSharedJob(String connectionCode) async {
    try {
      print('🎯 Joining shared job with code: $connectionCode');
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get the shared job document
      final docRef = _firestore.collection('sharedJobs').doc(connectionCode);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Shared job not found');
      }

      final data = doc.data();
      if (data == null) {
        throw Exception('Shared job data is null');
      }

      // Check if the job is public or if the user is already connected
      if (!data['isPublic'] && !data['connectedUsers'].contains(userId)) {
        throw Exception('This job is private and you are not connected');
      }

      // Add the user to the connected users list
      await docRef.update({
        'connectedUsers': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create a copy of the job in the user's jobs collection
      final job = Job(
        id: doc.id,
        name: data['name'],
        color: Color(data['color']),
        isShared: true,
        isPublic: data['isPublic'],
        creatorId: data['creatorId'],
        connectedUsers: List<String>.from(data['connectedUsers']),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('jobs')
          .doc(doc.id)
          .set(job.toJson());

      print('✅ Successfully joined shared job');
    } catch (e) {
      print('❌ Error joining shared job: $e');
      rethrow;
    }
  }

  Future<void> deleteSharedJob(String jobId, String connectionCode) async {
    try {
      print('🎯 Deleting shared job with ID: $jobId');
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get the shared job document
      final docRef = _firestore.collection('sharedJobs').doc(connectionCode);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Shared job not found');
      }

      final data = doc.data();
      if (data == null) {
        throw Exception('Shared job data is null');
      }

      // Check if the user is the creator
      if (data['creatorId'] != userId) {
        throw Exception('Only the creator can delete the shared job');
      }

      // Delete the shared job document
      await docRef.delete();

      // Delete the job from all connected users' collections
      final connectedUsers = List<String>.from(data['connectedUsers']);
      for (final connectedUserId in connectedUsers) {
        await _firestore
            .collection('users')
            .doc(connectedUserId)
            .collection('jobs')
            .doc(jobId)
            .delete();
      }

      print('✅ Successfully deleted shared job');
    } catch (e) {
      print('❌ Error deleting shared job: $e');
      rethrow;
    }
  }

  // Get all time entries for a shared job
  Future<List<TimeEntry>> getSharedJobTimeEntries(String jobId) async {
    try {
      // Get the job to check if it's shared
      final jobDoc = await jobsCollection.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      if (!(jobData?['isShared'] ?? false)) {
        throw Exception('This is not a shared job');
      }

      final connectionCode = jobData?['connectionCode'];
      if (connectionCode == null) {
        throw Exception('Invalid connection code');
      }

      // Try to get entries from the shared collection first
      final sharedEntriesSnapshot =
          await _firestore
              .collection('sharedJobs')
              .doc(connectionCode)
              .collection('timeEntries')
              .get();

      if (sharedEntriesSnapshot.docs.isNotEmpty) {
        // Use the shared entries if available
        return sharedEntriesSnapshot.docs.map((doc) {
          final data = doc.data();
          return TimeEntry(
            id: data['id'],
            jobId: data['jobId'],
            jobName: data['jobName'],
            jobColor: ui.Color(data['jobColor']),
            clockInTime: DateTime.parse(data['clockInTime']),
            clockOutTime: DateTime.parse(data['clockOutTime']),
            duration: Duration(minutes: data['duration']),
            description: data['description'],
            userId: data['userId'],
            date: DateTime.parse(data['clockInTime']),
          );
        }).toList();
      }

      // Fallback to the old method if no shared entries found
      final sharedJobDoc =
          await _firestore.collection('sharedJobs').doc(connectionCode).get();
      final connectedUsers = List<String>.from(
        sharedJobDoc.data()?['connectedUsers'] ?? [],
      );

      List<TimeEntry> allEntries = [];

      // Fetch time entries from all connected users
      for (String userId in connectedUsers) {
        final userEntriesSnapshot =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('timeEntries')
                .where('jobId', isEqualTo: jobId)
                .get();

        final userEntries =
            userEntriesSnapshot.docs.map((doc) {
              final data = doc.data();
              return TimeEntry(
                id: data['id'],
                jobId: data['jobId'],
                jobName: data['jobName'],
                jobColor: ui.Color(data['jobColor']),
                clockInTime: DateTime.parse(data['clockInTime']),
                clockOutTime: DateTime.parse(data['clockOutTime']),
                duration: Duration(minutes: data['duration']),
                description: data['description'],
                userId: userId,
                date: DateTime.parse(data['clockInTime']),
              );
            }).toList();

        allEntries.addAll(userEntries);
      }

      // Sort by date, newest first
      allEntries.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));

      return allEntries;
    } catch (e) {
      print('Error getting shared job time entries: $e');
      throw e;
    }
  }

  // Add a method to handle join requests
  Future<void> requestJobAccess(String jobId, String connectionCode) async {
    try {
      // Get the job creator
      final sharedJobDoc =
          await _firestore.collection('sharedJobs').doc(connectionCode).get();
      if (!sharedJobDoc.exists) {
        throw Exception('Job not found');
      }

      final creatorId = sharedJobDoc.data()?['creatorId'];

      // Create a join request
      await _firestore.collection('joinRequests').add({
        'jobId': jobId,
        'connectionCode': connectionCode,
        'requesterId': uid,
        'creatorId': creatorId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error requesting job access: $e');
      throw e;
    }
  }

  // Add a method to get pending join requests for a user
  Future<List<Map<String, dynamic>>> getPendingJoinRequests() async {
    try {
      final requestsSnapshot =
          await _firestore
              .collection('joinRequests')
              .where('creatorId', isEqualTo: uid)
              .where('status', isEqualTo: 'pending')
              .get();

      return requestsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add the document ID
        return data;
      }).toList();
    } catch (e) {
      print('Error getting join requests: $e');
      throw e;
    }
  }

  // Add a method to approve or deny a join request
  Future<void> respondToJoinRequest(String requestId, bool approve) async {
    try {
      // Add more detailed logging
      print('Responding to join request: $requestId, approve: $approve');

      final requestDoc =
          await _firestore.collection('joinRequests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      print('Request data: $requestData');

      // Update the request status
      await _firestore.collection('joinRequests').doc(requestId).update({
        'status': approve ? 'approved' : 'denied',
      });

      if (approve) {
        // Get the job data
        final sharedJobDoc =
            await _firestore
                .collection('sharedJobs')
                .doc(requestData['connectionCode'])
                .get();
        final sharedJobData = sharedJobDoc.data()!;

        // Create a job for the requester
        final job = Job(
          id: requestData['jobId'],
          name: sharedJobData['name'],
          color: ui.Color(
            sharedJobData['color'] is int
                ? sharedJobData['color']
                : Colors.blue.value,
          ),
          creatorId: sharedJobData['creatorId'],
          connectionCode: requestData['connectionCode'],
          isShared: true,
          isPublic: sharedJobData['isPublic'] ?? true,
        );

        // Add the job to the requester's jobs collection
        await _firestore
            .collection('users')
            .doc(requestData['requesterId'])
            .collection('jobs')
            .doc(job.id)
            .set(job.toJson());

        // Update the shared job's connected users list
        List<String> connectedUsers = List<String>.from(
          sharedJobData['connectedUsers'] ?? [],
        );
        if (!connectedUsers.contains(requestData['requesterId'])) {
          connectedUsers.add(requestData['requesterId']);
          await _firestore
              .collection('sharedJobs')
              .doc(requestData['connectionCode'])
              .update({'connectedUsers': connectedUsers});
        }
      }
    } catch (e) {
      print('Error responding to join request (detailed): $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Permission denied. Please check Firestore security rules.',
        );
      }
      throw e;
    }
  }

  // Add this method to the DatabaseService class
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    print('🔍 DatabaseService.getUserData called for userId: $userId');
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      print('📄 User document exists: ${doc.exists}');
      if (doc.exists) {
        final data = doc.data();
        print('📄 User data: $data');
        return data;
      }
      print('⚠️ User document does not exist');
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // Add this method to handle job deletion
  Future<void> deleteJob(String jobId) async {
    try {
      // First check if this is a shared job
      final jobDoc = await jobsCollection.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      final isShared = jobData?['isShared'] ?? false;

      if (isShared) {
        final connectionCode = jobData?['connectionCode'];
        if (connectionCode != null) {
          // This is a shared job, so we need to remove the user from the connected users list
          final sharedJobDoc =
              await _firestore
                  .collection('sharedJobs')
                  .doc(connectionCode)
                  .get();

          if (sharedJobDoc.exists) {
            List<String> connectedUsers = List<String>.from(
              sharedJobDoc.data()?['connectedUsers'] ?? [],
            );

            // Remove this user from the list
            connectedUsers.removeWhere((userId) => userId == uid);

            // Update the shared job document
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .update({'connectedUsers': connectedUsers});

            print('User removed from shared job connected users');
          }
        }
      }

      // Now delete the job from the user's collection
      await jobsCollection.doc(jobId).delete();

      // Delete all time entries for this job
      await deleteAllTimeEntriesForJob(jobId);

      print('Job deleted successfully');
    } catch (e) {
      print('Error deleting job: $e');
      throw e;
    }
  }

  // Add method to delete all time entries for a job
  Future<void> deleteAllTimeEntriesForJob(String jobId) async {
    try {
      print('🗑️ Starting deletion of all time entries for job $jobId');

      // First, check if this is a shared job
      final jobDoc = await jobsCollection.doc(jobId).get();
      final jobData = jobDoc.data() as Map<String, dynamic>?;
      final isShared = jobData?['isShared'] ?? false;
      final connectionCode = jobData?['connectionCode'];

      // Delete from user's own collection
      print('🗑️ Deleting entries from user collection');
      final userEntriesSnapshot =
          await timeEntriesCollection.where('jobId', isEqualTo: jobId).get();

      for (var doc in userEntriesSnapshot.docs) {
        await doc.reference.delete();
      }

      // If it's a shared job, also delete from shared collection
      if (isShared && connectionCode != null) {
        print('🗑️ Deleting entries from shared job collection');
        final sharedEntriesSnapshot =
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('entries')
                .where('jobId', isEqualTo: jobId)
                .get();

        for (var doc in sharedEntriesSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Delete from any collection group queries
      print('🗑️ Cleaning up any remaining entries');
      final collectionGroupSnapshot =
          await _firestore
              .collectionGroup('timeEntries')
              .where('jobId', isEqualTo: jobId)
              .get();

      for (var doc in collectionGroupSnapshot.docs) {
        await doc.reference.delete();
      }

      print('✅ Successfully deleted all time entries for job $jobId');
    } catch (e) {
      print('❌ Error deleting time entries for job $jobId: $e');
      throw e;
    }
  }

  // Add this method to DatabaseService
  Future<void> updateUserClockState({
    bool? isClockedIn,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    String? jobId,
  }) async {
    try {
      final data = {
        'isClockedIn': isClockedIn,
        if (clockInTime != null) 'clockInTime': clockInTime.toIso8601String(),
        if (clockOutTime != null)
          'clockOutTime': clockOutTime.toIso8601String(),
        if (jobId != null) 'currentJobId': jobId,
      };

      await userCollection.doc(uid).update(data);
    } catch (e) {
      print('Error updating user clock state: $e');
      rethrow;
    }
  }

  // Add this method to delete a time entry
  Future<void> deleteTimeEntry(String entryId) async {
    try {
      // Delete from user's collection
      await timeEntriesCollection.doc(entryId).delete();

      // Check if this was a shared job entry and delete from shared collection if needed
      final sharedEntryQuery =
          await _firestore
              .collectionGroup('timeEntries')
              .where('id', isEqualTo: entryId)
              .where('userId', isEqualTo: uid)
              .get();

      for (var doc in sharedEntryQuery.docs) {
        await doc.reference.delete();
      }

      print('Time entry deleted: $entryId');
    } catch (e) {
      print('Error deleting time entry: $e');
      rethrow;
    }
  }

  // Add these methods to DatabaseService
  Future<int> getPendingRequestCount() async {
    if (currentUser == null) return 0;

    try {
      final snapshot =
          await _firestore
              .collection('jobRequests')
              .where('ownerId', isEqualTo: currentUser!.uid)
              .where('status', isEqualTo: 'pending')
              .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting pending request count: $e');
      return 0;
    }
  }

  Future<void> checkForPendingRequests() async {
    // This method just refreshes the pending requests
    await getPendingRequestCount();
  }

  Stream<List<TimeEntry>> getTimeEntriesStream() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('timeEntries')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return TimeEntry.fromFirestore(doc);
          }).toList();
        });
  }

  // Add this method to get the current user ID
  String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // Add these methods to the DatabaseService class

  Future<void> saveJob(Job job) async {
    await jobsCollection.doc(job.id).set(job.toJson());
  }

  Future<void> updateJob(Job job) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('Updating job in Firebase: ${job.id}, ${job.name}, ${job.color}');

      // Update in the user's jobs collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('jobs')
          .doc(job.id)
          .set(job.toJson(), SetOptions(merge: true));

      // If it's a shared job, also update in the shared jobs collection
      if (job.isShared && job.connectionCode != null) {
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(job.connectionCode)
            .update({
              'name': job.name,
              'color': job.color.value,
              'description': job.description,
            });
      }

      print('Job updated successfully in Firebase');
    } catch (e) {
      print('Error updating job in Firebase: $e');
      rethrow;
    }
  }

  Future<List<TimeEntry>> loadAllEntriesForJob(String jobId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // First, get the job to check if it's shared
      final jobDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('jobs')
              .doc(jobId)
              .get();

      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final job = Job.fromJson(jobDoc.data()!);

      if (!job.isShared) {
        // For non-shared jobs, just return the user's own entries
        return await loadTimeEntriesForJob(jobId);
      }

      // For shared jobs, get entries from all connected users
      final List<TimeEntry> allEntries = [];

      // First add the creator's entries
      if (job.creatorId != null) {
        final creatorEntries =
            await _firestore
                .collection('users')
                .doc(job.creatorId)
                .collection('timeEntries')
                .where('jobId', isEqualTo: jobId)
                .get();

        for (var doc in creatorEntries.docs) {
          final entry = TimeEntry.fromFirestore(doc);
          allEntries.add(entry);
        }
      }

      // Then add entries from all connected users
      if (job.connectedUsers != null) {
        for (var userId in job.connectedUsers!) {
          if (userId == job.creatorId) continue; // Skip creator, already added

          final userEntries =
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('timeEntries')
                  .where('jobId', isEqualTo: jobId)
                  .get();

          for (var doc in userEntries.docs) {
            final entry = TimeEntry.fromFirestore(doc);
            allEntries.add(entry);
          }
        }
      }

      return allEntries;
    } catch (e) {
      print('Error loading all entries for job $jobId: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    try {
      final Map<String, String> userNames = {};

      // Use a batch get to efficiently retrieve multiple users
      final userDocs = await Future.wait(
        userIds.map(
          (userId) => _firestore.collection('users').doc(userId).get(),
        ),
      );

      for (var doc in userDocs) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          // Use name field from the user document
          userNames[doc.id] = data['name'] ?? 'Unknown User';
        }
      }

      print('Retrieved user names: $userNames');
      return userNames;
    } catch (e) {
      print('Error getting user names: $e');
      return {};
    }
  }

  Future<List<TimeEntry>> loadTimeEntriesForJob(String jobId) async {
    if (currentUser == null) {
      return [];
    }

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(currentUser!.uid)
              .collection('timeEntries')
              .where('jobId', isEqualTo: jobId)
              .get();

      return snapshot.docs.map((doc) => TimeEntry.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error loading time entries for job $jobId: $e');
      return [];
    }
  }

  Future<void> updateTimeEntry(TimeEntry entry) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update in user's collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timeEntries')
          .doc(entry.id)
          .update(entry.toJson());

      // If this is a shared job entry, also update in the shared job's collection
      final job = await getJobById(entry.jobId);
      if (job != null && job.isShared) {
        await _firestore
            .collection('sharedJobs')
            .doc(job.connectionCode)
            .collection('timeEntries')
            .doc(entry.id)
            .update(entry.toJson());
      }
    } catch (e) {
      print('Error updating time entry: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile({required String name}) async {
    try {
      await _firestore.collection('users').doc(uid).update({'name': name});
      print('✅ User profile updated successfully');
    } catch (e) {
      print('❌ Error updating user profile: $e');
      rethrow;
    }
  }

  Future<List<Expense>> getExpensesForJob(String jobId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // First check if this is a shared job
      final jobDoc = await jobsCollection.doc(jobId).get();
      if (!jobDoc.exists) return [];

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      if (jobData?['isShared'] ?? false) {
        // For shared jobs, get expenses from the shared job's expenses collection
        final connectionCode = jobData?['connectionCode'];
        if (connectionCode == null) return [];

        final snapshot =
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('expenses')
                .where('jobId', isEqualTo: jobId)
                .get();

        return snapshot.docs
            .map((doc) => Expense.fromJson({'id': doc.id, ...doc.data()}))
            .toList();
      } else {
        // For regular jobs, get expenses from the user's expenses collection
        final snapshot =
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('expenses')
                .where('jobId', isEqualTo: jobId)
                .get();

        return snapshot.docs
            .map((doc) => Expense.fromJson({'id': doc.id, ...doc.data()}))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting expenses: $e');
      return [];
    }
  }

  Future<void> addExpense(Expense expense) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // First check if this is a shared job
      final jobDoc = await jobsCollection.doc(expense.jobId).get();
      if (!jobDoc.exists) return;

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      if (jobData?['isShared'] ?? false) {
        // For shared jobs, save to the shared job's expenses collection
        final connectionCode = jobData?['connectionCode'];
        if (connectionCode == null) return;

        await _firestore
            .collection('sharedJobs')
            .doc(connectionCode)
            .collection('expenses')
            .doc(expense.id)
            .set(expense.toJson());
      } else {
        // For regular jobs, save to the user's expenses collection
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(expense.id)
            .set(expense.toJson());
      }
    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // First check if this is a shared job
      final jobDoc = await jobsCollection.doc(expense.jobId).get();
      if (!jobDoc.exists) return;

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      if (jobData?['isShared'] ?? false) {
        // For shared jobs, update in the shared job's expenses collection
        final connectionCode = jobData?['connectionCode'];
        if (connectionCode == null) return;

        await _firestore
            .collection('sharedJobs')
            .doc(connectionCode)
            .collection('expenses')
            .doc(expense.id)
            .update(expense.toJson());
      } else {
        // For regular jobs, update in the user's expenses collection
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(expense.id)
            .update(expense.toJson());
      }
    } catch (e) {
      debugPrint('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // First check if this is a shared job
      final jobDoc = await jobsCollection.doc(expenseId).get();
      if (!jobDoc.exists) return;

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      if (jobData?['isShared'] ?? false) {
        // For shared jobs, delete from the shared job's expenses collection
        final connectionCode = jobData?['connectionCode'];
        if (connectionCode == null) return;

        await _firestore
            .collection('sharedJobs')
            .doc(connectionCode)
            .collection('expenses')
            .doc(expenseId)
            .delete();
      } else {
        // For regular jobs, delete from the user's expenses collection
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(expenseId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      rethrow;
    }
  }

  Future<List<TimeEntry>> getTimeEntriesForJob(String jobId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // First check if this is a shared job
      final jobDoc = await jobsCollection.doc(jobId).get();
      if (!jobDoc.exists) return [];

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      if (jobData?['isShared'] ?? false) {
        // For shared jobs, only get entries from the shared job's entries collection
        final connectionCode = jobData?['connectionCode'];
        if (connectionCode == null) return [];

        final snapshot =
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('entries')
                .where('jobId', isEqualTo: jobId)
                .orderBy('clockInTime', descending: true)
                .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          DateTime parseDateTime(dynamic value) {
            if (value is Timestamp) {
              return value.toDate();
            } else if (value is String) {
              return DateTime.parse(value);
            }
            throw Exception('Invalid date format');
          }

          return TimeEntry(
            id: doc.id,
            jobId: data['jobId'],
            jobName: data['jobName'],
            jobColor: ui.Color(data['jobColor']),
            clockInTime: parseDateTime(data['clockInTime']),
            clockOutTime: parseDateTime(data['clockOutTime']),
            duration: Duration(minutes: data['duration']),
            description: data['description'],
            userId: data['userId'],
            userName: data['userName'],
            date: parseDateTime(data['clockInTime']),
          );
        }).toList();
      } else {
        // For regular jobs, get entries from the user's timeEntries collection
        final snapshot =
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('timeEntries')
                .where('jobId', isEqualTo: jobId)
                .orderBy('clockInTime', descending: true)
                .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          DateTime parseDateTime(dynamic value) {
            if (value is Timestamp) {
              return value.toDate();
            } else if (value is String) {
              return DateTime.parse(value);
            }
            throw Exception('Invalid date format');
          }

          return TimeEntry(
            id: doc.id,
            jobId: data['jobId'],
            jobName: data['jobName'],
            jobColor: ui.Color(data['jobColor']),
            clockInTime: parseDateTime(data['clockInTime']),
            clockOutTime: parseDateTime(data['clockOutTime']),
            duration: Duration(minutes: data['duration']),
            description: data['description'],
            userId: data['userId'],
            userName: data['userName'],
            date: parseDateTime(data['clockInTime']),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error getting time entries: $e');
      return [];
    }
  }

  Future<Job?> getJobById(String jobId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // First check user's jobs
      final userJobDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('jobs')
              .doc(jobId)
              .get();

      if (userJobDoc.exists) {
        return Job.fromFirestore(userJobDoc);
      }

      // Then check shared jobs
      final sharedJobDoc =
          await _firestore.collection('sharedJobs').doc(jobId).get();

      if (sharedJobDoc.exists) {
        return Job.fromFirestore(sharedJobDoc);
      }

      return null;
    } catch (e) {
      print('Error getting job by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getJobDataForExport(String jobId) async {
    try {
      print('📊 Getting all data for job $jobId for export');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the job document
      final jobDoc = await jobsCollection.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      final isShared = jobData?['isShared'] ?? false;
      final connectionCode = jobData?['connectionCode'];

      // Get all time entries
      List<TimeEntry> entries;
      if (isShared && connectionCode != null) {
        // For shared jobs, get entries from the shared collection
        final entriesSnapshot =
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('entries')
                .where('jobId', isEqualTo: jobId)
                .orderBy('clockInTime', descending: true)
                .get();

        entries =
            entriesSnapshot.docs.map((doc) {
              final data = doc.data();
              DateTime parseDateTime(dynamic value) {
                if (value is Timestamp) {
                  return value.toDate();
                } else if (value is String) {
                  return DateTime.parse(value);
                }
                throw Exception('Invalid date format');
              }

              return TimeEntry(
                id: doc.id,
                jobId: data['jobId'],
                jobName: data['jobName'],
                jobColor: ui.Color(data['jobColor']),
                clockInTime: parseDateTime(data['clockInTime']),
                clockOutTime: parseDateTime(data['clockOutTime']),
                duration: Duration(minutes: data['duration']),
                description: data['description'],
                userId: data['userId'],
                userName: data['userName'],
                date: parseDateTime(data['clockInTime']),
              );
            }).toList();
      } else {
        // For regular jobs, get entries from user's collection
        entries = await loadTimeEntriesForJob(jobId);
      }

      // Get all expenses
      List<Expense> expenses;
      if (isShared && connectionCode != null) {
        // For shared jobs, get expenses from the shared collection
        final expensesSnapshot =
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('expenses')
                .where('jobId', isEqualTo: jobId)
                .get();

        expenses =
            expensesSnapshot.docs
                .map((doc) => Expense.fromJson({'id': doc.id, ...doc.data()}))
                .toList();
      } else {
        // For regular jobs, get expenses from user's collection
        expenses = await getExpensesForJob(jobId);
      }

      // Get user names for all entries and expenses
      final userIds =
          {
            ...entries.map((e) => e.userId),
            ...expenses.map((e) => e.userId),
          }.toList();
      final userNames = await getUserNames(userIds);

      // Calculate totals
      final totalHours = entries.fold<double>(
        0,
        (sum, entry) => sum + entry.duration.inMinutes / 60,
      );
      final totalExpenses = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      // Return all data in a structured format
      return {
        'job': {
          'id': jobId,
          'name': jobData?['name'] ?? 'Unnamed Job',
          'color': jobData?['color'],
          'description': jobData?['description'],
          'isShared': isShared,
          'connectionCode': connectionCode,
          'creatorId': jobData?['creatorId'],
          'createdAt': jobData?['createdAt']?.toDate().toIso8601String(),
        },
        'entries':
            entries
                .map(
                  (e) => {
                    'id': e.id,
                    'userId': e.userId,
                    'userName': e.userName ?? userNames[e.userId] ?? 'Unknown',
                    'clockInTime': e.clockInTime.toIso8601String(),
                    'clockOutTime': e.clockOutTime.toIso8601String(),
                    'duration': e.duration.inMinutes,
                    'description': e.description,
                  },
                )
                .toList(),
        'expenses':
            expenses
                .map(
                  (e) => {
                    'id': e.id,
                    'userId': e.userId,
                    'userName': e.userName ?? userNames[e.userId] ?? 'Unknown',
                    'date': e.date.toIso8601String(),
                    'amount': e.amount,
                    'description': e.description,
                    'receiptUrl': e.receiptUrl,
                  },
                )
                .toList(),
        'totals': {'totalHours': totalHours, 'totalExpenses': totalExpenses},
      };
    } catch (e) {
      print('❌ Error getting job data for export: $e');
      rethrow;
    }
  }

  Future<String> exportJobToPdf(String jobId) async {
    try {
      print('📄 Starting PDF export for job $jobId');
      final data = await getJobDataForExport(jobId);
      final job = data['job'] as Map<String, dynamic>;
      final entries = data['entries'] as List<dynamic>;
      final expenses = data['expenses'] as List<dynamic>;
      final totals = data['totals'] as Map<String, dynamic>;

      // Create a temporary directory for the PDF
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${job['name']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${tempDir.path}/$fileName';

      // Create PDF document
      final pdf = pw.Document();
      final font = await rootBundle.load(
        "assets/fonts/Poppins/Poppins-Regular.ttf",
      );
      final ttf = pw.Font.ttf(font);

      // Add content to PDF
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            theme: pw.ThemeData.withFont(base: ttf),
          ),
          build:
              (context) => [
                // Header
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    job['name'],
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),

                // Job details
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Job Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text('ID: ${job['id']}'),
                      pw.Text('Description: ${job['description'] ?? 'N/A'}'),
                      pw.Text('Created: ${job['createdAt'] ?? 'N/A'}'),
                      pw.Text(
                        'Type: ${job['isShared'] ? 'Shared Job' : 'Personal Job'}',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Time entries
                pw.Header(level: 1, child: pw.Text('Time Entries')),
                pw.Table.fromTextArray(
                  headers: ['Date', 'User', 'Duration', 'Description'],
                  data:
                      entries
                          .map(
                            (entry) => [
                              DateFormat(
                                'yyyy-MM-dd',
                              ).format(DateTime.parse(entry['clockInTime'])),
                              entry['userName'],
                              '${(entry['duration'] / 60).toStringAsFixed(1)} hours',
                              entry['description'] ?? '',
                            ],
                          )
                          .toList(),
                ),
                pw.SizedBox(height: 20),

                // Expenses
                pw.Header(level: 1, child: pw.Text('Expenses')),
                pw.Table.fromTextArray(
                  headers: ['Date', 'User', 'Amount', 'Description'],
                  data:
                      expenses
                          .map(
                            (expense) => [
                              DateFormat(
                                'yyyy-MM-dd',
                              ).format(DateTime.parse(expense['date'])),
                              expense['userName'],
                              '${expense['amount'].toStringAsFixed(2)} kr',
                              expense['description'] ?? '',
                            ],
                          )
                          .toList(),
                ),
                pw.SizedBox(height: 20),

                // Totals
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Summary',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Total Hours: ${totals['totalHours'].toStringAsFixed(1)}',
                      ),
                      pw.Text(
                        'Total Expenses: ${totals['totalExpenses'].toStringAsFixed(2)} kr',
                      ),
                    ],
                  ),
                ),
              ],
        ),
      );

      // Save the PDF
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      print('✅ PDF exported successfully to $filePath');

      return filePath;
    } catch (e) {
      print('❌ Error exporting job to PDF: $e');
      rethrow;
    }
  }
}
