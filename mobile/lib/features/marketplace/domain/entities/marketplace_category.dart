import 'package:flutter/material.dart';

/// Centralized category definition for Aaspaas Marketplace.
enum MarketplaceCategory {
  electronics('electronics', 'Electronics', Icons.devices_rounded),
  mobiles('mobiles', 'Mobiles', Icons.phone_android_rounded),
  computers('computers', 'Computers', Icons.laptop_mac_rounded),
  furniture('furniture', 'Furniture', Icons.chair_rounded),
  homeKitchen('home_kitchen', 'Home & Kitchen', Icons.kitchen_rounded),
  vehicles('vehicles', 'Vehicles', Icons.directions_car_rounded),
  books('books', 'Books & Hobbies', Icons.menu_book_rounded),
  fashion('fashion', 'Fashion', Icons.checkroom_rounded),
  kids('kids', 'Kids & Toys', Icons.toys_rounded),
  sports('sports', 'Sports & Fitness', Icons.fitness_center_rounded),
  other('other', 'Other', Icons.category_rounded);

  const MarketplaceCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static MarketplaceCategory fromString(String? val) {
    if (val == null) return MarketplaceCategory.other;
    return MarketplaceCategory.values.firstWhere(
      (c) => c.value.toLowerCase() == val.toLowerCase(),
      orElse: () => MarketplaceCategory.other,
    );
  }
}
