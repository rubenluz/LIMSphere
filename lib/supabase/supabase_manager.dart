// supabase_manager.dart - Singleton Supabase client initialisation, project-ref
// extraction from the stored URL, and session restore on startup.

import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/database_connection/database_connection_model.dart';
import '/core/local_storage.dart';

class SupabaseManager {
  static SupabaseClient? _client;
  static String? _currentUrl;
  static String? currentName;

  static SupabaseClient get client {
    if (_client == null) throw Exception('Supabase not initialized');
    return _client!;
  }

  static bool get isInitialized => _client != null;

  /// Extracts the Supabase project reference ID from the URL.
  /// e.g. https://abcdefgh.supabase.co → 'abcdefgh'
  static String? get projectRef {
    if (_currentUrl == null) return null;
    try {
      return Uri.parse(_currentUrl!).host.split('.').first;
    } catch (_) {
      return null;
    }
  }

  static bool get hasActiveSession {
    if (!isInitialized) return false;
    return _client!.auth.currentSession != null;
  }

  /// MAIN INITIALIZATION (used when user selects a connection)
  static Future<void> initialize(ConnectionModel conn) async {
    await _init(conn.url, conn.anonKey);
    currentName = conn.name;
    await LocalStorage.saveLastConnection(conn);
  }

  /// Restore last used connection silently on app start
  static Future<bool> restoreLastConnection() async {
    final conn = await LocalStorage.loadLastConnection();
    if (conn == null) return false;
    try {
      await _init(conn.url, conn.anonKey);
      currentName = conn.name;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _init(String url, String anonKey) async {
    // If already initialized to the same URL, reuse the existing instance
    if (_client != null && _currentUrl == url) return;

    // Only dispose if we previously initialized (avoids assert in debug mode)
    if (_client != null) {
      try {
        await Supabase.instance.dispose();
      } catch (_) {}
      _client = null;
      _currentUrl = null;
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
    _currentUrl = url;
  }

  /// LIGHTWEIGHT HEALTH CHECK (for grid status dot)
  /// Uses a temporary isolated client — does NOT affect the global instance
  static Future<bool> testConnection(ConnectionModel conn) async {
    try {
      final temp = SupabaseClient(conn.url, conn.anonKey);
      await temp
          .from('app_meta')
          .select('meta_initialized')
          .limit(1)
          .maybeSingle();
      await temp.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// SIGN OUT
  static Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {}
    _client = null;
    _currentUrl = null;
    currentName = null;
    await LocalStorage.clearLastConnection();
  }

  /// TABLE CHECK (used in setup flow)
  static Future<bool> checkInitialized() async {
    if (!isInitialized) return false;

    try {
      final res = await client
          .from('app_meta')
          .select('meta_initialized')
          .limit(1)
          .maybeSingle();

      return res?['meta_initialized'] == true;
    } catch (_) {
      return false;
    }
  }

  /// SUPERADMIN CHECK
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