class ReagentCodeAllocator {
  static final RegExp _brPattern = RegExp(
    r'^BR(\d+)$',
    caseSensitive: false,
  );

  final Set<String> _usedCodes;
  int _nextNumber;

  ReagentCodeAllocator(
    Iterable<String?> existingCodes, {
    Iterable<String?> reservedCodes = const [],
  })
      : _usedCodes = {
          for (final code in existingCodes)
            if (code != null && code.trim().isNotEmpty)
              code.trim().toUpperCase(),
          for (final code in reservedCodes)
            if (code != null && code.trim().isNotEmpty)
              code.trim().toUpperCase(),
        },
        _nextNumber = _highestBrNumber(existingCodes) + 1;

  static int _highestBrNumber(Iterable<String?> codes) {
    var highest = 0;
    for (final code in codes) {
      final match = _brPattern.firstMatch(code?.trim() ?? '');
      if (match == null) continue;
      final number = int.tryParse(match.group(1)!) ?? 0;
      if (number > highest) highest = number;
    }
    return highest;
  }

  String next() {
    while (true) {
      final code = 'BR${_nextNumber.toString().padLeft(4, '0')}';
      _nextNumber++;
      if (_usedCodes.add(code)) return code;
    }
  }
}
