import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/providers/base_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';

class JobsProvider extends BaseProvider {
  List<Job> jobs = [];
  List<Job> sharedJobs = [];
  Job? selectedJob;
  bool isPaidUser = true;
  SettingsProvider? _settingsProvider;
  TimeEntriesProvider? _timeEntriesProvider;

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
      if (databaseService != null) {
        final loadedJobs = await databaseService!.loadJobs();

        // Debug logging
        for (var job in loadedJobs) {
          print(
            'Loaded job: ${job.name}, color: ${job.color}, isShared: ${job.isShared}',
          );
        }

        jobs = loadedJobs;

        // Separate shared jobs
        sharedJobs = jobs.where((job) => job.isShared).toList();

        // Set a default selected job if none is selected
        if (selectedJob == null && jobs.isNotEmpty) {
          selectedJob = jobs.first;
        }

        notifyListeners();
      } else {
        // Load from local storage
        final prefs = await SharedPreferences.getInstance();
        final jobsJson = prefs.getString('jobs');

        if (jobsJson != null) {
          final List<dynamic> decoded = jsonDecode(jobsJson);
          jobs = decoded.map((item) => Job.fromJson(item)).toList();

          // Separate shared jobs
          sharedJobs = jobs.where((job) => job.isShared).toList();

          // Set a default selected job if none is selected
          if (selectedJob == null && jobs.isNotEmpty) {
            selectedJob = jobs.first;
          }

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading jobs: $e');
    }
  }

  void setSelectedJob(Job job) {
    selectedJob = job;
    notifyListeners();
  }

  Future<void> addJob(String name, Color color, [String? description]) async {
    final job = Job(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      color: color,
    );

    jobs.add(job);

    // Save to database if available
    if (databaseService != null) {
      await databaseService!.saveJob(job);
    }

    await saveJobsToLocalStorage();
    notifyListeners();
  }

  Future<void> deleteJob(String jobId) async {
    // Check if any time entries use this job
    final timeEntriesProvider = _timeEntriesProvider;
    if (timeEntriesProvider != null) {
      // Check if we're currently clocked in with this job
      if (timeEntriesProvider.isClockedIn &&
          timeEntriesProvider.selectedJob?.id == jobId) {
        throw Exception(translate('cannotDeleteActiveJob'));
      }

      // Delete all time entries for this job
      final entriesToDelete =
          timeEntriesProvider.timeEntries
              .where((entry) => entry.jobId == jobId)
              .toList();

      for (var entry in entriesToDelete) {
        await timeEntriesProvider.deleteTimeEntry(entry.id);
      }
    }

    // Remove the job from the list
    jobs.removeWhere((job) => job.id == jobId);

    // If this was the selected job, clear it
    if (selectedJob?.id == jobId) {
      selectedJob = jobs.isNotEmpty ? jobs.first : null;
    }

    // Save to database if authenticated
    if (databaseService != null) {
      await databaseService!.deleteJob(jobId);
    }

    // Save to local storage
    await saveJobsToLocalStorage();

    notifyListeners();
  }

  Future<void> saveJobsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jobsJson = jsonEncode(jobs.map((job) => job.toJson()).toList());
    await prefs.setString('jobs', jobsJson);
  }

  // Shared jobs methods
  Future<Job> createSharedJob(String name, Color color, bool isPublic) async {
    final connectionCode = _generateConnectionCode();

    final job = Job(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      color: color,
      creatorId: currentUserId,
      connectionCode: connectionCode,
      isShared: true,
      connectedUsers: [currentUserId!],
      isPublic: isPublic,
    );

    jobs.add(job);
    sharedJobs.add(job);

    if (databaseService != null) {
      await databaseService!.saveJob(job);
      // Also save to shared jobs collection
      await FirebaseFirestore.instance
          .collection('sharedJobs')
          .doc(connectionCode)
          .set({
            'jobId': job.id,
            'name': job.name,
            'color': job.color.value,
            'creatorId': currentUserId,
            'isPublic': isPublic,
            'connectedUsers': [currentUserId],
          });
    }

    await saveJobsToLocalStorage();
    notifyListeners();
    return job;
  }

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
        final job = await databaseService!.joinJobByCode(connectionCode);

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
    final index = jobs.indexWhere((job) => job.id == id);
    if (index != -1) {
      jobs[index] = jobs[index].copyWith(
        name: name,
        description: description,
        color: color,
      );

      // Save to database if available
      if (databaseService != null) {
        await databaseService!.updateJob(jobs[index]);
      }

      await saveJobsToLocalStorage();
      notifyListeners();
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
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}
