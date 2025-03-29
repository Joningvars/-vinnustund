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

class SharedJobsProvider extends BaseProvider {
  List<Map<String, dynamic>> pendingRequests = [];
  Timer? _notificationTimer;
  bool isPaidUser = true;
  List<Job> jobs = [];
  List<Job> sharedJobs = [];
  SettingsProvider? _settingsProvider;

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
          final requesterData = await databaseService!.getUserData(
            data['requesterId'],
          );
          data['requesterName'] = requesterData?['name'] ?? 'Unknown User';

          return data;
        }).toList(),
      );

      return pendingRequests;
    } catch (e) {
      print('Error getting pending join requests: $e');
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
        throw Exception('Invalid connection code');
      }

      final sharedJobData = sharedJobDoc.data()!;
      final isPublic = sharedJobData['isPublic'] ?? true;

      if (!isPublic) {
        // For private jobs, create a join request
        await _createJoinRequest(code, sharedJobData);
        throw Exception('Join request sent. Waiting for approval.');
      }

      // For public jobs, join immediately
      final job = await _joinPublicJob(code, sharedJobData);
      return job;
    } catch (e) {
      print('Error joining job by code: $e');
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
      connectedUsers.add(currentUserId ?? '');
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(code)
          .update({'connectedUsers': connectedUsers});
    }

    // Save the job to the user's collection
    if (databaseService != null) {
      await databaseService!.saveJobs([job]);
    }

    await saveJobsToLocalStorage();
    notifyListeners();

    return job;
  }

  Future<void> initializeApp() async {
    // Initialize shared jobs data
    if (isAuthenticated) {
      await getPendingJoinRequests();
    }
  }

  Future<void> saveJobsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jobsJson = jsonEncode(jobs.map((job) => job.toJson()).toList());
    await prefs.setString('jobs', jobsJson);
  }

  Future<Job> createSharedJob(
    String name,
    Color color, {
    bool isPublic = true,
  }) async {
    if (databaseService == null) {
      throw Exception('User not authenticated');
    }

    // Generate a random 6-character code
    final random = Random();
    final codeChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String connectionCode = '';
    for (int i = 0; i < 6; i++) {
      connectionCode += codeChars[random.nextInt(codeChars.length)];
    }

    final job = Job(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      color: color,
      creatorId: currentUserId ?? '',
      connectionCode: connectionCode,
      isShared: true,
      isPublic: isPublic,
    );

    try {
      // Create the shared job in Firestore
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(connectionCode)
          .set({
            'id': job.id,
            'name': job.name,
            'color': job.color.value,
            'creatorId': job.creatorId,
            'connectionCode': connectionCode,
            'isPublic': isPublic,
            'connectedUsers': [job.creatorId],
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Add to local jobs list
      jobs.add(job);
      sharedJobs.add(job);

      // Save to user's jobs collection
      await databaseService!.saveJobs([job]);
      await saveJobsToLocalStorage();

      notifyListeners();
      return job;
    } catch (e) {
      print('Error creating shared job: $e');
      throw e;
    }
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

  Future<void> deleteSharedJob(Job job) async {
    if (job.connectionCode == null) {
      throw Exception('This is not a shared job');
    }

    if (job.creatorId != currentUserId) {
      throw Exception('Only the creator can delete this job');
    }

    try {
      // Delete the shared job from Firestore
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(job.connectionCode)
          .delete();

      // Remove from local jobs list
      jobs.removeWhere((j) => j.id == job.id);
      sharedJobs.removeWhere((j) => j.id == job.id);

      // Delete from user's jobs collection
      if (databaseService != null) {
        await databaseService!.deleteJob(job.id);
      }

      await saveJobsToLocalStorage();
      notifyListeners();
    } catch (e) {
      print('Error deleting shared job: $e');
      rethrow;
    }
  }
}
