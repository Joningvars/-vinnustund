import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timagatt/services/database_service.dart';

class BaseProvider extends ChangeNotifier {
  DatabaseService? _databaseService;
  String? currentUserId;

  BaseProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        currentUserId = user.uid;
        _databaseService = DatabaseService(uid: user.uid);
        onUserAuthenticated();
      } else {
        _databaseService = null;
        currentUserId = null;
        onUserLoggedOut();
      }
    });
  }

  // Override these in subclasses
  void onUserAuthenticated() {}
  void onUserLoggedOut() {}

  DatabaseService? get databaseService => _databaseService;
}
