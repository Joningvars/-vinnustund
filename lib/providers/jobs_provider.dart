import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/providers/base_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';

class JobsProvider extends BaseProvider {
  List<Job> jobs = [];
  List<Job> sharedJobs = [];
  Job? selectedJob;
  bool isPaidUser = true;
  SettingsProvider? _settingsProvider;
  TimeEntriesProvider? _timeEntriesProvider;
  DateTime? _lastSyncTime;
  SharedJobsProvider? _sharedJobsProvider;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void onUserAuthenticated() {
    loadJobs();
  }

  @override
  void onUserLoggedOut() {
    jobs = [];
    sharedJobs = [];
    selectedJob = null;
    notifyListeners();
  }

  Future<void> loadJobs() async {
    try {
      print('🔄 Loading jobs...');
      if (databaseService != null) {
        print('📱 Loading from database service...');
        final loadedJobs = await databaseService!.loadJobs();

        // Debug logging
        print('📊 Loaded ${loadedJobs.length} jobs from database');
        for (var job in loadedJobs) {
          print(
            '📝 Job: ${job.name}, ID: ${job.id}, isShared: ${job.isShared}, connectionCode: ${job.connectionCode}',
          );
        }

        // Only load non-shared jobs into the main list
        jobs = loadedJobs.where((job) => !job.isShared).toList();
        print('📊 Regular jobs: ${jobs.length}');

        // Set a default selected job if none is selected
        if (selectedJob == null && jobs.isNotEmpty) {
          selectedJob = jobs.first;
        }

        notifyListeners();
      }
    } catch (e) {
      print('❌ Error loading jobs: $e');
    }
  }

  void setSelectedJob(Job job) {
    selectedJob = job;
    notifyListeners();
  }

  Future<void> addJob(String name, Color color, String? description) async {
    try {
      final newJob = Job(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        color: color,
        description: description,
        isShared: false,
        isPublic: true,
        connectionCode: null,
        creatorId: currentUserId,
        connectedUsers: null,
      );

      // Add to local list - all jobs go in the main list for time entries
      jobs.add(newJob);

      // Set as selected job if no job is selected
      if (selectedJob == null) {
        selectedJob = newJob;
      }

      notifyListeners();

      // Save to database if authenticated
      if (databaseService != null &&
          FirebaseAuth.instance.currentUser != null) {
        try {
          await databaseService!.saveJob(newJob);
        } catch (e) {
          print('Error saving job to database: $e');
        }
      }

      // Always save to local storage as a backup
      try {
        await saveJobsToLocalStorage();
      } catch (e) {
        print('Error saving job to local storage: $e');
      }
    } catch (e) {
      print('Error adding job: $e');
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      // Find the job to delete
      final jobToDelete = jobs.firstWhere((job) => job.id == jobId);

      // Delete all time entries for this job first
      if (databaseService != null) {
        print('🗑️ Deleting all time entries for job: $jobId');
        await databaseService!.deleteAllTimeEntriesForJob(jobId);
      }

      // If it's a shared job, handle shared job deletion
      if (jobToDelete.isShared) {
        await _deleteSharedJob(jobToDelete);
      } else {
        // For regular jobs, just delete from the user's collection
        if (currentUserId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('jobs')
              .doc(jobId)
              .delete();
        }
      }

      // Remove from both lists
      jobs.removeWhere((job) => job.id == jobId);
      sharedJobs.removeWhere((job) => job.id == jobId);

      // Update selected job in both providers
      if (selectedJob?.id == jobId) {
        // Find a new job to select
        final newSelectedJob = jobs.isNotEmpty ? jobs.first : null;
        selectedJob = newSelectedJob;

        // Update TimeEntriesProvider if available
        if (_timeEntriesProvider != null) {
          _timeEntriesProvider!.clearSelectedJob();
        }
      }

      // Save to local storage
      await saveJobsToLocalStorage();

      // Notify listeners
      notifyListeners();
    } catch (e) {
      print('Error deleting job: $e');
      throw e; // Re-throw the error to handle it in the UI
    }
  }

