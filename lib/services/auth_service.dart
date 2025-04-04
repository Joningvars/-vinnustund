import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/models/time_entry.dart';

class AuthService {
  // Use a singleton pattern to ensure only one instance exists
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream - cache the stream to prevent multiple subscriptions
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
    BuildContext context,
  ) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Initialize user data
      final provider = Provider.of<TimeEntriesProvider>(context, listen: false);
      await provider.initializeNewUser();

      // Clear any existing jobs
      final jobsProvider = Provider.of<JobsProvider>(context, listen: false);
      jobsProvider.clearAllJobs(); // Clear any existing jobs

      // Create first job
      await jobsProvider.addJob(
        'Verkefni A',
        Colors.orange,
        'Skráðu tíma sem þú vinnur að persónulegum verkefnum',
      );

      // Create second job
      await jobsProvider.addJob(
        'Verkefni B',
        Colors.green,
        'Haltu inni til að eyða verki!',
      );

      // Get the first job (Verkefni A) to create a time entry for it
      final jobA = jobsProvider.jobs.firstWhere(
        (job) => job.name == 'Verkefni A',
      );

      // Create a dummy time entry for job A
      final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
        context,
        listen: false,
      );
      final now = DateTime.now();
      final sixHoursAgo = now.subtract(const Duration(hours: 6));

      final dummyEntry = TimeEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        jobId: jobA.id,
        jobName: jobA.name,
        jobColor: jobA.color,
        clockInTime: sixHoursAgo,
        clockOutTime: now,
        duration: const Duration(hours: 6),
        description: 'Haltu inni til að eyða tímaskráningu!',
        userId: userCredential.user!.uid,
        date: sixHoursAgo,
      );

      await timeEntriesProvider.addTimeEntry(dummyEntry);

      // Get Verkefni B to create a time entry for it
      final jobB = jobsProvider.jobs.firstWhere(
        (job) => job.name == 'Verkefni B',
      );

      // Create a 2-hour time entry for job B
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      final dummyEntryB = TimeEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        jobId: jobB.id,
        jobName: jobB.name,
        jobColor: jobB.color,
        clockInTime: twoHoursAgo,
        clockOutTime: now,
        duration: const Duration(hours: 2),
        description: '',
        userId: userCredential.user!.uid,
        date: twoHoursAgo,
      );

      await timeEntriesProvider.addTimeEntry(dummyEntryB);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('User signed out');
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
