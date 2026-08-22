import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'location_model.dart';

class RoomInventoryReagent {
  final String name;
  final String? code;
  final int? locationId;
  final String? responsible;
  final String? storageTemperature;
  final String? quantity;
  final String? expiryDate;

  const RoomInventoryReagent({
    required this.name,
    this.code,
    this.locationId,
    this.responsible,
    this.storageTemperature,
    this.quantity,
    this.expiryDate,
  });
}

class RoomResponsiblePerson {
  final String name;
  final String? email;
  final String? phone;

  const RoomResponsiblePerson({required this.name, this.email, this.phone});
}

class RoomInventoryPdf {
  static Future<Uint8List> build({
    required LocationModel room,
    required String roomCode,
    required List<LocationModel> locations,
    required List<RoomInventoryReagent> reagents,
    required List<RoomResponsiblePerson> responsiblePeople,
    DateTime? generatedAt,
  }) async {
    final pdfTheme = await _unicodeTheme();
    final document = pw.Document(
      title: 'Room inventory - ${room.name}',
      author: 'LIMSphere',
      subject: 'Locations and reagents present in ${room.name}',
    );
    final created = (generatedAt ?? DateTime.now()).toLocal();
    final locationNames = <int, String>{
      room.id: room.name,
      for (final location in locations) location.id: location.name,
    };
    final sorted = sortedReagents(reagents);
    final sortedLocations = sortedLocationsByNumber(locations);
    final locationEntries = <pw.Widget>[
      for (var i = 0; i < sortedLocations.length; i++)
        _locationEntry(sortedLocations[i], i),
    ];
    final reagentEntries = <pw.Widget>[
      for (final reagent in sorted) _reagentEntry(reagent, locationNames),
    ];
    final firstReagentCapacity = firstReagentPageCapacity(
      locationCount: locations.length,
      responsibleCount: responsiblePeople.length,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pdfTheme,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        maxPages: 200,
        header: (context) {
          if (context.pageNumber == 1) return pw.SizedBox();
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  room.name,
                  style: pw.TextStyle(
                    color: PdfColors.indigo700,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '$roomCode  |  ROOM INVENTORY',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated ${_dateTime(created)}  |  Review against live inventory',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 7,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 7,
                ),
              ),
            ],
          ),
        ),
        build: (_) => [
          _header(room.name, roomCode),
          pw.SizedBox(height: 12),
          _summary(room, locations.length, reagents.length),
          pw.SizedBox(height: 12),
          _responsibleSection(
            title: 'RESPONSIBLE PEOPLE (${responsiblePeople.length})',
            emptyText: 'No responsible person recorded',
            entries: [
              for (final person in responsiblePeople) _responsibleEntry(person),
            ],
          ),
          pw.SizedBox(height: 14),
          ..._paginatedSection(
            title: 'LOCATIONS (${locations.length})',
            emptyText: 'No child locations recorded',
            entries: locationEntries,
            firstPageCapacity: 12,
            pageCapacity: 20,
          ),
          pw.SizedBox(height: 14),
          ..._paginatedSection(
            title: 'REAGENTS PRESENT (${reagents.length})',
            emptyText: 'No reagents recorded',
            entries: reagentEntries,
            firstPageCapacity: firstReagentCapacity,
            pageCapacity: 40,
          ),
        ],
      ),
    );
    return document.save();
  }

  static Future<pw.ThemeData> _unicodeTheme() async {
    final windowsRoot = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final candidates = <(String, String)>[
      (
        '$windowsRoot${Platform.pathSeparator}Fonts${Platform.pathSeparator}arial.ttf',
        '$windowsRoot${Platform.pathSeparator}Fonts${Platform.pathSeparator}arialbd.ttf',
      ),
      (
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      ),
      ('/system/fonts/NotoSans-Regular.ttf', '/system/fonts/NotoSans-Bold.ttf'),
      (
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
      ),
    ];

    for (final (regularPath, boldPath) in candidates) {
      final regularFile = File(regularPath);
      final boldFile = File(boldPath);
      if (!await regularFile.exists() || !await boldFile.exists()) continue;
      try {
        final regularBytes = await regularFile.readAsBytes();
        final boldBytes = await boldFile.readAsBytes();
        final regularFont = pw.Font.ttf(
          regularBytes.buffer.asByteData(
            regularBytes.offsetInBytes,
            regularBytes.lengthInBytes,
          ),
        );
        final boldFont = pw.Font.ttf(
          boldBytes.buffer.asByteData(
            boldBytes.offsetInBytes,
            boldBytes.lengthInBytes,
          ),
        );
        return pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
          fontFallback: [regularFont],
        );
      } catch (_) {
        // Try the next installed Unicode font before using the online fallback.
      }
    }

    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    return pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      fontFallback: [regularFont],
    );
  }

  static pw.Widget _header(String roomName, String roomCode) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo700,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ROOM INVENTORY REPORT',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                roomName,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Text(
            roomCode,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summary(
    LocationModel room,
    int locationCount,
    int reagentCount,
  ) {
    return pw.Row(
      children: [
        _summaryItem('ROOM TYPE', LocationModel.typeLabel(room.type)),
        pw.SizedBox(width: 7),
        _summaryItem('TEMPERATURE', displayRoomTemperature(room.temperature)),
        pw.SizedBox(width: 7),
        _summaryItem('LOCATIONS', '$locationCount'),
        pw.SizedBox(width: 7),
        _summaryItem('REAGENTS', '$reagentCount'),
      ],
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColors.grey600,
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      color: PdfColors.indigo700,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: .7,
    ),
  );

  static List<RoomInventoryReagent> sortedReagents(
    Iterable<RoomInventoryReagent> reagents,
  ) {
    return List<RoomInventoryReagent>.of(reagents)..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return (a.code ?? '').toLowerCase().compareTo(
        (b.code ?? '').toLowerCase(),
      );
    });
  }

  static String displayRoomTemperature(String? temperature) {
    final value = temperature?.trim();
    return value == null || value.isEmpty ? 'RT' : value;
  }

  static List<LocationModel> sortedLocationsByNumber(
    Iterable<LocationModel> locations,
  ) {
    final indexed = locations.indexed.toList();
    indexed.sort((a, b) {
      final byCode = _compareNaturalCode(a.$2.code, b.$2.code);
      if (byCode != 0) return byCode;
      final aOrder = a.$2.sortOrder;
      final bOrder = b.$2.sortOrder;
      if (aOrder != null && bOrder != null && aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }
      if (aOrder != null && bOrder == null) return -1;
      if (aOrder == null && bOrder != null) return 1;
      return a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }

  static int _compareNaturalCode(String? a, String? b) {
    final aCode = a?.trim();
    final bCode = b?.trim();
    if (aCode?.isNotEmpty != true && bCode?.isNotEmpty != true) return 0;
    if (aCode?.isNotEmpty != true) return 1;
    if (bCode?.isNotEmpty != true) return -1;
    final aNumbers = RegExp(r'\d+')
        .allMatches(aCode!)
        .map((match) => int.parse(match.group(0)!))
        .toList();
    final bNumbers = RegExp(r'\d+')
        .allMatches(bCode!)
        .map((match) => int.parse(match.group(0)!))
        .toList();
    final count = aNumbers.length < bNumbers.length
        ? aNumbers.length
        : bNumbers.length;
    for (var i = 0; i < count; i++) {
      final comparison = aNumbers[i].compareTo(bNumbers[i]);
      if (comparison != 0) return comparison;
    }
    final byPartCount = aNumbers.length.compareTo(bNumbers.length);
    if (byPartCount != 0) return byPartCount;
    return aCode.toLowerCase().compareTo(bCode.toLowerCase());
  }

  static List<RoomResponsiblePerson> resolveResponsiblePeople({
    required LocationModel room,
    required Iterable<LocationModel> locations,
    required Iterable<Map<String, dynamic>> users,
  }) {
    final userList = users.toList();
    final resolved = <String, RoomResponsiblePerson>{};
    for (final location in [room, ...locations]) {
      final entries = (location.responsible ?? '')
          .split(';')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty);
      for (final entry in entries) {
        final query = entry.toLowerCase();
        Map<String, dynamic>? match;
        for (final user in userList) {
          final email = (user['user_email'] as String?)?.trim().toLowerCase();
          final name = (user['user_name'] as String?)?.trim().toLowerCase();
          if (email == query || name == query) {
            match = user;
            break;
          }
        }
        final matchedName = (match?['user_name'] as String?)?.trim();
        final matchedEmail = (match?['user_email'] as String?)?.trim();
        final matchedPhone = (match?['user_phone'] as String?)?.trim();
        final person = RoomResponsiblePerson(
          name: matchedName?.isNotEmpty == true ? matchedName! : entry,
          email: matchedEmail?.isNotEmpty == true
              ? matchedEmail
              : (entry.contains('@') ? entry : null),
          phone: matchedPhone?.isNotEmpty == true ? matchedPhone : null,
        );
        final key = (person.email ?? person.name).toLowerCase();
        resolved[key] = person;
      }
    }
    return resolved.values.toList();
  }

  static (List<T>, List<T>) splitForColumns<T>(List<T> entries) {
    final splitAt = (entries.length + 1) ~/ 2;
    return (entries.sublist(0, splitAt), entries.sublist(splitAt));
  }

  static List<(T, T?)> pairSideBySide<T>(List<T> entries) {
    return [
      for (var i = 0; i < entries.length; i += 2)
        (entries[i], i + 1 < entries.length ? entries[i + 1] : null),
    ];
  }

  static int firstReagentPageCapacity({
    required int locationCount,
    required int responsibleCount,
  }) {
    final responsibleRows = responsibleCount < 1 ? 1 : responsibleCount;
    int availableRowsPerColumn;
    if (locationCount <= 12) {
      final locationRows = locationCount < 1 ? 1 : (locationCount + 1) ~/ 2;
      availableRowsPerColumn = 15 - locationRows - responsibleRows;
    } else {
      var locationsOnLastPage = (locationCount - 12) % 20;
      if (locationsOnLastPage == 0) locationsOnLastPage = 20;
      final locationRows = (locationsOnLastPage + 1) ~/ 2;
      availableRowsPerColumn = 19 - locationRows;
    }
    return availableRowsPerColumn.clamp(2, 15) * 2;
  }

  static List<pw.Widget> _paginatedSection({
    required String title,
    required String emptyText,
    required List<pw.Widget> entries,
    required int firstPageCapacity,
    required int pageCapacity,
    bool startOnNewPage = false,
  }) {
    if (entries.isEmpty) {
      return [
        if (startOnNewPage) pw.NewPage(),
        _balancedSection(title: title, emptyText: emptyText, entries: const []),
      ];
    }

    final widgets = <pw.Widget>[];
    var offset = 0;
    var pageIndex = 0;
    while (offset < entries.length) {
      final capacity = pageIndex == 0 ? firstPageCapacity : pageCapacity;
      final end = (offset + capacity).clamp(0, entries.length);
      if (pageIndex > 0 || (pageIndex == 0 && startOnNewPage)) {
        widgets.add(pw.NewPage());
      }
      widgets.add(
        _balancedSection(
          title: pageIndex == 0 ? title : '$title — CONTINUED',
          emptyText: emptyText,
          entries: entries.sublist(offset, end),
        ),
      );
      offset = end;
      pageIndex++;
    }
    return widgets;
  }

  static pw.Widget _balancedSection({
    required String title,
    required String emptyText,
    required List<pw.Widget> entries,
  }) {
    final heading = pw.Container(
      color: PdfColors.indigo50,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: _sectionTitle(title),
    );
    if (entries.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          heading,
          pw.Container(
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Text(
              emptyText,
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
          ),
        ],
      );
    }
    final (left, right) = splitForColumns(entries);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        heading,
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _entryColumn(left)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _entryColumn(right)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _responsibleSection({
    required String title,
    required String emptyText,
    required List<pw.Widget> entries,
  }) {
    final pairs = pairSideBySide(entries);
    final heading = pw.Container(
      color: PdfColors.indigo50,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: _sectionTitle(title),
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        heading,
        pw.SizedBox(height: 6),
        if (entries.isEmpty)
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Text(
              emptyText,
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
          )
        else
          pw.Column(
            children: [
              for (var i = 0; i < pairs.length; i++) ...[
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: pairs[i].$1),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: pairs[i].$2 ?? pw.SizedBox()),
                  ],
                ),
                if (i < pairs.length - 1) pw.SizedBox(height: 5),
              ],
            ],
          ),
      ],
    );
  }

  static pw.Widget _entryColumn(List<pw.Widget> entries) {
    return pw.Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          entries[i],
          if (i < entries.length - 1) pw.SizedBox(height: 5),
        ],
      ],
    );
  }

  static pw.Widget _locationEntry(LocationModel location, int index) {
    final details = <String>[
      LocationModel.typeLabel(location.type),
      if (location.temperature?.trim().isNotEmpty == true)
        location.temperature!.trim(),
      if (location.responsible?.trim().isNotEmpty == true)
        'Responsible: ${location.responsible!.trim()}',
    ];
    return _inventoryEntry(
      code: location.code ?? 'L${index + 1}',
      name: location.name,
      details: details.join(' | '),
    );
  }

  static pw.Widget _responsibleEntry(RoomResponsiblePerson person) {
    final contactLines = <String>[
      if (person.email?.trim().isNotEmpty == true &&
          person.email!.trim().toLowerCase() != person.name.toLowerCase())
        'Email: ${person.email!.trim()}',
      if (person.phone?.trim().isNotEmpty == true)
        'Phone: ${person.phone!.trim()}',
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            person.name,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          if (contactLines.isEmpty)
            pw.Text(
              person.email?.trim().isNotEmpty == true
                  ? 'Email: ${person.email!.trim()}'
                  : 'No contact details available',
              style: const pw.TextStyle(
                color: PdfColors.grey600,
                fontSize: 7.5,
              ),
            )
          else
            for (final line in contactLines)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 1),
                child: pw.Text(
                  line,
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 7.5,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static pw.Widget _reagentEntry(
    RoomInventoryReagent reagent,
    Map<int, String> locationNames,
  ) {
    final details = <String>[
      locationNames[reagent.locationId] ?? 'Room',
      if (reagent.storageTemperature?.trim().isNotEmpty == true)
        reagent.storageTemperature!.trim(),
      if (reagent.quantity?.trim().isNotEmpty == true) reagent.quantity!.trim(),
      if (reagent.expiryDate?.trim().isNotEmpty == true)
        'Expiry: ${reagent.expiryDate!.trim()}',
    ];
    return _inventoryEntry(
      code: _value(reagent.code),
      name: reagent.name,
      details: details.join(' | '),
    );
  }

  static pw.Widget _inventoryEntry({
    required String code,
    required String name,
    required String details,
    String? secondary,
  }) {
    return pw.SizedBox(
      height: 30,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 42,
              child: pw.Text(
                code,
                maxLines: 1,
                style: pw.TextStyle(
                  color: PdfColors.indigo700,
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    name,
                    maxLines: 1,
                    style: pw.TextStyle(
                      fontSize: 8.2,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      details,
                      maxLines: 1,
                      style: const pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 6.6,
                      ),
                    ),
                  ],
                  if (secondary != null) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      secondary,
                      maxLines: 1,
                      style: const pw.TextStyle(
                        color: PdfColors.grey600,
                        fontSize: 7.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _value(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? '-' : trimmed;
  }

  static String _dateTime(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
