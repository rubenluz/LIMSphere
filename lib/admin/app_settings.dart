// app_settings.dart - AppSettings: global settings model (visible module groups,
// feature flags) persisted via SharedPreferences.

import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

/// Global app settings stored in Supabase `app_meta.meta_settings`.
/// Changes are immediately visible to all users.
class AppSettings {
  static const _defaultVisible = {
    'dashboard', 'labels', 'chat', 'requests', 'culture_collection', 'fish_facility', 'resources',
    'reservations',
  };

  static Set<String> _visibleGroups = Set.from(_defaultVisible);

  /// Load settings from Supabase. Call once when the menu initialises.
  static Future<void> load() async {
    try {
      final row = await Supabase.instance.client
          .from('app_meta')
          .select('meta_settings')
          .limit(1)
          .maybeSingle();

      final settings = (row?['meta_settings'] as Map<String, dynamic>?) ?? {};
      final rawGroups = settings['visible_groups'];
      if (rawGroups is List) {
        _visibleGroups = Set<String>.from(rawGroups.whereType<String>());
      } else {
        _visibleGroups = Set.from(_defaultVisible);
      }
    } catch (_) {
      _visibleGroups = Set.from(_defaultVisible);
    }
  }

  static Set<String> get visibleGroups => Set.from(_visibleGroups);

  /// Persist updated visible-groups to Supabase and update the in-memory cache.
  static Future<void> setVisibleGroups(Set<String> groups) async {
    _visibleGroups = Set.from(groups);
    await Supabase.instance.client
        .from('app_meta')
        .update({'meta_settings': {'visible_groups': groups.toList()}})
        .eq('meta_initialized', true);
  }
}
