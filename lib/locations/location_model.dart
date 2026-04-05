// location_model.dart - LocationModel: hierarchical parent-child relationship
// for rooms and sub-locations; fromMap serialisation.

import 'package:flutter/material.dart';

class LocationModel {
  final int id;
  final String name;
  final String type;
  final String? room;
  final String? temperature;
  final int? capacity;
  final int? parentId;
  final String? parentName;
  final String? responsible;
  final String? qrcode;
  final String? notes;
  final DateTime? createdAt;

  const LocationModel({
    required this.id,
    required this.name,
    required this.type,
    this.room,
    this.temperature,
    this.capacity,
    this.parentId,
    this.parentName,
    this.responsible,
    this.qrcode,
    this.notes,
    this.createdAt,
  });

  factory LocationModel.fromMap(Map<String, dynamic> m) => LocationModel(
        id: (m['location_id'] as num).toInt(),
        name: m['location_name'] as String,
        type: (m['location_type'] as String?) ?? 'room',
        room: m['location_room'] as String?,
        temperature: m['location_temperature'] as String?,
        capacity: m['location_capacity'] != null
            ? (m['location_capacity'] as num).toInt()
            : null,
        parentId: m['location_parent_id'] != null
            ? (m['location_parent_id'] as num).toInt()
            : null,
        parentName: m['parent_name'] as String?,
        responsible: m['location_responsible'] as String?,
        qrcode: m['location_qrcode'] as String?,
        notes: m['location_notes'] as String?,
        createdAt: m['location_created_at'] != null
            ? DateTime.tryParse(m['location_created_at'].toString())
            : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'location_name': name,
        'location_type': type,
        if (room != null) 'location_room': room,
        if (temperature != null) 'location_temperature': temperature,
        if (capacity != null) 'location_capacity': capacity,
        if (parentId != null) 'location_parent_id': parentId,
        if (notes != null) 'location_notes': notes,
      };

  LocationModel copyWith({
    int? id,
    String? name,
    String? type,
    String? room,
    String? temperature,
    int? capacity,
    int? parentId,
    String? parentName,
    String? responsible,
    String? qrcode,
    String? notes,
    DateTime? createdAt,
  }) =>
      LocationModel(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        room: room ?? this.room,
        temperature: temperature ?? this.temperature,
        capacity: capacity ?? this.capacity,
        parentId: parentId ?? this.parentId,
        parentName: parentName ?? this.parentName,
        responsible: responsible ?? this.responsible,
        qrcode: qrcode ?? this.qrcode,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );

  // Sorted alphabetically — room first as it is the top-level container
  static const typeOptions = [
    'room',
    'bench',
    'box',
    'cabinet',
    'cold_room',
    'cryotank',
    'drawer',
    'freezer',
    'fridge',
    'incubator',
    'oven',
    'rack',
    'shelf',
    'water_bath',
  ];

  static String typeLabel(String t) => switch (t) {
        'room'       => 'Room',
        'bench'      => 'Bench',
        'box'        => 'Box',
        'cabinet'    => 'Cabinet',
        'cold_room'  => 'Cold Room',
        'cryotank'   => 'Cryo Tank',
        'drawer'     => 'Drawer',
        'freezer'    => 'Freezer',
        'fridge'     => 'Fridge',
        'incubator'  => 'Incubator',
        'oven'       => 'Oven',
        'rack'       => 'Rack',
        'shelf'      => 'Shelf',
        'water_bath' => 'Water Bath',
        _ => t,
      };

  static Color typeAccent(String t) => switch (t) {
        'room'       => const Color(0xFF6366F1),
        'bench'      => const Color(0xFF64748B),
        'box'        => const Color(0xFF94A3B8),
        'cabinet'    => const Color(0xFF8B5CF6),
        'cold_room'  => const Color(0xFF38BDF8),
        'cryotank'   => const Color(0xFF06B6D4),
        'drawer'     => const Color(0xFFA78BFA),
        'freezer'    => const Color(0xFF0EA5E9),
        'fridge'     => const Color(0xFF14B8A6),
        'incubator'  => const Color(0xFFF59E0B),
        'oven'       => const Color(0xFFF97316),
        'rack'       => const Color(0xFF22C55E),
        'shelf'      => const Color(0xFF10B981),
        'water_bath' => const Color(0xFF3B82F6),
        _ => const Color(0xFF38BDF8),
      };

  static IconData typeIcon(String t) => switch (t) {
        'room'       => Icons.meeting_room_outlined,
        'bench'      => Icons.desk_outlined,
        'box'        => Icons.inbox_outlined,
        'cabinet'    => Icons.door_sliding_outlined,
        'cold_room'  => Icons.ac_unit_outlined,
        'cryotank'   => Icons.water_drop_outlined,
        'drawer'     => Icons.table_rows_outlined,
        'freezer'    => Icons.severe_cold,
        'fridge'     => Icons.kitchen,
        'incubator'  => Icons.thermostat_outlined,
        'oven'       => Icons.local_fire_department_outlined,
        'rack'       => Icons.view_column_outlined,
        'shelf'      => Icons.shelves,
        'water_bath' => Icons.hot_tub_outlined,
        _ => Icons.place_outlined,
      };
}
