// data_cache.dart - DataCache: in-memory singleton that holds the most-recently
// loaded lists of samples, strains, locations, machines, and reagents to avoid
// redundant Supabase fetches within the same session.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../supabase/supabase_manager.dart';

/// File-based JSON cache for stale-while-revalidate offline support.
/// Data is namespaced per Supabase project so switching connections
/// never serves data from the wrong backend.
class DataCache {
  static Future<String> _filePath(String key) async {
    final base = await getApplicationSupportDirectory();
    final ref = SupabaseManager.projectRef ?? 'default';
    final dir = Directory('${base.path}/data_cache/$ref');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return '${dir.path}/$key.json';
  }

  /// Returns cached data, or null if nothing is cached yet.
  static Future<List<dynamic>?> read(String key) async {
    try {
      final file = File(await _filePath(key));
      if (!file.existsSync()) return null;
      return jsonDecode(file.readAsStringSync()) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Persists fresh data to disk.
  static Future<void> write(String key, List<dynamic> data) async {
    try {
      File(await _filePath(key)).writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  /// Removes cached data for a key (e.g. after sign-out).
  static Future<void> clear(String key) async {
    try {
      final file = File(await _filePath(key));
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
