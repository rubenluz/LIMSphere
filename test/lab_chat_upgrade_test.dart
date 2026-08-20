import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/lab_chat/lab_mention.dart';
import 'package:limsphere/lab_chat/lab_message.dart';

void main() {
  LabMessage message({String? owner = 'owner-uid'}) => LabMessage(
    id: 1,
    userAuthUid: owner,
    channel: 'general',
    body: 'Hello',
    createdAt: DateTime.utc(2026, 8, 20),
  );

  group('chat message editing', () {
    test('ordinary users can edit their own message', () {
      expect(
        canEditLabMessage(
          message: message(),
          authUid: 'owner-uid',
          role: 'researcher',
        ),
        isTrue,
      );
    });

    test('ordinary users cannot edit another user message', () {
      expect(
        canEditLabMessage(
          message: message(),
          authUid: 'other-uid',
          role: 'researcher',
        ),
        isFalse,
      );
    });

    test('admins and superadmins can edit every message', () {
      for (final role in ['admin', 'superadmin']) {
        expect(
          canEditLabMessage(
            message: message(),
            authUid: 'other-uid',
            role: role,
          ),
          isTrue,
        );
      }
    });
  });

  group('chat mentions', () {
    test('creates a stable linked mention token', () {
      const mention = LabMention(type: 'strains', id: 42, label: 'ABC-42');
      expect(mention.token, '@[strains:42 ABC-42]');
    });

    test('normalizes unsafe PostgREST filter characters', () {
      expect(LabMentionSearch.normalize('  abc),id.eq.1%_*  '), 'abc id.eq.1');
    });
  });
}
