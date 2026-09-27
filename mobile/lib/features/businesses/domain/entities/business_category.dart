import 'package:flutter/material.dart';

enum BusinessCategory {
  foodDining('food_dining', 'Food & Dining', Icons.restaurant_rounded),
  grocery('grocery', 'Grocery & Essentials', Icons.local_grocery_store_rounded),
  shopping('shopping', 'Shopping & Retail', Icons.shopping_bag_rounded),
  health('health', 'Health & Wellness', Icons.local_hospital_rounded),
  beauty('beauty', 'Beauty & Salon', Icons.spa_rounded),
  fitness('fitness', 'Fitness & Sports', Icons.fitness_center_rounded),
  education('education', 'Education & Coaching', Icons.school_rounded),
  electronics('electronics', 'Electronics & Gadgets', Icons.devices_rounded),
  homeRepair(
    'home_repair',
    'Home & Hardware',
    Icons.home_repair_service_rounded,
  ),
  automotive('automotive', 'Automotive', Icons.directions_car_rounded),
  professional(
    'professional',
    'Professional Services',
    Icons.business_center_rounded,
  ),
  other('other', 'Other Business', Icons.store_rounded);

  const BusinessCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static BusinessCategory fromString(String? value) {
    if (value == null) return BusinessCategory.other;
    return BusinessCategory.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase().trim(),
      orElse: () => BusinessCategory.other,
    );
  }
}
