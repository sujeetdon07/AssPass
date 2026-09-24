import 'package:flutter/material.dart';

enum ServiceCategory {
  electrician('electrician', 'Electrician', Icons.electrical_services_rounded),
  plumber('plumber', 'Plumber', Icons.plumbing_rounded),
  carpenter('carpenter', 'Carpenter', Icons.carpenter_rounded),
  painter('painter', 'Painter', Icons.format_paint_rounded),
  cleaner(
      'cleaner', 'Cleaning & Housekeeping', Icons.cleaning_services_rounded,),
  tutor('tutor', 'Home Tutor / Teacher', Icons.menu_book_rounded),
  mechanic('mechanic', 'Auto Mechanic', Icons.build_rounded),
  tailor('tailor', 'Tailor & Alterations', Icons.content_cut_rounded),
  gardener('gardener', 'Gardening & Lawn', Icons.yard_rounded),
  pestControl('pest_control', 'Pest Control', Icons.pest_control_rounded),
  applianceRepair('appliance_repair', 'Appliance Repair',
      Icons.home_repair_service_rounded,),
  beauty('beauty', 'Salon & Beauty', Icons.spa_rounded),
  photography('photography', 'Photography & Video', Icons.camera_alt_rounded),
  moving('moving', 'Packers & Movers', Icons.local_shipping_rounded),
  handyman('handyman', 'Handyman', Icons.handyman_rounded),
  other('other', 'Other Services', Icons.miscellaneous_services_rounded);

  const ServiceCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static ServiceCategory fromString(String value) {
    return ServiceCategory.values.firstWhere(
      (c) => c.value == value.toLowerCase().trim(),
      orElse: () => ServiceCategory.other,
    );
  }
}

enum PricingModel {
  fixed('fixed', 'Fixed Price'),
  hourly('hourly', 'Hourly Rate'),
  startingAt('starting_at', 'Starting At'),
  contactForQuote('contact_for_quote', 'Contact for Quote');

  const PricingModel(this.value, this.label);

  final String value;
  final String label;

  static PricingModel fromString(String value) {
    return PricingModel.values.firstWhere(
      (m) => m.value == value.toLowerCase().trim(),
      orElse: () => PricingModel.contactForQuote,
    );
  }
}

enum ServiceStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive'),
  suspended('suspended', 'Suspended');

  const ServiceStatus(this.value, this.label);

  final String value;
  final String label;

  static ServiceStatus fromString(String value) {
    return ServiceStatus.values.firstWhere(
      (s) => s.value == value.toLowerCase().trim(),
      orElse: () => ServiceStatus.active,
    );
  }
}
