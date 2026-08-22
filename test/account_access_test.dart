import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/login/account_access.dart';

void main() {
  group('account access', () {
    test('only explicitly active accounts may sign in', () {
      expect(hasActiveAccount({'user_status': 'active'}), isTrue);
      expect(hasActiveAccount({'user_status': 'pending'}), isFalse);
      expect(hasActiveAccount({'user_status': 'inactive'}), isFalse);
      expect(hasActiveAccount({'user_status': null}), isFalse);
      expect(hasActiveAccount(null), isFalse);
    });

    test('permission and role fields cannot substitute for active status', () {
      expect(
        hasActiveAccount({
          'user_status': 'pending',
          'user_role': 'superadmin',
          'user_table_dashboard': 'write',
        }),
        isFalse,
      );
    });
  });
}
