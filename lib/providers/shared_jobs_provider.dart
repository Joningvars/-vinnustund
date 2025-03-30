import 'package:flutter/material.dart';
import 'package:timagatt/providers/base_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/utils/color_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timagatt/models/time_entry.dart';

class SharedJobsProvider extends BaseProvider {
  List<Map<String, dynamic>> pendingRequests = [];
  Timer? _notificationTimer;
  bool isPaidUser = true;
  List<Job> jobs = [];
  List<Job> sharedJobs = [];
  SettingsProvider? _settingsProvider;
  Map<String, String> _userNames = {};

  bool get isAuthenticated => currentUserId != null;

  @override
  void onUserAuthenticated() {
    startNotificationChecks();
  }

  @override
  void onUserLoggedOut() {
    _notificationTimer?.cancel();
    pendingRequests = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void startNotificationChecks() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(Duration(minutes: 1), (_) {
      checkForPendingRequests();
    });
  }

  Future<void> checkForPendingRequests() async {
    if (databaseService != null) {
      try {
        final count = await getPendingRequestCount();
        if (count > 0) {
          // Notify the UI that there are pending requests
          notifyListeners();
        }
      } catch (e) {
        print('Error checking for pending requests: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPendingJoinRequests() async {
    if (databaseService == null) {
      return [];
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('joinRequests')
              .where('creatorId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'pending')
              .get();

      pendingRequests = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data();
          data['id'] = doc.id;

          // Get requester name
          try {
            final requesterData = await databaseService!.getUserData(
              data['requesterId'],
            );
            data['requesterName'] = requesterData?['name'] ?? 'Unknown User';
          } catch (e) {
            print('Error getting requester data: $e');
            data['requesterName'] = 'Unknown User';
          }

          return data;
        }).toList(),
      );

      return pendingRequests;
    } catch (e) {
      print('Error getting pending join requests: $e');
      // Return empty list instead of throwing
      return [];
    }
  }

  Future<int> getPendingRequestCount() async {
    if (databaseService == null) {
      return 0;
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('joinRequests')
              .where('creatorId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'pending')
              .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting pending request count: $e');
      return 0;
    }
  }

  Future<void> respondToJoinRequest(String requestId, bool approve) async {
    if (databaseService == null) {
      throw Exception('User not authenticated');
    }

    try {
      if (approve) {
        // Get the request data
        final requestDoc =
            await FirebaseFirestore.instance
                .collection('joinRequests')
                .doc(requestId)
                .get();

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        final requestData = requestDoc.data()!;

        // Manually approve the request
        await _manuallyApproveRequest(requestData);
      } else {
        // Manually deny the request
        await _manuallyDenyRequest(requestId);
      }

      // Refresh the pending requests list
      await getPendingJoinRequests();
      notifyListeners();
    } catch (e) {
      print('Error responding to join request: $e');
      throw e;
    }
  }

  Future<void> _manuallyApproveRequest(Map<String, dynamic> request) async {
    try {
      // 1. Update the request status
      await FirebaseFirestore.instance
          .collection('joinRequests')
          .doc(request['id'])
          .update({'status': 'approved'});

      // 2. Get the job data
      final sharedJobDoc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(request['connectionCode'])
              .get();

      if (!sharedJobDoc.exists) {
        throw Exception('Shared job not found');
      }

      final sharedJobData = sharedJobDoc.data()!;

      // 3. Create a job for the requester
      final job = {
        'id': request['jobId'],
        'name': sharedJobData['name'],
        'color': sharedJobData['color'],
        'creatorId': sharedJobData['creatorId'],
        'connectionCode': request['connectionCode'],
        'isShared': true,
        'isPublic': sharedJobData['isPublic'] ?? true,
      };

      // 4. Add the job to the requester's jobs collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(request['requesterId'])
          .collection('jobs')
          .doc(job['id'].toString())
          .set(job);

      // 5. Update the shared job's connected users list
      List<String> connectedUsers = List<String>.from(
        sharedJobData['connectedUsers'] ?? [],
      );

      if (!connectedUsers.contains(request['requesterId'])) {
        final requesterId = request['requesterId'] as String;
        connectedUsers.add(requesterId);
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(request['connectionCode'])
            .update({'connectedUsers': connectedUsers});
      }

      print('Manual approval completed successfully');
    } catch (e) {
      print('Error in manual approval: $e');
      throw e;
    }
  }

  Future<void> _manuallyDenyRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('joinRequests')
          .doc(requestId)
          .update({'status': 'denied'});

      print('Manual denial completed successfully');
    } catch (e) {
      print('Error in manual denial: $e');
      throw e;
    }
  }

