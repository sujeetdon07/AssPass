import 'package:flutter/material.dart';

/// RSVP status states for Aaspaas events.
enum EventRsvpStatus {
  going('going', 'Going', Icons.check_circle_outline, Color(0xFF1B5E20)),
  interested('interested', 'Interested', Icons.star_border, Color(0xFFE65100)),
  notGoing('not_going', 'Not Going', Icons.cancel_outlined, Color(0xFF757575));

  const EventRsvpStatus(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  static EventRsvpStatus? fromString(String? value) {
    if (value == null) return null;
    return EventRsvpStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => EventRsvpStatus.going,
    );
  }
}
