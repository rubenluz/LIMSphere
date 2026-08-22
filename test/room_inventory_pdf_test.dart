import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/resources/locations/location_model.dart';
import 'package:limsphere/resources/locations/room_inventory_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds an A4 room inventory PDF', () async {
    const room = LocationModel(
      id: 1,
      name: 'Molecular Lab',
      type: LocationModel.roomType,
      responsible: 'Dr. Silva',
    );
    const location = LocationModel(
      id: 2,
      name: 'Freezer 1',
      type: 'freezer',
      parentId: 1,
      responsible: 'Ana Costa',
    );

    final bytes = await RoomInventoryPdf.build(
      room: room,
      roomCode: 'R1',
      locations: const [location],
      responsiblePeople: const [
        RoomResponsiblePerson(
          name: 'Dr. Silva',
          email: 'silva@example.org',
          phone: '+351 296 000 000',
        ),
      ],
      reagents: const [
        RoomInventoryReagent(
          name: 'DNA polymerase α–β',
          code: 'RG-001',
          locationId: 2,
          quantity: '2 containers',
          storageTemperature: '-20 C',
        ),
      ],
      generatedAt: DateTime(2026, 8, 21, 10, 30),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('paginates a large inventory across printable A4 pages', () async {
    const room = LocationModel(
      id: 10,
      name: 'Coleção de culturas',
      type: LocationModel.roomType,
    );
    final reagents = List.generate(
      100,
      (index) => RoomInventoryReagent(
        name: 'Reagent ${index + 1}',
        code: 'RG-${index + 1}',
        locationId: 10,
      ),
    );

    final bytes = await RoomInventoryPdf.build(
      room: room,
      roomCode: 'R10',
      locations: const [],
      responsiblePeople: const [],
      reagents: reagents,
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final pdfSource = latin1.decode(bytes, allowInvalid: true);
    final pageObjects = RegExp(r'/Type\s*/Page\b').allMatches(pdfSource).length;
    expect(pageObjects, greaterThan(1));
    expect(pageObjects, lessThan(10));
  });

  test('sorts reagents alphabetically without changing the source list', () {
    const source = [
      RoomInventoryReagent(name: 'zinc'),
      RoomInventoryReagent(name: 'Agar'),
      RoomInventoryReagent(name: 'buffer'),
    ];

    final sorted = RoomInventoryPdf.sortedReagents(source);

    expect(sorted.map((item) => item.name), ['Agar', 'buffer', 'zinc']);
    expect(source.map((item) => item.name), ['zinc', 'Agar', 'buffer']);
  });

  test(
    'uses RT for an empty room temperature and preserves entered values',
    () {
      expect(RoomInventoryPdf.displayRoomTemperature(null), 'RT');
      expect(RoomInventoryPdf.displayRoomTemperature(''), 'RT');
      expect(RoomInventoryPdf.displayRoomTemperature(' 18 °C '), '18 °C');
    },
  );

  test('balances eight alphabetical entries as four per column', () {
    final entries = List.generate(8, (index) => index + 1);

    final (left, right) = RoomInventoryPdf.splitForColumns(entries);

    expect(left, [1, 2, 3, 4]);
    expect(right, [5, 6, 7, 8]);
  });

  test('pairs responsible people left to right in entered order', () {
    final pairs = RoomInventoryPdf.pairSideBySide([
      'Principal',
      'Deputy',
      'Third',
    ]);

    expect(pairs, [('Principal', 'Deputy'), ('Third', null)]);
  });

  test('sorts locations by their numeric code', () {
    const locations = [
      LocationModel(id: 10, code: 'L1.10', name: 'Ten', type: 'shelf'),
      LocationModel(id: 2, code: 'L1.2', name: 'Two', type: 'shelf'),
      LocationModel(id: 1, code: 'L1.1', name: 'One', type: 'shelf'),
    ];

    final sorted = RoomInventoryPdf.sortedLocationsByNumber(locations);

    expect(sorted.map((location) => location.code), ['L1.1', 'L1.2', 'L1.10']);
  });

  test('uses remaining first-page space for reagents', () {
    expect(
      RoomInventoryPdf.firstReagentPageCapacity(
        locationCount: 8,
        responsibleCount: 1,
      ),
      20,
    );
    expect(
      RoomInventoryPdf.firstReagentPageCapacity(
        locationCount: 12,
        responsibleCount: 2,
      ),
      14,
    );
  });

  test('resolves responsible contact details from location assignments', () {
    const room = LocationModel(
      id: 1,
      name: 'Room A',
      type: LocationModel.roomType,
      responsible: 'ana@example.org; External Person',
    );
    const location = LocationModel(
      id: 2,
      name: 'Freezer',
      type: 'freezer',
      responsible: 'Ana Costa',
    );

    final people = RoomInventoryPdf.resolveResponsiblePeople(
      room: room,
      locations: const [location],
      users: const [
        {
          'user_name': 'Ana Costa',
          'user_email': 'ana@example.org',
          'user_phone': '+351 296 123 456',
        },
      ],
    );

    expect(people, hasLength(2));
    expect(people.first.name, 'Ana Costa');
    expect(people.first.email, 'ana@example.org');
    expect(people.first.phone, '+351 296 123 456');
    expect(people.last.name, 'External Person');
    expect(people.last.email, isNull);
  });
}