  Future<Job?> joinJobByCode(String code) async {
    try {
      print(' Attempting to join job with code: $code');
      if (code.isEmpty) {
        throw Exception('Please enter a connection code');
      }

      // Check if the shared job exists
      final sharedJobDoc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(code)
              .get();

      if (!sharedJobDoc.exists) {
        print('❌ Job not found with code: $code');
        throw Exception('Job not found with this code');
      }

      final jobData = sharedJobDoc.data()!;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null) {
        print('❌ No authenticated user found');
        throw Exception('You must be logged in to join a job');
      }

      // Ensure we have a consistent ID field
      final String jobId = jobData['id'] ?? jobData['jobId'] ?? '';
      if (jobId.isEmpty) {
        print('❌ Invalid job data: missing ID');
        throw Exception('Invalid job data');
      }

      // Check if user is already connected to this job
      final List<String> connectedUsers =
          jobData['connectedUsers'] != null
              ? List<String>.from(jobData['connectedUsers'])
              : [];

      if (connectedUsers.contains(currentUserId)) {
        print('ℹ️ User already connected to this job');
        throw Exception('You are already connected to this job');
      }

      // Check if the job is public or private
      final bool isPublic = jobData['isPublic'] ?? true;

      if (isPublic) {
        // For public jobs, add user directly to connectedUsers
        print('✅ Job is public, adding user directly');

        // Update the shared job document
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(code)
            .update({
              'connectedUsers': FieldValue.arrayUnion([currentUserId]),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // Create a job object for the user
        final job = Job(
          id: jobId,
          name: jobData['name'] ?? 'Unnamed Job',
          color: Color(jobData['color'] ?? Colors.blue.value),
          description: jobData['description'],
          isShared: true,
          isPublic: isPublic,
          connectionCode: code,
          creatorId: jobData['creatorId'],
          connectedUsers: [...connectedUsers, currentUserId],
          updatedAt: DateTime.now(),
        );

        // Add the job to the user's collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('jobs')
            .doc(jobId)
            .set(job.toJson());

        // Also add to local jobs list for immediate UI update
        jobs.add(job);
        notifyListeners();

        print('✅ Successfully joined public job');
        return job;
      } else {
        // For private jobs, add user to pendingRequests
        print('🔒 Job is private, adding user to pending requests');

        // Check if user is already in pendingRequests
        final List<String> pendingRequests =
            jobData['pendingRequests'] != null
                ? List<String>.from(jobData['pendingRequests'])
                : [];

        if (!pendingRequests.contains(currentUserId)) {
          // Add user to pendingRequests
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(code)
              .update({
                'pendingRequests': FieldValue.arrayUnion([currentUserId]),
                'updatedAt': FieldValue.serverTimestamp(),
              });

          print('✅ Successfully added to pendingRequests');
        } else {
          print('ℹ️ User already in pendingRequests list');
        }

        return null; // Return null since we haven't joined yet
      }
    } catch (e) {
      print('❌ Error joining job by code: $e');
      throw e;
    }
  }

  Future<void> _createJoinRequest(
    String code,
    Map<String, dynamic> jobData,
  ) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();

    await FirebaseFirestore.instance
        .collection('joinRequests')
        .doc(requestId)
        .set({
          'id': requestId,
          'connectionCode': code,
          'jobId': jobData['id'],
          'requesterId': currentUserId,
          'creatorId': jobData['creatorId'],
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Future<Job?> _joinPublicJob(String code, Map<String, dynamic> jobData) async {
    print('🔄 Joining public job: ${jobData['name']}');

    // Create a job object
    final job = Job(
      id: jobData['id'],
      name: jobData['name'],
      color: Color(jobData['color']),
      creatorId: jobData['creatorId'],
      connectionCode: code,
      isShared: true,
      isPublic: true,
    );

    // Add to local jobs list
    jobs.add(job);
    sharedJobs.add(job);

    // Update the connected users list in Firestore
    List<String> connectedUsers = List<String>.from(
      jobData['connectedUsers'] ?? [],
    );

    if (!connectedUsers.contains(currentUserId)) {
      print('🔄 Adding user to connectedUsers list');
      connectedUsers.add(currentUserId ?? '');
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(code)
          .update({'connectedUsers': connectedUsers});
    }

    // Save the job to the user's collection
    if (databaseService != null) {
      print('🔄 Saving job to user\'s collection');
      await databaseService!.saveJobs([job]);
    }

    await saveJobsToLocalStorage();
    notifyListeners();

    print('✅ Successfully joined public job: ${job.name}');
    return job;
  }

  @override
  Future<void> initializeApp() async {
    await super.initializeApp();

    // Start listening to shared jobs
    listenToSharedJobs();
  }

  Future<void> saveJobsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jobsJson = jsonEncode(jobs.map((job) => job.toJson()).toList());
    await prefs.setString('jobs', jobsJson);
  }

  Future<String?> createSharedJob(Job job) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Generate a unique code for connection
      final connectionCode = _generateUniqueCode();
      // Use timestamp as ID for consistency
      final jobId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create the shared job document in sharedJobs collection
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(connectionCode)
          .set({
            'id': jobId,
            'name': job.name,
            'color': job.color.value,
            'isPublic': job.isPublic,
            'creatorId': user.uid,
            'connectedUsers': [user.uid],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'connectionCode': connectionCode,
          });

      // Also add to user's jobs collection with the same data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('jobs')
          .doc(jobId)
          .set({
            'id': jobId,
            'name': job.name,
            'color': job.color.value,
            'isShared': true,
            'isPublic': job.isPublic,
            'connectionCode': connectionCode,
            'creatorId': user.uid,
            'connectedUsers': [user.uid],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Reload shared jobs
      await loadSharedJobs();

      // After successfully creating a shared job
      await refreshSharedJobs();

      return connectionCode;
    } catch (e) {
      print('Error creating shared job: $e');
      return null;
    }
  }

  String _generateCode() {
    final random = Random();
    final codeChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String connectionCode = '';
    for (int i = 0; i < 6; i++) {
      connectionCode += codeChars[random.nextInt(codeChars.length)];
    }
    return connectionCode;
  }

  String _generateUniqueCode() {
    final random = Random();
    final codeChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String connectionCode = '';
    for (int i = 0; i < 6; i++) {
      connectionCode += codeChars[random.nextInt(codeChars.length)];
    }
    return connectionCode;
  }

  void setSettingsProvider(SettingsProvider provider) {
    _settingsProvider = provider;
  }

  String translate(String key) {
    if (_settingsProvider != null) {
      return _settingsProvider!.translate(key);
    }
    return key; // Just return the key if settings provider not available
  }

  Future<bool> checkIfJobIsPrivate(String connectionCode) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(connectionCode)
              .get();

      if (!doc.exists) {
        throw Exception('Invalid connection code');
      }

      final isPublic = doc.data()?['isPublic'] ?? true;
      return !isPublic;
    } catch (e) {
      print('Error checking job privacy: $e');
      rethrow;
    }
  }

