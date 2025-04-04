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
import 'package:timagatt/services/database_service.dart';

class SharedJobsProvider extends BaseProvider {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService(
    uid: FirebaseAuth.instance.currentUser?.uid ?? '',
  );
  bool _isInitialized = false;
  int _pendingRequestCount = 0;
  Map<String, String> _userNames = {};
  StreamSubscription? _sharedJobsSubscription;
  List<Map<String, dynamic>> pendingRequests = [];
  Timer? _notificationTimer;
  bool isPaidUser = true;
  List<Job> jobs = [];
  List<Job> sharedJobs = [];
  SettingsProvider? _settingsProvider;
  bool isLoading = false;
  String? error;

  bool get isInitialized => _isInitialized;
  String? get currentUserId => _auth.currentUser?.uid;
  int get pendingRequestCount => _pendingRequestCount;
  bool get isAuthenticated => currentUserId != null;

  @override
  void onUserAuthenticated() {
    startNotificationChecks();
    listenToSharedJobs();
  }

  @override
  void onUserLoggedOut() {
    _notificationTimer?.cancel();
    pendingRequests = [];
    sharedJobs = [];
    _sharedJobsSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _sharedJobsSubscription?.cancel();
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .get();

    return snapshot.docs.length;
  }

  Future<void> loadPendingRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot =
          await _firestore
              .collection('sharedJobs')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'pending')
              .get();

      _pendingRequestCount = snapshot.docs.length;
      notifyListeners();
    } catch (e) {
      print('Error loading pending requests: $e');
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

    // Add to shared jobs list only
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

    // Load jobs immediately
    await loadSharedJobs();

    // Start listening to shared jobs
    listenToSharedJobs();
  }

  Future<void> saveJobsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jobsJson = jsonEncode(jobs.map((job) => job.toJson()).toList());
    await prefs.setString('jobs', jobsJson);
  }

  String _generateConnectionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6, // 6-character code
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Future<Job?> createSharedJob(Job job, BuildContext context) async {
    try {
      print('🔄 Creating shared job: ${job.name}');

      // Generate a connection code if not provided
      if (job.connectionCode == null) {
        final connectionCode = _generateConnectionCode();
        job = job.copyWith(
          id: connectionCode, // Use connection code as ID
          connectionCode: connectionCode,
          creatorId: currentUserId,
        );
      }

      print('📝 Job details:');
      print('- Name: ${job.name}');
      print('- Connection Code: ${job.connectionCode}');
      print('- Creator ID: ${job.creatorId}');
      print('- Is Public: ${job.isPublic}');

      // Create the shared job document in Firestore
      final sharedJobData = {
        'id': job.connectionCode, // Use connection code as ID
        'name': job.name,
        'color': job.color.value,
        'creatorId': job.creatorId,
        'connectionCode': job.connectionCode,
        'isShared': true,
        'isPublic': job.isPublic,
        'connectedUsers': [currentUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to sharedJobs collection
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(job.connectionCode)
          .set(sharedJobData);

      // Save to user's jobs collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('jobs')
          .doc(job.id)
          .set(job.toJson());

      print('✅ Job created successfully in Firestore');

      // Add to local jobs list
      jobs.add(job);
      sharedJobs.add(job);

      // Save to local storage
      await saveJobsToLocalStorage();

      // Notify listeners
      notifyListeners();

      print('✅ Job added to local lists and storage');

      // Navigate to jobs overview
      navigateToJobsOverview(context);

      return job;
    } catch (e) {
      print('❌ Error creating shared job: $e');
      return null;
    }
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

  Future<void> deleteSharedJob(Job job) async {
    try {
      if (!isAuthenticated) {
        throw Exception('Cannot delete shared job: Not authenticated');
      }

      print('🗑️ Attempting to delete shared job: ${job.name} (${job.id})');

      // Check if job has a connection code
      final connectionCode = job.connectionCode;
      if (connectionCode == null) {
        throw Exception('Cannot delete shared job: Missing connection code');
      }

      // Get the shared job document to check permissions
      final jobDoc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(connectionCode)
              .get();

      if (!jobDoc.exists) {
        throw Exception('Shared job not found');
      }

      final jobData = jobDoc.data();
      if (jobData == null) {
        throw Exception('Shared job data is null');
      }

      // Check if current user is the creator
      if (jobData['creatorId'] == currentUserId) {
        print('👑 User is creator, deleting entire job');
        // Delete all entries in the entries subcollection
        final entriesSnapshot =
            await FirebaseFirestore.instance
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('entries')
                .get();

        for (var doc in entriesSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete all expenses in the expenses subcollection
        final expensesSnapshot =
            await FirebaseFirestore.instance
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('expenses')
                .get();

        for (var doc in expensesSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete job references from all connected users' collections
        final connectedUsers = List<String>.from(
          jobData['connectedUsers'] ?? [],
        );
        for (var userId in connectedUsers) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('jobs')
                .doc(job.id)
                .delete();
          } catch (e) {
            print(
              'Warning: Failed to delete job reference for user $userId: $e',
            );
          }
        }

        // Delete the shared job document itself
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(connectionCode)
            .delete();

        print('✅ Successfully deleted shared job and all related data');
      } else {
        print('👤 User is not creator, removing from connected users');
        // Just remove the user from connectedUsers
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(connectionCode)
            .update({
              'connectedUsers': FieldValue.arrayRemove([currentUserId]),
            });

        // Remove from user's jobs collection
        if (currentUserId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('jobs')
              .doc(job.id)
              .delete();
        }
      }

      // Remove from local lists
      jobs.removeWhere((j) => j.id == job.id);
      sharedJobs.removeWhere((j) => j.id == job.id);

      // Notify listeners
      notifyListeners();

      print('✅ Shared job deletion completed successfully');
    } catch (e) {
      print('❌ Error deleting shared job: $e');
      throw e;
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

      // Get shared jobs where user is either creator or in connectedUsers
      final sharedJobsSnapshot =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .where('creatorId', isEqualTo: user.uid)
              .get();

      final joinedJobsSnapshot =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .where('connectedUsers', arrayContains: user.uid)
              .get();

      print(
        '📊 Found ${sharedJobsSnapshot.docs.length} created jobs and ${joinedJobsSnapshot.docs.length} joined jobs',
      );

      // Process jobs from sharedJobs collection
      final loadedJobs = <Job>[];
      final processedCodes = <String>{};

      // Process created jobs
      for (final doc in sharedJobsSnapshot.docs) {
        final data = doc.data();
        final code = doc.id;
        if (!processedCodes.contains(code)) {
          print('🔍 Processing created job: ${data['name']} (${code})');
          loadedJobs.add(
            Job(
              id: code,
              name: data['name'] ?? 'Unnamed Job',
              color: Color(data['color'] ?? Colors.blue.value),
              isShared: true,
              isPublic: data['isPublic'] ?? true,
              connectionCode: code,
              creatorId: data['creatorId'],
              connectedUsers:
                  data['connectedUsers'] != null
                      ? List<String>.from(data['connectedUsers'])
                      : [],
            ),
          );
          processedCodes.add(code);
        }
      }

      // Process joined jobs
      for (final doc in joinedJobsSnapshot.docs) {
        final data = doc.data();
        final code = doc.id;
        if (!processedCodes.contains(code)) {
          print('🔍 Processing joined job: ${data['name']} (${code})');
          loadedJobs.add(
            Job(
              id: code,
              name: data['name'] ?? 'Unnamed Job',
              color: Color(data['color'] ?? Colors.blue.value),
              isShared: true,
              isPublic: data['isPublic'] ?? true,
              connectionCode: code,
              creatorId: data['creatorId'],
              connectedUsers:
                  data['connectedUsers'] != null
                      ? List<String>.from(data['connectedUsers'])
                      : [],
            ),
          );
          processedCodes.add(code);
        }
      }

      print('✅ Loaded ${loadedJobs.length} unique shared jobs');
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

      // First check if the shared job document exists
      final jobDoc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(connectionCode)
              .get();

      print('📄 Shared job document exists: ${jobDoc.exists}');
      if (jobDoc.exists) {
        print('📄 Shared job data: ${jobDoc.data()}');
      }

      // Now get the entries
      final entriesRef = FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(connectionCode)
          .collection('entries');

      print(
        '🔍 Querying entries collection at: sharedJobs/$connectionCode/entries',
      );

      final snapshot =
          await entriesRef.orderBy('timestamp', descending: true).get();

      print('📊 Found ${snapshot.docs.length} entries');

      if (snapshot.docs.isEmpty) {
        print('⚠️ No entries found in collection');
        return [];
      }

      // Log each entry's data for debugging
      for (var doc in snapshot.docs) {
        print('📝 Entry data: ${doc.data()}');
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
          .doc(code)
          .set({
            'id': code,
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
    if (!isAuthenticated || currentUserId == null) {
      print(
        '❌ Cannot set up shared jobs listener: Not authenticated or no user ID',
      );
      return;
    }

    print('🔄 Setting up shared jobs listener for user: $currentUserId');

    // Cancel existing subscription if any
    _sharedJobsSubscription?.cancel();

    // Listen to sharedJobs collection where user is either creator or in connectedUsers
    _sharedJobsSubscription = FirebaseFirestore.instance
        .collection('sharedJobs')
        .where('creatorId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
          print(
            '📥 Received ${snapshot.docs.length} created shared jobs from Firestore',
          );

          final processedCodes = <String>{};
          final updatedJobs = <Job>[];

          // Process created jobs
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final code = doc.id;
            if (!processedCodes.contains(code)) {
              print('🔍 Processing created job: ${data['name']} (${code})');
              updatedJobs.add(
                Job(
                  id: code,
                  name: data['name'] ?? 'Unnamed Job',
                  color: Color(data['color'] ?? Colors.blue.value),
                  isShared: true,
                  isPublic: data['isPublic'] ?? true,
                  connectionCode: code,
                  creatorId: data['creatorId'],
                  connectedUsers:
                      data['connectedUsers'] != null
                          ? List<String>.from(data['connectedUsers'])
                          : [],
                ),
              );
              processedCodes.add(code);
            }
          }

          // Also get jobs where user is in connectedUsers
          FirebaseFirestore.instance
              .collection('sharedJobs')
              .where('connectedUsers', arrayContains: currentUserId)
              .get()
              .then((joinedSnapshot) {
                print(
                  '📥 Received ${joinedSnapshot.docs.length} joined shared jobs from Firestore',
                );

                // Process joined jobs
                for (final doc in joinedSnapshot.docs) {
                  final data = doc.data();
                  final code = doc.id;
                  if (!processedCodes.contains(code)) {
                    print(
                      '🔍 Processing joined job: ${data['name']} (${code})',
                    );
                    updatedJobs.add(
                      Job(
                        id: code,
                        name: data['name'] ?? 'Unnamed Job',
                        color: Color(data['color'] ?? Colors.blue.value),
                        isShared: true,
                        isPublic: data['isPublic'] ?? true,
                        connectionCode: code,
                        creatorId: data['creatorId'],
                        connectedUsers:
                            data['connectedUsers'] != null
                                ? List<String>.from(data['connectedUsers'])
                                : [],
                      ),
                    );
                    processedCodes.add(code);
                  }
                }

                print(
                  '✅ Updated shared jobs list with ${updatedJobs.length} unique jobs',
                );
                sharedJobs = updatedJobs;
                notifyListeners();
              });
        });
  }

  // Add this new method to SharedJobsProvider
  Future<void> deleteSharedJobById(String jobId, String connectionCode) async {
    try {
      if (!isAuthenticated) {
        throw Exception('Cannot delete shared job: Not authenticated');
      }

      print(
        '🔍 Finding shared job with ID: $jobId and connection code: $connectionCode',
      );

      // Get the shared job document to check permissions
      final jobDoc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(connectionCode)
              .get();

      if (!jobDoc.exists) {
        throw Exception('Shared job not found');
      }

      final jobData = jobDoc.data();
      if (jobData == null) {
        throw Exception('Shared job data is null');
      }

      // Check if current user is the creator
      if (jobData['creatorId'] == currentUserId) {
        print('👑 User is creator, deleting entire job');
        // Delete all entries in the entries subcollection
        final entriesSnapshot =
            await FirebaseFirestore.instance
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('entries')
                .get();

        for (var doc in entriesSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete all expenses in the expenses subcollection
        final expensesSnapshot =
            await FirebaseFirestore.instance
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('expenses')
                .get();

        for (var doc in expensesSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete job references from all connected users' collections
        final connectedUsers = List<String>.from(
          jobData['connectedUsers'] ?? [],
        );
        for (var userId in connectedUsers) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('jobs')
                .doc(jobId)
                .delete();
          } catch (e) {
            print(
              'Warning: Failed to delete job reference for user $userId: $e',
            );
          }
        }

        // Delete the shared job document itself
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(connectionCode)
            .delete();

        print('✅ Successfully deleted shared job and all related data');
      } else {
        print('👤 User is not creator, removing from connected users');
        // Just remove the user from connectedUsers
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(connectionCode)
            .update({
              'connectedUsers': FieldValue.arrayRemove([currentUserId]),
            });

        // Remove from user's jobs collection
        if (currentUserId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('jobs')
              .doc(jobId)
              .delete();
        }
      }

      // Remove from local lists
      jobs.removeWhere((j) => j.id == jobId);
      sharedJobs.removeWhere((j) => j.id == jobId);

      // Notify listeners
      notifyListeners();

      print('✅ Shared job deletion completed successfully');
    } catch (e) {
      print('❌ Error deleting shared job: $e');
      throw e;
    }
  }

  void setSettingsProvider(SettingsProvider provider) {
    _settingsProvider = provider;
  }

  // Add navigation method
  void navigateToJobsOverview(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/jobs');
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await loadPendingRequests();
      _setupSharedJobsListener();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing SharedJobsProvider: $e');
    }
  }

  void _setupSharedJobsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sharedJobsSubscription = FirebaseFirestore.instance
        .collection('sharedJobs')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          _pendingRequestCount = snapshot.docs.length;
          notifyListeners();
        });
  }

  Future<void> addSharedJob(Job job) async {
    try {
      // Check if job already exists in the list
      if (sharedJobs.any((j) => j.id == job.id)) {
        print('Job ${job.id} already exists in shared jobs list');
        return;
      }

      // Add to shared jobs collection
      await _databaseService.saveJob(job);

      // Update local state
      final updatedJobs = [...sharedJobs, job];
      sharedJobs = updatedJobs;
      print('Added job ${job.id} to shared jobs list');
    } catch (e) {
      print('Error adding shared job: $e');
      rethrow;
    }
  }
}
