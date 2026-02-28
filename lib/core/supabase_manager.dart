import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../models/connection_model.dart';
import 'local_storage.dart';

class SupabaseManager {
  static SupabaseClient? _client;
  static String? _currentUrl;

  static SupabaseClient get client {
    if (_client == null) throw Exception('Supabase not initialized');
    return _client!;
  }

  static bool get isInitialized => _client != null;

  static bool get hasActiveSession {
    if (!isInitialized) return false;
    return _client!.auth.currentSession != null;
  }

  /// MAIN INITIALIZATION (used when user selects a connection)
  static Future<void> initialize(ConnectionModel conn) async {
    await _init(conn.url, conn.anonKey);
    await LocalStorage.saveLastConnection(conn);
  }

  /// Restore last used connection silently on app start
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
    // If already initialized to the same URL, reuse the existing instance
    if (_client != null && _currentUrl == url) return;

    // If Supabase was initialized to a different URL, dispose it first
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Not yet initialized — that's fine
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
// ── Tanks ─────────────────────────────────────────────────────────────────
  Future<List<ZebrafishTank>> fetchTanks({String? rack}) async {
    var q = _client?.from('zebrafish_facility').select();
    if (rack != null) q = q?.eq('zebra_rack', rack) as dynamic;
    final rows = await q?.order('zebra_tank_id') as List<dynamic>;
    return rows.map((r) => ZebrafishTank.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> upsertTank(ZebrafishTank tank) async {
    await _client?.from('zebrafish_facility').upsert(tank.toMap());
  }

  Future<void> deleteTank(String tankId) async {
    await _client?.from('zebrafish_facility').delete().eq('zebra_tank_id', tankId);
  }

  // ── Fish Lines ────────────────────────────────────────────────────────────
  Future<List<FishLine>> fetchLines() async {
    final rows = await _client?.from('fishlines').select().order('fishline_name') as List<dynamic>;
    return rows.map((r) => FishLine.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> upsertLine(FishLine line) async {
    final data = line.toMap();
    data['fishline_updated_at'] = DateTime.now().toIso8601String();
    await _client?.from('fishlines').upsert(data);
  }

  Future<void> deleteLine(int lineId) async {
    await _client?.from('fishlines').delete().eq('fishline_id', lineId);
  }
}