  Future<bool> deleteSharedJob(Job job) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if user is the creator
      if (job.creatorId != user.uid) {
        // If not creator, just remove from user's collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('jobs')
            .doc(job.id)
            .delete();

        // Also remove user from connected users in shared job
        if (job.connectionCode != null) {
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(job.connectionCode)
              .update({
                'connectedUsers': FieldValue.arrayRemove([user.uid]),
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }
      } else {
        // If creator, delete the shared job completely
        if (job.connectionCode != null) {
          // Delete all entries first
          final entriesSnapshot =
              await FirebaseFirestore.instance
                  .collection('sharedJobs')
                  .doc(job.connectionCode)
                  .collection('entries')
                  .get();

          final batch = FirebaseFirestore.instance.batch();
          for (final doc in entriesSnapshot.docs) {
            batch.delete(doc.reference);
          }

          // Delete the shared job document
          batch.delete(
            FirebaseFirestore.instance
                .collection('sharedJobs')
                .doc(job.connectionCode),
          );

          await batch.commit();
        }

        // Delete from user's collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('jobs')
            .doc(job.id)
            .delete();
      }

      // Reload shared jobs
      await loadSharedJobs();
      return true;
    } catch (e) {
      print('❌ Error deleting shared job: $e');
      return false;
    }
  }