  Future<void> _deleteSharedJob(Job job) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Check if current user is the creator
      if (job.creatorId == currentUserId) {
        // If creator, delete the shared job document and all its entries
        if (job.connectionCode != null) {
          // Delete all entries in the shared job's entries collection
          print(
            '🗑️ Deleting shared job entries for connection code: ${job.connectionCode}',
          );
          final entriesSnapshot =
              await FirebaseFirestore.instance
                  .collection('sharedJobs')
                  .doc(job.connectionCode)
                  .collection('entries')
                  .get();

          for (var doc in entriesSnapshot.docs) {
            await doc.reference.delete();
          }

          // Delete the shared job document itself
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(job.connectionCode)
              .delete();

          print('✅ Deleted shared job document: ${job.name}');
        }
      } else {
        // If not creator, just remove current user from connectedUsers
        if (job.connectionCode != null) {
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(job.connectionCode)
              .update({
                'connectedUsers': FieldValue.arrayRemove([currentUserId]),
              });

          print('✅ Removed user from shared job: ${job.name}');
        }
      }

      // Always delete from user's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('jobs')
          .doc(job.id)
          .delete();

      print('✅ Deleted job from user collection: ${job.name}');
    } catch (e) {
      print('❌ Error deleting shared job: $e');
      throw e;
    }
  }

  Future<void> saveJobsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    // Only save non-shared jobs to local storage
    final nonSharedJobs = jobs.where((job) => !job.isShared).toList();
    final jobsJson = jsonEncode(
      nonSharedJobs.map((job) => job.toJson()).toList(),
    );
    await prefs.setString('jobs', jobsJson);
  }

  // Shared jobs methods
  Future<Job?> joinJobByCode(String connectionCode) async {
    if (databaseService == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if the job is private
      final isPrivate = await checkIfJobIsPrivate(connectionCode);

      if (isPrivate) {
        // For private jobs, create a join request
        final jobId = DateTime.now().millisecondsSinceEpoch.toString();
        await databaseService!.requestJobAccess(jobId, connectionCode);
        return null; // Return null to indicate a request was sent
      } else {
        // For public jobs, join immediately
        final job = await _sharedJobsProvider?.joinJobByCode(connectionCode);

        // Add to local jobs list
        if (job != null) {
          jobs.add(job);
          sharedJobs.add(job);
        }

        await saveJobsToLocalStorage();
        notifyListeners();

        return job;
      }
    } catch (e) {
      print('Error joining job by code: $e');
      throw e;
    }
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
      await databaseService!.deleteSharedJob(job.id, job.connectionCode!);

      // Remove from local jobs list
      jobs.removeWhere((j) => j.id == job.id);
      sharedJobs.removeWhere((j) => j.id == job.id);

      // If this was the selected job, reset selection
      if (selectedJob?.id == job.id) {
        selectedJob = jobs.isNotEmpty ? jobs.first : null;
      }

      await saveJobsToLocalStorage();
      notifyListeners();
    } catch (e) {
      print('Error deleting shared job: $e');
      rethrow;
    }
  }

  Future<void> initializeApp() async {
    await loadJobs();
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

  void setTimeEntriesProvider(TimeEntriesProvider provider) {
    _timeEntriesProvider = provider;
  }

  Future<void> updateJob(
    String id, {
    required String name,
    String? description,
    required Color color,
  }) async {
    try {
      final index = jobs.indexWhere((job) => job.id == id);
      if (index != -1) {
        jobs[index] = jobs[index].copyWith(
          name: name,
          description: description,
          color: color,
        );

        // Save to database if available
        if (databaseService != null &&
            FirebaseAuth.instance.currentUser != null) {
          try {
            await databaseService!.updateJob(jobs[index]);
          } catch (e) {
            print('Error updating job in database: $e');
          }
        }

        // Always save to local storage as backup
        try {
          await saveJobsToLocalStorage();
        } catch (e) {
          print('Error saving job to local storage: $e');
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error updating job: $e');
    }
  }

  Future<void> joinSharedJob(String code) async {
    // Implementation will depend on your Firebase structure
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('sharedJobs')
              .doc(code)
              .get();

      if (doc.exists) {
        // Process the shared job data
        // This is a simplified implementation
        notifyListeners();
      }
    } catch (e) {
      print('Error joining shared job: $e');
    }
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

  Future<void> refreshJobs() async {
    print('🔄 Refreshing jobs from Firestore');
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        print('❌ No authenticated user found');
        return;
      }

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('jobs')
              .get();

      final loadedJobs =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return Job.fromFirestore(doc);
          }).toList();

      print('✅ Loaded ${loadedJobs.length} jobs from Firestore');

      // Filter out shared jobs from the regular jobs list
      jobs = loadedJobs.where((job) => !job.isShared).toList();
      print('📊 Regular jobs after filtering: ${jobs.length}');

      notifyListeners();

      // Save to local storage
      await saveJobsToLocalStorage();
    } catch (e) {
      print('❌ Error refreshing jobs: $e');
    }
  }

  Future<void> addSharedJob(Job job) async {
    try {
      print('🔄 Adding shared job to jobs list: ${job.name}');

      // Check if job already exists
      final existingIndex = jobs.indexWhere((j) => j.id == job.id);
      if (existingIndex >= 0) {
        print('ℹ️ Job already exists in list, updating');
        jobs[existingIndex] = job;
      } else {
        print('✅ Adding new job to list');
        jobs.add(job);
      }

      // Save to local storage
      await saveJobsToLocalStorage();

      // Notify listeners
      notifyListeners();

      print('✅ Job added to jobs list successfully');
    } catch (e) {
      print('❌ Error adding shared job to jobs list: $e');
    }
  }

  Future<void> fetchJobs(BuildContext context) async {
    if (currentUserId == null) return;

    try {
      // Fetch user's jobs from Firestore
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('jobs')
              .get();

      // Clear existing jobs and add the fetched ones
      jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();

      // Separate regular and shared jobs
      sharedJobs = jobs.where((job) => job.isShared).toList();

      // Only sync with shared jobs if it's been more than 30 seconds since last sync
      final now = DateTime.now();
      if (_lastSyncTime == null ||
          now.difference(_lastSyncTime!).inSeconds > 30) {
        final sharedJobsProvider = Provider.of<SharedJobsProvider>(
          context,
          listen: false,
        );
        await sharedJobsProvider.syncUserJobs();
        _lastSyncTime = now;
      }

      notifyListeners();
    } catch (e) {
      print('Error fetching jobs: $e');
    }
  }

  Future<Job?> getJobById(String jobId) async {
    print('🔍 Looking for job with ID: $jobId');

    // First check the in-memory jobs list
    try {
      final localJob = jobs.firstWhere((job) => job.id == jobId);
      print('✅ Found job in memory: ${localJob.name}');
      return localJob;
    } catch (e) {
      print('⚠️ Job not found in memory, trying database');
    }

    // If not found in memory, try to fetch from Firestore
    if (databaseService != null) {
      try {
        print('🔍 Querying Firestore for job: $jobId');

        // Get job from Firestore
        final snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .collection('jobs')
                .doc(jobId)
                .get();

        if (snapshot.exists) {
          final job = Job.fromFirestore(snapshot);
          print('✅ Found job in Firestore: ${job.name}');
          return job;
        } else {
          print('❌ Job not found in Firestore');
        }
      } catch (e) {
        print('❌ Error fetching job by ID: $e');
      }
    }

    print('❌ Job not found anywhere: $jobId');
    return null;
  }

  Future<void> refreshAllJobs() async {
    try {
      await loadJobs();
      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing jobs: $e');
    }
  }

  void setSharedJobsProvider(SharedJobsProvider provider) {
    _sharedJobsProvider = provider;
    // Listen for changes in shared jobs
    _sharedJobsProvider?.addListener(_onSharedJobsChanged);
  }

  void _onSharedJobsChanged() {
    // When shared jobs change, refresh all jobs
    loadJobs();
  }

  Future<Job?> createSharedJob(Job job) async {
    try {
      // Use the correct method signature based on your database service
      final createdJob = await databaseService?.createSharedJob(
        name: job.name,
        color: job.color,
        isPublic: job.isPublic,
      );

      return createdJob;
    } catch (e) {
      print('Error creating shared job: $e');
      return null;
    }
  }

  Future<void> clearAllJobs() async {
    try {
      // Clear from memory
      jobs = [];
      sharedJobs = [];
      selectedJob = null;

      // Clear from local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jobs');

      // Clear from Firebase if authenticated
      if (databaseService != null &&
          FirebaseAuth.instance.currentUser != null) {
        final user = FirebaseAuth.instance.currentUser!;
        final jobsSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('jobs')
                .get();

        // Delete each job document
        for (var doc in jobsSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error clearing jobs: $e');
    }
  }

  User? get currentUser => _auth.currentUser;
}
