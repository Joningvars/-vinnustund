import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:timagatt/screens/add_time_screen.dart';
import 'package:timagatt/screens/export_screen.dart';
import 'package:timagatt/screens/history_screen.dart';
import 'package:timagatt/screens/settings_screen.dart';
import 'package:timagatt/screens/time_clock_screen.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<CustomNavBarItem> items;
  final Color activeColor;
  final Color inactiveColor;
  final Color indicatorColor;
  final double indicatorHeight;

  const CustomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.indicatorColor = Colors.blue,
    this.indicatorHeight = 2.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Use primary color for light mode, onPrimary for dark mode
    final activeItemColor =
        isDarkMode
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).primaryColor;

    // Use the same color for the indicator
    final indicatorActiveColor = activeItemColor;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Sliding indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left:
                    (MediaQuery.of(context).size.width / items.length) *
                    currentIndex,
                top: 0,
                width: MediaQuery.of(context).size.width / items.length,
                child: Container(
                  alignment: Alignment.center,
                  child: Container(
                    width:
                        (MediaQuery.of(context).size.width / items.length) - 20,
                    height: indicatorHeight,
                    decoration: BoxDecoration(
                      color: indicatorActiveColor, // Use the appropriate color
                      borderRadius: BorderRadius.circular(indicatorHeight / 2),
                    ),
                  ),
                ),
              ),
              // Navigation items
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(items.length, (index) {
                    final isSelected = currentIndex == index;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onTap(index);
                        },
                        child: SizedBox(
                          width:
                              MediaQuery.of(context).size.width / items.length,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                items[index].icon,
                                color:
                                    isSelected
                                        ? activeItemColor
                                        : inactiveColor, // Use the appropriate color
                                size: 26,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                items[index].title,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      isSelected
                                          ? activeItemColor
                                          : inactiveColor, // Use the appropriate color
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomNavBarItem {
  final String title;
  final IconData icon;

  CustomNavBarItem({required this.title, required this.icon});
}
