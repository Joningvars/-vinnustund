import 'package:flutter/material.dart';
import 'package:timagatt/utils/image_paths.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 60, this.showText = true});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.1)
                    : Theme.of(
                      context,
                    ).colorScheme.onSecondary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [isDarkMode ? Image.asset(logoDark) : Image.asset(logo)],
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 8),
          Text(
            'Tímagátt',
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color:
                  isDarkMode
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
