// database_initializer.dart - Typed diagnostics for the Supabase schema check.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_manager.dart';

enum DatabaseCheckStatus {
  ready,
  notInitialized,
  noInternet,
  invalidCredentials,
  invalidSession,
  accessDenied,
  serviceUnavailable,
  invalidConfiguration,
  unknownError,
}

class DatabaseCheckResult {
  const DatabaseCheckResult(
    this.status, {
    required this.title,
    required this.message,
    this.technicalDetails,
  });

  final DatabaseCheckStatus status;
  final String title;
  final String message;
  final String? technicalDetails;

  bool get isReady => status == DatabaseCheckStatus.ready;
  bool get needsSetup => status == DatabaseCheckStatus.notInitialized;
}

class DatabaseInitializer {
  static Future<DatabaseCheckResult> checkDatabase() async {
    if (!SupabaseManager.isInitialized) {
      return const DatabaseCheckResult(
        DatabaseCheckStatus.invalidConfiguration,
        title: 'Connection is not configured',
        message: 'Select a saved database connection and try again.',
      );
    }

    try {
      final response = await SupabaseManager.readAppMetaAnonymously().timeout(
        const Duration(seconds: 12),
      );

      if (response?['meta_initialized'] == true) {
        return const DatabaseCheckResult(
          DatabaseCheckStatus.ready,
          title: 'Database ready',
          message: 'The database connection and schema are available.',
        );
      }

      return const DatabaseCheckResult(
        DatabaseCheckStatus.notInitialized,
        title: 'Database schema not initialized',
        message: 'The connection works, but the LIMSphere initialization record is missing or incomplete.',
      );
    } catch (error) {
      return classifyError(error);
    }
  }

  /// Kept for callers that only need a yes/no answer.
  static Future<bool> isDatabaseInitialized() async =>
      (await checkDatabase()).isReady;

  static DatabaseCheckResult classifyError(Object error) {
    if (error is TimeoutException) {
      return DatabaseCheckResult(
        DatabaseCheckStatus.noInternet,
        title: 'Cannot reach the internet',
        message: 'Check your internet connection, VPN, firewall, or DNS settings and try again.',
        technicalDetails: _safeDetails(error),
      );
    }

    if (error is PostgrestException) {
      final code = (error.code ?? '').toUpperCase();
      final message = error.message.toLowerCase();

      if (code == 'PGRST205' || code == '42P01' || code == 'PGRST204') {
        return DatabaseCheckResult(
          DatabaseCheckStatus.notInitialized,
          title: 'Database schema not initialized',
          message: 'Supabase is reachable, but the LIMSphere app_meta table or required column was not found.',
          technicalDetails: _postgrestDetails(error),
        );
      }

      if (code == 'PGRST301' || code == 'PGRST303') {
        final clockMismatch = message.contains('issued at future');
        return DatabaseCheckResult(
          DatabaseCheckStatus.invalidSession,
          title: clockMismatch
              ? 'Supabase session clock mismatch'
              : 'Supabase session rejected',
          message: clockMismatch
              ? 'The project key is valid, but Supabase Auth issued a user token that the Data API considers to be from the future. Sign in again; if it persists, the Supabase project services need their clocks synchronized.'
              : 'The project key is valid, but the restored user session JWT was rejected. Sign in again to create a fresh session.',
          technicalDetails: _postgrestDetails(error),
        );
      }

      if (code.startsWith('28') || message.contains('api key')) {
        return DatabaseCheckResult(
          DatabaseCheckStatus.invalidCredentials,
          title: 'Invalid Supabase key',
          message: 'The project rejected the saved publishable/anon key. Edit the connection and enter a valid client key.',
          technicalDetails: _postgrestDetails(error),
        );
      }

      if (code == '42501' ||
          code == 'PGRST302' ||
          code == 'PGRST106' ||
          message.contains('permission denied') ||
          message.contains('not exposed')) {
        return DatabaseCheckResult(
          DatabaseCheckStatus.accessDenied,
          title: 'Database access denied',
          message: 'The key is accepted, but app_meta is not accessible through the Supabase Data API. Check schema exposure, grants, and RLS.',
          technicalDetails: _postgrestDetails(error),
        );
      }

      if (code == 'PGRST000' ||
          code == 'PGRST001' ||
          code == 'PGRST002' ||
          code == 'PGRST003' ||
          code.startsWith('08') ||
          code.startsWith('53')) {
        return DatabaseCheckResult(
          DatabaseCheckStatus.serviceUnavailable,
          title: 'Supabase service unavailable',
          message: 'Supabase was reached, but its Data API or database is temporarily unavailable. Try again shortly.',
          technicalDetails: _postgrestDetails(error),
        );
      }

      return DatabaseCheckResult(
        DatabaseCheckStatus.unknownError,
        title: 'Database request failed',
        message: 'Supabase returned an unexpected database error. Use the details below to diagnose it.',
        technicalDetails: _postgrestDetails(error),
      );
    }

    final text = error.toString().toLowerCase();
    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('network is unreachable') ||
        text.contains('clientexception') ||
        text.contains('xmlhttprequest error')) {
      return DatabaseCheckResult(
        DatabaseCheckStatus.noInternet,
        title: 'Cannot reach Supabase',
        message: 'No network connection could be established. Check internet access, DNS, VPN, and firewall settings.',
        technicalDetails: _safeDetails(error),
      );
    }

    if (text.contains('invalid api key') ||
        text.contains('unauthorized') ||
        text.contains('statuscode: 401')) {
      return DatabaseCheckResult(
        DatabaseCheckStatus.invalidCredentials,
        title: 'Invalid Supabase key',
        message: 'The project rejected the saved publishable/anon key. Edit the connection and enter a valid client key.',
        technicalDetails: _safeDetails(error),
      );
    }

    if (text.contains('invalid url') ||
        text.contains('invalid argument') ||
        text.contains('no host specified') ||
        text.contains('unsupported scheme')) {
      return DatabaseCheckResult(
        DatabaseCheckStatus.invalidConfiguration,
        title: 'Invalid Supabase URL',
        message: 'The saved project URL is not valid. Edit the connection and use the HTTPS URL from Supabase project settings.',
        technicalDetails: _safeDetails(error),
      );
    }

    return DatabaseCheckResult(
      DatabaseCheckStatus.unknownError,
      title: 'Connection check failed',
      message: 'An unexpected error occurred while checking the database connection.',
      technicalDetails: _safeDetails(error),
    );
  }

  static String _postgrestDetails(PostgrestException error) {
    final parts = <String>[
      if (error.code != null && error.code!.isNotEmpty) 'Code: ${error.code}',
      error.message,
      if (error.hint != null && error.hint!.isNotEmpty) 'Hint: ${error.hint}',
    ];
    return parts.join('\n');
  }

  static String _safeDetails(Object error) {
    final details = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return details.length <= 500 ? details : '${details.substring(0, 500)}…';
  }
}
