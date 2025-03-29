import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/utils/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completeOnboarding() async {
    // Mark onboarding as complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', false);

    // Navigate to login screen
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeEntriesProvider>(context);

    // Define pages with translations
    final List<OnboardingPage> pages = [
      OnboardingPage(
        title:
            provider.translate('trackYourWorkHours') == 'trackYourWorkHours'
                ? 'Track Your Work Hours'
                : provider.translate('trackYourWorkHours'),
        description:
            provider.translate('trackYourWorkHoursDesc') ==
                    'trackYourWorkHoursDesc'
                ? 'Easily clock in and out to track your work hours accurately'
                : provider.translate('trackYourWorkHoursDesc'),
        image: Icons.access_time,
        color: Colors.blue,
      ),
      OnboardingPage(
        title:
            provider.translate('multipleJobs') == 'multipleJobs'
                ? 'Multiple Jobs'
                : provider.translate('multipleJobs'),
        description:
            provider.translate('multipleJobsDesc') == 'multipleJobsDesc'
                ? 'Manage multiple jobs efficiently'
                : provider.translate('multipleJobsDesc'),
        image: Icons.work,
        color: Colors.green,
      ),
      OnboardingPage(
        title:
            provider.translate('detailedReports') == 'detailedReports'
                ? 'Detailed Reports'
                : provider.translate('detailedReports'),
        description:
            provider.translate('detailedReportsDesc') == 'detailedReportsDesc'
                ? 'Generate detailed reports to analyze your work'
                : provider.translate('detailedReportsDesc'),
        image: Icons.bar_chart,
        color: Colors.orange,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  pages[_currentPage].color.withOpacity(0.3),
                  pages[_currentPage].color.withOpacity(0.1),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildPage(pages[index]);
                    },
                  ),
                ),

                // Page indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        height: 10,
                        width: _currentPage == index ? 30 : 10,
                        decoration: BoxDecoration(
                          color:
                              _currentPage == index
                                  ? pages[_currentPage].color
                                  : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),

                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 30,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip button
                      if (_currentPage < pages.length - 1)
                        TextButton(
                          onPressed: () {
                            _completeOnboarding();
                          },
                          child: Text(provider.translate('skip')),
                        )
                      else
                        const SizedBox(width: 80),

                      // Next/Get Started button
                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage < pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _completeOnboarding();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pages[_currentPage].color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          _currentPage < pages.length - 1
                              ? provider.translate('next')
                              : provider.translate('getStarted'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: page.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(page.image, size: 100, color: page.color),
                ),
              );
            },
          ),
          const SizedBox(height: 60),

          // Title
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    page.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Description
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    page.description,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData image;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
  });
}
