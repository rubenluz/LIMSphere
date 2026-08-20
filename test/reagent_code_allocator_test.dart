import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/resources/reagents/reagent_code_allocator.dart';

void main() {
  group('ReagentCodeAllocator', () {
    test('continues after the highest existing BR code', () {
      final allocator = ReagentCodeAllocator(['BR0002', 'BR0014', 'OTHER']);

      expect(allocator.next(), 'BR0015');
      expect(allocator.next(), 'BR0016');
    });

    test('handles lowercase and non-padded BR codes', () {
      final allocator = ReagentCodeAllocator(['br9', 'BR0010']);

      expect(allocator.next(), 'BR0011');
    });

    test('starts at BR0001 when no BR code exists', () {
      final allocator = ReagentCodeAllocator([null, '', 'CHEM-A']);

      expect(allocator.next(), 'BR0001');
    });

    test('skips incoming reserved codes without changing the starting point', () {
      final allocator = ReagentCodeAllocator(
        ['BR0010'],
        reservedCodes: ['BR0011', 'BR0900'],
      );

      expect(allocator.next(), 'BR0012');
    });
  });
}
