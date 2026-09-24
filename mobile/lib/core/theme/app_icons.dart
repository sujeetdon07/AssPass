import 'package:flutter/material.dart';

/// Centralized icon registry and icon-size tokens for Aaspaas.
///
/// Wraps Material Icons in a semantic layer so future changes to the icon
/// library do not require touching individual widgets.
class AppIcons {
  AppIcons._();

  // ── Icon Size Tokens ───────────────────────────────────────────────────────

  static const double sizeXs = 16.0;
  static const double sizeSm = 20.0;
  static const double sizeMd = 24.0;
  static const double sizeLg = 32.0;
  static const double sizeXl = 40.0;

  // ── Navigation Destinations ────────────────────────────────────────────────

  static const IconData home = Icons.home_rounded;
  static const IconData homeOutline = Icons.home_outlined;

  static const IconData nearby = Icons.near_me_rounded;
  static const IconData nearbyOutline = Icons.near_me_outlined;

  static const IconData communities = Icons.groups_rounded;
  static const IconData communitiesOutline = Icons.groups_outlined;

  static const IconData marketplace = Icons.storefront_rounded;
  static const IconData marketplaceOutline = Icons.storefront_outlined;

  static const IconData profile = Icons.person_rounded;
  static const IconData profileOutline = Icons.person_outline_rounded;

  // ── Businesses & Services Icons ───────────────────────────────────────────

  static const IconData business = Icons.business_center_rounded;
  static const IconData businessOutline = Icons.business_center_outlined;
  static const IconData service = Icons.home_repair_service_rounded;
  static const IconData serviceOutline = Icons.home_repair_service_outlined;
  static const IconData phoneCall = Icons.phone_forwarded_rounded;
  static const IconData website = Icons.language_rounded;
  static const IconData schedule = Icons.schedule_rounded;
  static const IconData verifiedShield = Icons.verified_user_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData chat = Icons.chat_rounded;

  // ── Header & Action Icons ──────────────────────────────────────────────────

  static const IconData notifications = Icons.notifications_rounded;
  static const IconData notificationsOutline = Icons.notifications_none_rounded;

  static const IconData search = Icons.search_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData more = Icons.more_vert_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.arrow_forward_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData clear = Icons.clear_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;

  // ── Context & Metadata Icons ───────────────────────────────────────────────

  static const IconData location = Icons.location_on_rounded;
  static const IconData locationOutline = Icons.location_on_outlined;
  static const IconData filter = Icons.tune_rounded;
  static const IconData sort = Icons.sort_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData refresh = Icons.refresh_rounded;

  // ── Feed & Interaction Icons ───────────────────────────────────────────────

  static const IconData like = Icons.favorite_rounded;
  static const IconData likeOutline = Icons.favorite_border_rounded;
  static const IconData comment = Icons.chat_bubble_outline_rounded;
  static const IconData send = Icons.send_rounded;

  // ── Status & Feedback Icons ────────────────────────────────────────────────

  static const IconData info = Icons.info_outline_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData report = Icons.flag_outlined;
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;

  static const IconData lightMode = Icons.light_mode_rounded;
  static const IconData darkMode = Icons.dark_mode_rounded;
  static const IconData systemMode = Icons.brightness_auto_rounded;

  // ── Auth & Account Icons ───────────────────────────────────────────────────

  static const IconData logout = Icons.logout_rounded;
  static const IconData phone = Icons.phone_rounded;
  static const IconData privacy = Icons.shield_outlined;
  static const IconData verified = Icons.verified_rounded;
  static const IconData arrowBack = Icons.arrow_back_rounded;
  static const IconData arrowDropDown = Icons.arrow_drop_down_rounded;
}
