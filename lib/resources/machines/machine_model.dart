// machine_model.dart - MachineModel: maps to the machines Supabase table;
// status, specs, location fields; fromMap / toMap serialisation.

import 'package:flutter/material.dart';

class MachineModel {
  final int id;
  final String name;
  final String? type;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String? patrimonyNumber;
  final int? locationId;
  final String? locationName;
  final String? room;
  final String status;
  final DateTime? purchaseDate;
  final DateTime? warrantyUntil;
  final DateTime? lastCalibration;
  final DateTime? nextCalibration;
  final int? calibrationIntervalDays;
  final DateTime? lastMaintenance;
  final DateTime? nextMaintenance;
  final int? maintenanceIntervalDays;
  final String? responsible;
  final String? manualLink;
  final String? supplier;
  final String? notes;
  final String? qrcode;
  final DateTime? createdAt;

  const MachineModel({
    required this.id,
    required this.name,
    required this.status,
    this.type,
    this.brand,
    this.model,
    this.serialNumber,
    this.patrimonyNumber,
    this.locationId,
    this.locationName,
    this.room,
    this.purchaseDate,
    this.warrantyUntil,
    this.lastCalibration,
    this.nextCalibration,
    this.calibrationIntervalDays,
    this.lastMaintenance,
    this.nextMaintenance,
    this.maintenanceIntervalDays,
    this.responsible,
    this.manualLink,
    this.supplier,
    this.notes,
    this.qrcode,
    this.createdAt,
  });

  factory MachineModel.fromMap(Map<String, dynamic> m) => MachineModel(
        id: (m['equipment_id'] as num).toInt(),
        name: m['equipment_name'] as String,
        status: (m['equipment_status'] as String?) ?? 'operational',
        type: m['equipment_type'] as String?,
        brand: m['equipment_brand'] as String?,
        model: m['equipment_model'] as String?,
        serialNumber: m['equipment_serial_number'] as String?,
        patrimonyNumber: m['equipment_patrimony_number'] as String?,
        locationId: m['equipment_location_id'] != null
            ? (m['equipment_location_id'] as num).toInt()
            : null,
        locationName: m['location_name'] as String?,
        room: m['equipment_room'] as String?,
        purchaseDate: m['equipment_purchase_date'] != null
            ? DateTime.tryParse(m['equipment_purchase_date'].toString())
            : null,
        warrantyUntil: m['equipment_warranty_until'] != null
            ? DateTime.tryParse(m['equipment_warranty_until'].toString())
            : null,
        lastCalibration: m['equipment_last_calibration'] != null
            ? DateTime.tryParse(m['equipment_last_calibration'].toString())
            : null,
        nextCalibration: m['equipment_next_calibration'] != null
            ? DateTime.tryParse(m['equipment_next_calibration'].toString())
            : null,
        calibrationIntervalDays:
            m['equipment_calibration_interval_days'] != null
                ? (m['equipment_calibration_interval_days'] as num).toInt()
                : null,
        lastMaintenance: m['equipment_last_maintenance'] != null
            ? DateTime.tryParse(m['equipment_last_maintenance'].toString())
            : null,
        nextMaintenance: m['equipment_next_maintenance'] != null
            ? DateTime.tryParse(m['equipment_next_maintenance'].toString())
            : null,
        maintenanceIntervalDays:
            m['equipment_maintenance_interval_days'] != null
                ? (m['equipment_maintenance_interval_days'] as num).toInt()
                : null,
        responsible: m['equipment_responsible'] as String?,
        manualLink: m['equipment_manual_link'] as String?,
        supplier: m['equipment_supplier'] as String?,
        notes: m['equipment_notes'] as String?,
        qrcode: m['equipment_qrcode'] as String?,
        createdAt: m['equipment_created_at'] != null
            ? DateTime.tryParse(m['equipment_created_at'].toString())
            : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'equipment_name': name,
        'equipment_status': status,
        if (type != null) 'equipment_type': type,
        if (brand != null) 'equipment_brand': brand,
        if (model != null) 'equipment_model': model,
        if (serialNumber != null) 'equipment_serial_number': serialNumber,
        if (patrimonyNumber != null)
          'equipment_patrimony_number': patrimonyNumber,
        if (locationId != null) 'equipment_location_id': locationId,
        if (room != null) 'equipment_room': room,
        if (purchaseDate != null)
          'equipment_purchase_date':
              purchaseDate!.toIso8601String().substring(0, 10),
        if (warrantyUntil != null)
          'equipment_warranty_until':
              warrantyUntil!.toIso8601String().substring(0, 10),
        if (lastCalibration != null)
          'equipment_last_calibration':
              lastCalibration!.toIso8601String().substring(0, 10),
        if (nextCalibration != null)
          'equipment_next_calibration':
              nextCalibration!.toIso8601String().substring(0, 10),
        if (calibrationIntervalDays != null)
          'equipment_calibration_interval_days': calibrationIntervalDays,
        if (lastMaintenance != null)
          'equipment_last_maintenance':
              lastMaintenance!.toIso8601String().substring(0, 10),
        if (nextMaintenance != null)
          'equipment_next_maintenance':
              nextMaintenance!.toIso8601String().substring(0, 10),
        if (maintenanceIntervalDays != null)
          'equipment_maintenance_interval_days': maintenanceIntervalDays,
        if (responsible != null) 'equipment_responsible': responsible,
        if (manualLink != null) 'equipment_manual_link': manualLink,
        if (supplier != null) 'equipment_supplier': supplier,
        if (notes != null) 'equipment_notes': notes,
      };

  bool get maintenanceDueSoon {
    if (nextMaintenance == null) return false;
    return nextMaintenance!.difference(DateTime.now()).inDays <= 14;
  }

  bool get maintenanceOverdue {
    if (nextMaintenance == null) return false;
    return nextMaintenance!.isBefore(DateTime.now());
  }

  Color get statusColor => switch (status.toLowerCase()) {
        'operational' => const Color(0xFF22C55E),
        'maintenance' => const Color(0xFFF97316),
        'broken' => const Color(0xFFEF4444),
        'retired' => const Color(0xFF64748B),
        _ => const Color(0xFF94A3B8),
      };

  static const statusOptions = [
    'operational',
    'maintenance',
    'broken',
    'retired'
  ];

  static String statusLabel(String s) => switch (s) {
        'operational' => 'Operational',
        'maintenance' => 'Maintenance',
        'broken' => 'Broken',
        'retired' => 'Retired',
        _ => s,
      };
}
