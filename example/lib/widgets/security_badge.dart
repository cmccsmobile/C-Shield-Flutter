import 'package:flutter/material.dart';

class SecurityBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const SecurityBadge({super.key, required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          Text('· $sub', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const Spacer(),
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
        ],
      ),
    );
  }
}
