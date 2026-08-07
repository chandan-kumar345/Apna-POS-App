import 'package:flutter/material.dart';

/// Reusable FoodType icon badge (Veg, Non-Veg, Egg, Beverage)
class FoodTypeIcon extends StatelessWidget {
  final String itemType;
  final double size;

  const FoodTypeIcon({
    super.key,
    required this.itemType,
    this.size = 13.0,
  });

  @override
  Widget build(BuildContext context) {
    if (itemType == 'Non-Veg') {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFEF4444),
            shape: BoxShape.circle,
          ),
        ),
      );
    } else if (itemType == 'Egg') {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB45309), width: 1.2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFB45309),
            shape: BoxShape.circle,
          ),
        ),
      );
    } else if (itemType == 'Beverage') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF00A3FF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF00A3FF), width: 0.8),
        ),
        child: Icon(Icons.local_drink_rounded, color: const Color(0xFF00A3FF), size: (size - 3).clamp(8.0, 16.0)),
      );
    } else {
      // Default Veg
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF10B981), width: 1.2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
        ),
      );
    }
  }
}
