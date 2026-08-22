import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/database_connection/database_initializer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('DatabaseInitializer.classifyError', () {
    test('recognizes missing schema', () {
      const error = PostgrestException(
        message: "Could not find the table 'public.app_meta'",
        code: 'PGRST205',
      );

      final result = DatabaseInitializer.classifyError(error);

      expect(result.status, DatabaseCheckStatus.notInitialized);
      expect(result.needsSetup, isTrue);
    });

    test('recognizes a rejected user session', () {
      const error = PostgrestException(
        message: 'JWT issued at future',
        code: 'PGRST303',
      );

      final result = DatabaseInitializer.classifyError(error);

      expect(result.status, DatabaseCheckStatus.invalidSession);
      expect(result.title, contains('clock mismatch'));
      expect(result.needsSetup, isFalse);
    });

    test('recognizes an invalid project key from its response message', () {
      const error = PostgrestException(
        message: 'Invalid API key',
        code: 'PGRSTX00',
      );

      final result = DatabaseInitializer.classifyError(error);

      expect(result.status, DatabaseCheckStatus.invalidCredentials);
    });

    test('recognizes denied Data API access', () {
      const error = PostgrestException(
        message: 'permission denied for table app_meta',
        code: '42501',
      );

      final result = DatabaseInitializer.classifyError(error);

      expect(result.status, DatabaseCheckStatus.accessDenied);
    });

    test('recognizes Supabase service failures', () {
      const error = PostgrestException(
        message: 'Database connection unavailable',
        code: 'PGRST000',
      );

      final result = DatabaseInitializer.classifyError(error);

      expect(result.status, DatabaseCheckStatus.serviceUnavailable);
    });

    test('recognizes timeouts and socket errors', () {
      final timeout = DatabaseInitializer.classifyError(
        TimeoutException('request timed out'),
      );
      final socket = DatabaseInitializer.classifyError(
        Exception('SocketException: Failed host lookup'),
      );

      expect(timeout.status, DatabaseCheckStatus.noInternet);
      expect(socket.status, DatabaseCheckStatus.noInternet);
    });

    test('does not present unknown errors as missing schema', () {
      final result = DatabaseInitializer.classifyError(
        StateError('unexpected response'),
      );

      expect(result.status, DatabaseCheckStatus.unknownError);
      expect(result.needsSetup, isFalse);
    });
  });
}
