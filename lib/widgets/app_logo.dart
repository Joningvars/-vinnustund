import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 60, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Clock face
              Container(
                width: size * 0.8,
                height: size * 0.8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),

              // Hour hand
              Positioned(
                left: size * 0.5,
                top: size * 0.5,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.rotationZ(3.14 / 2), // 12 o'clock
                  child: Container(
                    height: size * 0.25,
                    width: 3,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),

              // Minute hand
              Positioned(
                left: size * 0.5,
                top: size * 0.5,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.rotationZ(3.14), // 9 o'clock
                  child: Container(
                    height: size * 0.3,
                    width: 2,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),

              // Center dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 8),
          Text(
            'Tímagátt',
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
