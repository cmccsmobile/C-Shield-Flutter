import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final String message;
  final bool success;

  const ResultCard({super.key, required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.error_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