  Future<bool> joinSharedJob(String code) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get the shared job
      final docRef = FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(code);
      final doc = await docRef.get();

      if (!doc.exists) throw Exception('Job not found');

      final data = doc.data()!;

      // Check if user is already connected
      final List<String> connectedUsers = List<String>.from(
        data['connectedUsers'] ?? [],
      );
      if (connectedUsers.contains(user.uid)) {
        return true; // Already connected
      }

      // Add user to connected users
      connectedUsers.add(user.uid);
      await docRef.update({'connectedUsers': connectedUsers});

      // Add to user's jobs
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('jobs')
          .doc(code)
          .set({
            'id': code,
            'name': data['name'],
            'color': data['color'],
            'isShared': true,
            'isPublic': data['isPublic'] ?? true,
            'connectionCode': code,
            'creatorId': data['creatorId'],
            'connectedUsers': connectedUsers,
          });

      return true;
    } catch (e) {
      print('Error joining shared job: $e');
      return false;
    }
  }

  Future<void> loadSharedJobs() async {
    try {
      print('🔄 Loading shared jobs');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return;
      }

      // Get jobs from user's collection that are marked as shared
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('jobs')
              .where('isShared', isEqualTo: true)
              .get();

      final loadedJobs =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return Job.fromFirestore(doc);
          }).toList();

      print('✅ Loaded ${loadedJobs.length} shared jobs');
      sharedJobs = loadedJobs;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading shared jobs: $e');
    }
  }

  Future<Job?> getSharedJobByCode(String connectionCode) async {
    try {
      final jobDoc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(connectionCode)
              .get();

      if (!jobDoc.exists) {
        return null;
      }

      final data = jobDoc.data()!;
      return Job(
        id: data['id'],
        name: data['name'] ?? 'Shared Job',
        color: Color(data['color'] ?? 0xFF2196F3),
        isShared: true,
        connectionCode: connectionCode,
        creatorId: data['creatorId'],
        connectedUsers:
            data['connectedUsers'] != null
                ? List<String>.from(data['connectedUsers'])
                : [],
      );
    } catch (e) {
      print('❌ Error getting shared job by code: $e');
      return null;
    }
  }

  Future<void> approveJoinRequest(String connectionCode, String userId) async {
    try {
      print('🔄 Approving join request for user: $userId');

      // Get the job document
      final jobDoc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(connectionCode)
              .get();

      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data()!;
      final now = DateTime.now();

      // Update the job document to move the user from pendingRequests to connectedUsers
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(connectionCode)
          .update({
            'pendingRequests': FieldValue.arrayRemove([userId]),
            'connectedUsers': FieldValue.arrayUnion([userId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Create a job object for the user
      final job = Job(
        id: jobData['id'],
        name: jobData['name'],
        color: Color(jobData['color']),
        description: jobData['description'],
        isShared: true,
        isPublic: false,
        connectionCode: connectionCode,
        creatorId: jobData['creatorId'],
        connectedUsers: List<String>.from(jobData['connectedUsers'] ?? [])
          ..add(userId),
        updatedAt: now,
      );

      // Add the job to the user's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('jobs')
          .doc(job.id)
          .set(job.toJson());

      print('✅ Successfully approved join request for user: $userId');

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      print('❌ Error approving join request: $e');
      throw e;
    }
  }

  Future<void> denyJoinRequest(String connectionCode, String userId) async {
    try {
      print('🔄 Denying join request for user: $userId');

      // Update the job document to remove the user from pendingRequests
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(connectionCode)
          .update({
            'pendingRequests': FieldValue.arrayRemove([userId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      print('✅ Successfully denied join request for user: $userId');

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      print('❌ Error denying join request: $e');
      throw e;
    }
  }

  // Method to add a time entry to a shared job
  Future<bool> addTimeEntryToSharedJob(
    TimeEntry entry,
    String connectionCode,
  ) async {
    try {
      print(
        '🔄 Adding time entry to shared job with connection code: $connectionCode',
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return false;
      }

      // Get user name if not already set
      String userName = entry.userName ?? '';
      if (userName.isEmpty) {
        final userData = await databaseService?.getUserData(user.uid);
        userName = userData?['name'] ?? 'Unknown User';
      }

      // Create a copy of the entry with additional metadata
      final sharedEntry = {
        ...entry.toJson(),
        'userId': user.uid,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
      };

      print(
        '🔄 Shared entry data: ${sharedEntry['jobName']} - ${sharedEntry['description']}',
      );
      print('🔄 Saving to: sharedJobs/$connectionCode/entries/${entry.id}');

      // Add entry to the shared job's entries collection
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(connectionCode)
          .collection('entries')
          .doc(entry.id)
          .set(sharedEntry);

      print(
        '✅ Time entry saved to shared job: ${entry.id} in collection: sharedJobs/$connectionCode/entries',
      );
      return true;
    } catch (e) {
      print('❌ Error adding time entry to shared job: $e');
      return false;
    }
  }

  // Method to get all entries for a shared job
  Future<List<TimeEntry>> getSharedJobEntries(String connectionCode) async {
    try {
      print(
        '🔍 Getting entries for shared job with connection code: $connectionCode',
      );

      final snapshot =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(connectionCode)
              .collection('entries')
              .orderBy('timestamp', descending: true)
              .get();

      print(
        '📊 Found ${snapshot.docs.length} entries for shared job: $connectionCode',
      );

      if (snapshot.docs.isEmpty) {
        print('⚠️ No entries found. Checking if the collection exists...');

        // Check if the shared job document exists
        final jobDoc =
            await FirebaseFirestore.instance
                .collection('sharedJobs')
                .doc(connectionCode)
                .get();

        if (jobDoc.exists) {
          print('✅ Shared job document exists: ${jobDoc.data()}');
        } else {
          print('❌ Shared job document does not exist');
        }
      }

      return snapshot.docs
          .map((doc) {
            try {
              return TimeEntry.fromJson(doc.data());
            } catch (e) {
              print('❌ Error parsing entry: ${e.toString()}');
              return null;
            }
          })
          .where((entry) => entry != null)
          .cast<TimeEntry>()
          .toList();
    } catch (e) {
      print('❌ Error getting shared job entries: $e');
      return [];
    }
  }

  // Add this method to sync user's jobs with shared jobs
  Future<void> syncUserJobs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('🔄 Syncing user jobs with shared jobs');

      // Get all shared jobs the user is connected to
      final sharedJobsQuery =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .where('connectedUsers', arrayContains: user.uid)
              .get();

      bool hasChanges = false;

      // For each shared job, ensure it exists in the user's collection
      for (final doc in sharedJobsQuery.docs) {
        final data = doc.data();
        final code = doc.id;

        // Check if job already exists in user's collection
        final userJobDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('jobs')
                .doc(code)
                .get();

        if (!userJobDoc.exists) {
          // Add to user's collection
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('jobs')
              .doc(code)
              .set({
                'id': code,
                'name': data['name'] ?? 'Shared Job',
                'color': data['color'] ?? Colors.blue.value,
                'isShared': true,
                'isPublic': data['isPublic'] ?? true,
                'connectionCode': code,
                'creatorId': data['creatorId'],
                'connectedUsers': data['connectedUsers'],
              });

          hasChanges = true;
        }
      }

      if (hasChanges) {
        await loadSharedJobs();
      }
    } catch (e) {
      print('❌ Error syncing user jobs: $e');
    }
  }

  Future<bool> connectUserToJob(String code) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      print('🔄 Connecting user to job with code: $code');

      // Check if the shared job exists
      final jobDoc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(code)
              .get();

      if (!jobDoc.exists) {
        print('❌ Job not found with code: $code');
        return false;
      }

      final jobData = jobDoc.data()!;
      final jobId =
          jobData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

      // Add user to connected users in shared job
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(code)
          .update({
            'connectedUsers': FieldValue.arrayUnion([user.uid]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Add job to user's jobs collection with all the same data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('jobs')
          .doc(jobId)
          .set({
            'id': jobId,
            'name': jobData['name'] ?? 'Shared Job',
            'color': jobData['color'] ?? Colors.blue.value,
            'isShared': true,
            'isPublic': jobData['isPublic'] ?? true,
            'connectionCode': code,
            'creatorId': jobData['creatorId'],
            'connectedUsers': FieldValue.arrayUnion([user.uid]),
            'createdAt': jobData['createdAt'],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Reload shared jobs
      await loadSharedJobs();

      return true;
    } catch (e) {
      print('❌ Error connecting to job: $e');
      return false;
    }
  }

  // Fix the saveTimeEntryToSharedJob method
  Future<bool> saveTimeEntryToSharedJob(TimeEntry entry, Job job) async {
    if (job.connectionCode == null) return false;

    // Reuse the existing implementation by calling the other method
    return addTimeEntryToSharedJob(entry, job.connectionCode!);
  }

  // Add this method to refresh shared jobs immediately after creation
  Future<void> refreshSharedJobs() async {
    if (!isAuthenticated) return;

    try {
      // Fetch shared jobs from Firestore
      final snapshot =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .where('connectedUsers', arrayContains: currentUserId)
              .get();

      final updatedJobs =
          snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();

      // Update the shared jobs list
      sharedJobs = updatedJobs;
      notifyListeners();

      print('📋 Refreshed shared jobs list: ${sharedJobs.length} jobs');
    } catch (e) {
      print('Error refreshing shared jobs: $e');
    }
  }

  // Add this method to handle null user names safely
  String? getUserNameSafely(String userId) {
    try {
      if (userId == null) return null;
      final userName = _userNames[userId];
      return userName;
    } catch (e) {
      print('Error getting user name for $userId: $e');
      return null;
    }
  }

  // Add this method to SharedJobsProvider
  void listenToSharedJobs() {
    if (!isAuthenticated || currentUserId == null) return;

    print('🔄 Setting up shared jobs listener for user: $currentUserId');

    // Listen to sharedJobs collection (note: no underscore)
    FirebaseFirestore.instance
        .collection('sharedJobs')
        .where('connectedUsers', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
          final updatedJobs =
              snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();

          print('📋 Received ${updatedJobs.length} shared jobs from Firestore');

          // Update the shared jobs list
          sharedJobs = updatedJobs;
          notifyListeners();
        });
  }
}
