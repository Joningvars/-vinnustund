import 'package:flutter/material.dart';
import 'package:timagatt/utils/image_paths.dart';
import 'package:timagatt/widgets/app_logo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timagatt/main.dart';

import '../utils/routes.dart'; // Import for Routes

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Check authentication status after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      _checkAuthAndNavigate();
    });
  }

  void _checkAuthAndNavigate() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, navigate to main screen
      Navigator.of(context).pushReplacementNamed(Routes.main);
    } else {
      // User is not logged in, navigate to login screen
      Navigator.of(context).pushReplacementNamed(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDarkMode
                    ? [Colors.grey.shade900, Colors.black]
                    : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use the AppLogo widget which already handles the logo
              const AppLogo(size: 120),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
