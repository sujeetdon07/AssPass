import 'package:flutter/material.dart';

/// Supported community categories in Aaspaas.
enum CommunityCategory {
  neighborhood('neighborhood', 'Neighborhood', Icons.location_city_rounded),
  society('society', 'Society / Apartment', Icons.apartment_rounded),
  parentsFamily(
    'parents_family',
    'Parents & Family',
    Icons.family_restroom_rounded,
  ),
  students('students', 'Students', Icons.school_rounded),
  localInterests('local_interests', 'Local Interests', Icons.interests_rounded),
  sports('sports', 'Sports & Fitness', Icons.sports_soccer_rounded),
  hobbies('hobbies', 'Hobbies', Icons.palette_rounded),
  residents('residents', 'Residents Club', Icons.groups_rounded),
  localHelp('local_help', 'Local Help', Icons.volunteer_activism_rounded),
  other('other', 'Other', Icons.category_rounded);

  const CommunityCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static CommunityCategory fromString(String? val) {
    if (val == null) return CommunityCategory.neighborhood;
    final normalized = val.toLowerCase().replaceAll('-', '_');
    return CommunityCategory.values.firstWhere(
      (e) => e.value == normalized,
      orElse: () => CommunityCategory.other,
    );
  }
}
