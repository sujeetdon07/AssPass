import 'package:flutter/material.dart';

/// Categories supported by Aaspaas Events.
enum EventCategory {
  social('social', 'Social & Meetups', Icons.people_outline),
  cultural('cultural', 'Cultural & Arts', Icons.palette_outlined),
  sports('sports', 'Sports & Fitness', Icons.directions_run_outlined),
  workshop('workshop', 'Workshops & Learning', Icons.school_outlined),
  volunteering('volunteering', 'Volunteering & Civic', Icons.volunteer_activism_outlined),
  neighborhood('neighborhood', 'Neighborhood & HOA', Icons.home_work_outlined),
  other('other', 'Other', Icons.event_outlined);

  const EventCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static EventCategory fromString(String? value) {
    if (value == null) return EventCategory.other;
    return EventCategory.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => EventCategory.other,
    );
  }
}
