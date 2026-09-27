import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/notification_repository_impl.dart';
import '../domain/models/notification_preferences.dart';
import '../domain/repositories/notification_repository.dart';

final notificationPreferencesControllerProvider = StateNotifierProvider<
    NotificationPreferencesController,
    AsyncValue<NotificationPreferences>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationPreferencesController(repository);
});

class NotificationPreferencesController
    extends StateNotifier<AsyncValue<NotificationPreferences>> {
  NotificationPreferencesController(this._repository)
      : super(const AsyncValue.loading()) {
    loadPreferences();
  }

  final NotificationRepository _repository;

  Future<void> loadPreferences() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await _repository.getPreferences();
      state = AsyncValue.data(prefs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateCategory(String categoryKey, bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Optimistically update
    NotificationPreferences updated;
    switch (categoryKey) {
      case 'messages':
        updated = current.copyWith(messagesEnabled: enabled);
        break;
      case 'social':
        updated = current.copyWith(socialEnabled: enabled);
        break;
      case 'community':
        updated = current.copyWith(communityEnabled: enabled);
        break;
      case 'marketplace':
        updated = current.copyWith(marketplaceEnabled: enabled);
        break;
      case 'business':
        updated = current.copyWith(businessEnabled: enabled);
        break;
      case 'system':
        updated = current.copyWith(systemEnabled: enabled);
        break;
      default:
        return;
    }

    state = AsyncValue.data(updated);

    try {
      final key = '${categoryKey}Enabled';
      final saved = await _repository.updatePreferences({key: enabled});
      state = AsyncValue.data(saved);
    } catch (e, st) {
      // Revert on failure
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> togglePush(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(pushEnabled: enabled);
    state = AsyncValue.data(updated);

    try {
      final saved =
          await _repository.updatePreferences({'pushEnabled': enabled});
      state = AsyncValue.data(saved);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }
}
