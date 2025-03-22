import 'package:flutter/material.dart';

class BreakButton extends StatelessWidget {
  final bool isOnBreak;
  final VoidCallback onPressed;

  const BreakButton({
    super.key,
    required this.isOnBreak,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isOnBreak ? Colors.amber : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isOnBreak ? Colors.amber.shade800 : Colors.amber,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isOnBreak ? Icons.play_arrow : Icons.pause,
          color: isOnBreak ? Colors.white : Colors.amber,
          size: 32,
        ),
      ),
    );
  }
}
