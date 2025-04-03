import 'package:flutter/material.dart';
import 'package:timagatt/utils/page_transitions.dart';
import 'package:timagatt/screens/jobs_screen.dart';
import 'package:timagatt/screens/job_overview_screen.dart';
import 'package:timagatt/screens/settings_screen.dart';
import 'package:timagatt/screens/history_screen.dart';
import 'package:timagatt/screens/add_time_screen.dart';
import 'package:timagatt/screens/home_screen.dart';
import 'package:timagatt/models/job.dart';

class Navigation {
  static void push(BuildContext context, Widget screen) {
    Navigator.push(context, FadePageRoute(child: screen));
  }

  static void pushNamed(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    final route = ModalRoute.of(context);
    if (route != null) {
      Navigator.push(
        context,
        FadePageRoute(child: _buildRoute(routeName, arguments)),
      );
    }
  }

  static void pushReplacement(BuildContext context, Widget screen) {
    Navigator.pushReplacement(context, FadePageRoute(child: screen));
  }

  static void pushAndRemoveUntil(BuildContext context, Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      FadePageRoute(child: screen),
      (route) => false,
    );
  }

  static void pop(BuildContext context) {
    Navigator.pop(context);
  }

  static void popUntil(
    BuildContext context,
    bool Function(Route<dynamic>) predicate,
  ) {
    Navigator.popUntil(context, predicate);
  }

  static void pushNamedAndRemoveUntil(
    BuildContext context,
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      predicate,
      arguments: arguments,
    );
  }

  static Widget _buildRoute(String routeName, Object? arguments) {
    switch (routeName) {
      case '/jobs':
        return const JobsScreen();
      case '/job-overview':
        return JobOverviewScreen(job: arguments as Job);
      case '/settings':
        return const SettingsScreen();
      case '/history':
        return const HistoryScreen();
      case '/add-time':
        return const AddTimeScreen();
      case '/home':
        return const HomeScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
