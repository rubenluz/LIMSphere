import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:limsphere/core/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('session-only login is not restored', () async {
    await LocalStorage.saveSessionExpiry(0);

    expect(await LocalStorage.getRememberDays(), 0);
    expect(await LocalStorage.hasValidSession(), isFalse);
  });

  test('never forget login remains valid without an expiry date', () async {
    await LocalStorage.saveSessionExpiry(LocalStorage.rememberForever);

    expect(await LocalStorage.getRememberDays(), LocalStorage.rememberForever);
    expect(await LocalStorage.hasValidSession(), isTrue);
  });
}
