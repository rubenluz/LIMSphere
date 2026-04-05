// local_storage.dart - SharedPreferences helpers: saved connections list,
// session expiry, remember-me duration, last-used email.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_connection/database_connection_model.dart';

class LocalStorage {
  static const _connectionsKey = 'connections';
  static const _lastConnectionKey = 'last_connection';
  static const _sessionExpiryKey = 'session_expiry_ms';
  static const _rememberDurationKey = 'remember_duration_days'; // 0 = session only
  static const _rememberedEmailKey = 'remembered_email';

  // ── Connections list ────────────────────────────────────────────────────────

  static Future<List<ConnectionModel>> loadConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_connectionsKey);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    return decoded.map((e) => ConnectionModel.fromJson(e)).toList();
  }

  static Future<void> saveConnections(List<ConnectionModel> connections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _connectionsKey,
      jsonEncode(connections.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> addConnection(ConnectionModel connection) async {
    final connections = await loadConnections();
    connections.add(connection);
    await saveConnections(connections);
  }

  // ── Last used connection ────────────────────────────────────────────────────

  static Future<void> saveLastConnection(ConnectionModel conn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastConnectionKey, jsonEncode(conn.toJson()));
  }

  static Future<ConnectionModel?> loadLastConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_lastConnectionKey);
    if (data == null) return null;
    try {
      return ConnectionModel.fromJson(jsonDecode(data));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearLastConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastConnectionKey);
    await prefs.remove(_sessionExpiryKey);
    await prefs.remove(_rememberDurationKey);
    await prefs.remove(_rememberedEmailKey);
  }

  // ── Session persistence ─────────────────────────────────────────────────────

  /// Save session expiry. [days] = 0 means "this session only" (don't persist).
  static Future<void> saveSessionExpiry(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rememberDurationKey, days);
    if (days > 0) {
      final expiry = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
      await prefs.setInt(_sessionExpiryKey, expiry);
    } else {
      await prefs.remove(_sessionExpiryKey);
    }
  }

  /// Returns true if there is a valid, non-expired saved session.
  static Future<bool> hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt(_sessionExpiryKey);
    if (expiry == null) return false;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  /// Returns how many days the user chose to remember (0 = never saved).
  static Future<int> getRememberDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_rememberDurationKey) ?? 0;
  }

  // ── Remembered email ────────────────────────────────────────────────────────

  static Future<void> saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedEmailKey, email);
  }

  static Future<void> clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedEmailKey);
  }

  static Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedEmailKey);
  }

}