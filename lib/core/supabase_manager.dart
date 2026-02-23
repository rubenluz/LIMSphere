import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../models/connection_model.dart';
import 'local_storage.dart';

class SupabaseManager {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    if (_client == null) throw Exception('Supabase not initialized');
    return _client!;
  }

  static bool get isInitialized => _client != null;

  /// Returns true if Supabase is initialized AND the user has an active session.
  static bool get hasActiveSession {
    if (!isInitialized) return false;
    return _client!.auth.currentSession != null;
  }

  /// Initialize from a ConnectionModel and remember it as last used.
  static Future<void> initialize(ConnectionModel conn) async {
    await _init(conn.url, conn.anonKey);
    await LocalStorage.saveLastConnection(conn);
  }

  /// Restore the last used connection silently (called on startup).
  static Future<bool> restoreLastConnection() async {
    final conn = await LocalStorage.loadLastConnection();
    if (conn == null) return false;
    try {
      await _init(conn.url, conn.anonKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _init(String url, String anonKey) async {
    try {
      // Already initialized — reuse
      _client = Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _client = Supabase.instance.client;
    }
  }

  /// Sign out and clear session persistence.
  static Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {}
    await LocalStorage.clearLastConnection();
  }

  /// Checks if all core tables exist.
  static Future<bool> checkTables() async {
    if (!isInitialized) return false;
    final requiredTables = [
      'app_meta', 'users', 'samples', 'strains', 'reagents',
      'zebrafish_facility', 'equipment', 'reservations', 'orders',
      'audit_log', 'storage_locations', 'protocols',
    ];
    try {
      final res = await client
          .from('information_schema.tables')
          .select('table_name')
          .eq('table_schema', 'public');
      final existing = (res as List).map((e) => e['table_name'] as String).toSet();
      return requiredTables.every(existing.contains);
    } catch (_) {
      return false;
    }
  }

  /// Checks if any superadmin exists.
  static Future<bool> adminExists() async {
    if (!isInitialized) return false;
    try {
      final res = await client
          .from('users')
          .select('id')
          .eq('role', 'superadmin')
          .limit(1);
      return (res as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}