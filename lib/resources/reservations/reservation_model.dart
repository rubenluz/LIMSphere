// reservation_model.dart - ReservationModel: booking start/end dates,
// resource reference, user info; fromMap serialisation.

import 'package:flutter/material.dart';

class ReservationModel {
  final int id;
  final String resourceType;
  final int? resourceId;
  final String? resourceName;
  final int? userId;
  final DateTime start;
  final DateTime end;
  final String? purpose;
  final String? project;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReservationModel({
    required this.id,
    required this.resourceType,
    required this.start,
    required this.end,
    required this.status,
    this.resourceId,
    this.resourceName,
    this.userId,
    this.purpose,
    this.project,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory ReservationModel.fromMap(Map<String, dynamic> m) => ReservationModel(
        id: (m['reservation_id'] as num).toInt(),
        resourceType: m['reservation_resource_type'] as String,
        resourceId: m['reservation_resource_id'] != null
            ? (m['reservation_resource_id'] as num).toInt()
            : null,
        resourceName: m['reservation_resource_name'] as String?,
        userId: m['reservation_user_id'] != null
            ? (m['reservation_user_id'] as num).toInt()
            : null,
        start: DateTime.parse(m['reservation_start'].toString()),
        end: DateTime.parse(m['reservation_end'].toString()),
        status: (m['reservation_status'] as String?) ?? 'confirmed',
        purpose: m['reservation_purpose'] as String?,
        project: m['reservation_project'] as String?,
        notes: m['reservation_notes'] as String?,
        createdAt: m['reservation_created_at'] != null
            ? DateTime.tryParse(m['reservation_created_at'].toString())
            : null,
        updatedAt: m['reservation_updated_at'] != null
            ? DateTime.tryParse(m['reservation_updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'reservation_resource_type': resourceType,
        'reservation_start': start.toUtc().toIso8601String(),
        'reservation_end': end.toUtc().toIso8601String(),
        'reservation_status': status,
        if (resourceId != null) 'reservation_resource_id': resourceId,
        if (resourceName != null) 'reservation_resource_name': resourceName,
        if (userId != null) 'reservation_user_id': userId,
        if (purpose != null) 'reservation_purpose': purpose,
        if (project != null) 'reservation_project': project,
        if (notes != null) 'reservation_notes': notes,
      };

  bool get isFuture => start.isAfter(DateTime.now());
  bool get isPast => end.isBefore(DateTime.now());
  bool get isOngoing =>
      start.isBefore(DateTime.now()) && end.isAfter(DateTime.now());

  Duration get duration => end.difference(start);

  Color get statusColor => switch (status.toLowerCase()) {
        'confirmed' => const Color(0xFF22C55E),
        'pending' => const Color(0xFFF59E0B),
        'cancelled' => const Color(0xFF64748B),
        'in_use' => const Color(0xFF38BDF8),
        'completed' => const Color(0xFF94A3B8),
        'no_show' => const Color(0xFFEF4444),
        _ => const Color(0xFF94A3B8),
      };

  static const statusOptions = [
    'pending',
    'confirmed',
    'cancelled',
  ];
}
