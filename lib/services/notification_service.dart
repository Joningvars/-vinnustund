import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize FCM and request permissions
  Future<void> initialize() async {
    print('🔄 Initializing FCM...');

    // Request permission for iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('📱 User granted permission: ${settings.authorizationStatus}');

    // Get FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      print('🔑 FCM Token: $token');
      await _saveTokenToFirestore(token);
    } else {
      print('❌ Failed to get FCM token');
    }

    // Handle token refresh
    _messaging.onTokenRefresh.listen((token) async {
      print('🔄 FCM Token refreshed: $token');
      await _saveTokenToFirestore(token);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Got a message whilst in the foreground!');
      print('📦 Message data: ${message.data}');
      print('🔔 Notification: ${message.notification}');
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      print('💾 Saving FCM token for user: ${user.uid}');
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
        print('✅ FCM token saved successfully');
      } catch (e) {
        print('❌ Error saving FCM token: $e');
      }
    } else {
      print('❌ No authenticated user found');
    }
  }

  // Send a notification to a specific user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('🔄 Sending notification to user: $userId');

      // Get the user's FCM tokens
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final tokens = List<String>.from(userData?['fcmTokens'] ?? []);

      print('🔑 User FCM tokens: $tokens');

      if (tokens.isEmpty) {
        print('❌ No FCM tokens found for user: $userId');
        return;
      }

      // Store notification in Firestore
      final notificationRef = await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': {
          ...data,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'sound': 'default',
        },
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'fcmTokens': tokens,
      });

      print(
        '📝 Notification stored in Firestore with ID: ${notificationRef.id}',
      );
      print('✅ Notification process completed');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  // Test method to send a notification
  Future<void> sendTestNotification(String userId) async {
    try {
      print('🔄 Sending test notification to user: $userId');

      await sendNotification(
        userId: userId,
        title: 'Test Notification',
        body: 'This is a test notification to verify the system is working',
        data: {
          'type': 'test',
          'testId': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Error sending test notification: $e');
      throw e;
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
}
