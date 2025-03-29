import 'package:flutter/material.dart';
import 'package:timagatt/services/auth_service.dart';
import 'package:timagatt/screens/auth/register_screen.dart';
import 'package:flutter/services.dart';
import 'package:timagatt/widgets/app_logo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';

import '../../utils/routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _email = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Map Firebase error codes to user-friendly messages
  String _getErrorMessage(FirebaseAuthException e) {
    final provider = Provider.of<SettingsProvider>(context, listen: false);

    switch (e.code) {
      case 'invalid-email':
        return provider.translate('invalidEmail');
      case 'user-disabled':
        return provider.translate('userDisabled');
      case 'user-not-found':
        return provider.translate('userNotFound');
      case 'wrong-password':
        return provider.translate('wrongPassword');
      case 'invalid-credential':
        return provider.translate('invalidCredentials');
      case 'too-many-requests':
        return provider.translate('tooManyRequests');
      case 'network-request-failed':
        return provider.translate('networkError');
      default:
        return '${provider.translate('loginError')}: ${e.message!}';
    }
  }

  Future<void> _signIn() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final jobsProvider = Provider.of<JobsProvider>(context, listen: false);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );

      // Navigate to main screen
      if (mounted) {
        // Load data from providers
        await jobsProvider.loadJobs();
        await timeEntriesProvider.loadTimeEntries();
        Navigator.of(context).pushReplacementNamed(Routes.main);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });

      // Show error in snackbar with haptic feedback
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = settingsProvider.translate('unknownError');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SettingsProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 100),

                      // Logo with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: const AppLogo(size: 80),
                          );
                        },
                      ),
                      const SizedBox(height: 48),

                      // Welcome text
                      Text(
                        provider.translate('welcomeBack'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.translate('loginToContinue'),
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Email field with animation
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.2,
                              0.6,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.2,
                              0.6,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: provider.translate('email'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return provider.translate('emailRequired');
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return provider.translate('invalidEmail');
                              }
                              return null;
                            },
                            onChanged: (value) => _email = value.trim(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password field with animation
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.3,
                              0.7,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.3,
                              0.7,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: provider.translate('password'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return provider.translate('passwordRequired');
                              }
                              return null;
                            },
                            onChanged: (value) => _password = value,
                          ),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Login button with animation
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.4,
                              0.8,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.4,
                              0.8,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? const CircularProgressIndicator()
                                      : Text(
                                        provider.translate('login'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Register button with animation
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.5,
                              0.9,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.5,
                              0.9,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: Text(
                              provider.translate('register'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Forgot password button with animation
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.6,
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.6,
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () {
                              _showResetPasswordDialog(provider);
                            },
                            child: Text(
                              provider.translate('forgotPassword'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showResetPasswordDialog(SettingsProvider provider) {
    String resetEmail = '';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset,
                        color: Theme.of(context).colorScheme.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.translate('resetPassword'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.translate('resetPasswordDescription'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: provider.translate('email'),
                        hintText: provider.translate('enterEmail'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return provider.translate('enterEmail');
                        }
                        if (!value.contains('@')) {
                          return provider.translate('invalidEmail');
                        }
                        return null;
                      },
                      onChanged: (value) {
                        resetEmail = value.trim();
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            provider.translate('cancel'),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                await _authService.resetPassword(resetEmail);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      provider.translate(
                                        'passwordResetEmailSent',
                                      ),
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              } catch (e) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${provider.translate('error')}: ${e.toString()}',
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(provider.translate('sendResetEmail')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
