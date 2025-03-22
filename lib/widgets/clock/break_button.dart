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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isOnBreak ? Colors.amber.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnBreak ? Colors.amber : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnBreak ? Icons.pause_circle_filled : Icons.coffee,
              color: isOnBreak ? Colors.amber.shade800 : Colors.amber.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isOnBreak ? 'End Break' : 'Take Break',
              style: TextStyle(
                color:
                    isOnBreak ? Colors.amber.shade800 : Colors.amber.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
