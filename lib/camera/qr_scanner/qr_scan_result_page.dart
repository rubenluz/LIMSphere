import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/data_cache.dart';
import '/theme/module_permission.dart';
import '/theme/theme.dart';
import 'qr_record_lookup.dart';

class QrScanResultPage extends StatefulWidget {
  final QrRecordSummary record;
  final Future<Widget> Function() openRecord;
  final Widget scanAgainPage;

  const QrScanResultPage({
    super.key,
    required this.record,
    required this.openRecord,
    required this.scanAgainPage,
  });

  @override
  State<QrScanResultPage> createState() => _QrScanResultPageState();
}

class _QrScanResultPageState extends State<QrScanResultPage> {
  late QrRecordSummary _record = widget.record;
  bool _opening = false;
  bool _savingNote = false;

  Future<void> _openRecord() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final page = await widget.openRecord();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } catch (e) {
      if (mounted) _showMessage('Could not open record: $e', error: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _copyLink() async {
    final payload = _record.payload;
    final link =
        'limsphere://${payload.projectCode}/${payload.type}/${payload.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) _showMessage('QR link copied.');
  }

  Future<void> _addNote() async {
    final notesColumn = _record.spec.notesColumn;
    if (notesColumn == null || _savingNote) return;
    if (!context.requireModuleAction(ModuleAction.edit)) return;
    if (!context.canEditWorkflowState(_record.status)) {
      _showMessage(
        'This record cannot be edited in its current state.',
        error: true,
      );
      return;
    }

    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add quick note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Note',
            hintText: 'This will be appended to the existing notes.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Add note'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;

    setState(() => _savingNote = true);
    try {
      final current = await Supabase.instance.client
          .from(_record.spec.table)
          .select(notesColumn)
          .eq(_record.spec.idColumn, _record.payload.id)
          .maybeSingle();
      if (current == null) {
        throw const QrQuickActionException(
          'The record no longer exists or is not accessible.',
        );
      }
      final previous = current[notesColumn]?.toString().trim() ?? '';
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final appended = previous.isEmpty
          ? '[$timestamp] $note'
          : '$previous\n[$timestamp] $note';
      final updated = await Supabase.instance.client
          .from(_record.spec.table)
          .update({notesColumn: appended})
          .eq(_record.spec.idColumn, _record.payload.id)
          .select(_record.spec.idColumn);
      if ((updated as List).isEmpty) {
        throw const QrQuickActionException(
          'The note was not saved. Check your record permissions.',
        );
      }
      final cacheKey = _record.spec.cacheKey;
      if (cacheKey != null) await DataCache.clear(cacheKey);
      if (!mounted) return;
      setState(() => _record = _record.withNotes(appended));
      _showMessage('Note added.');
    } catch (e) {
      if (mounted) _showMessage('Could not add note: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppDS.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canQuickEdit =
        _record.spec.notesColumn != null &&
        context.canEditModule &&
        context.canEditWorkflowState(_record.status);
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        title: const Text('Record found'),
        backgroundColor: context.appSurface,
        foregroundColor: context.appTextPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppDS.blue500.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 36,
                  color: AppDS.blue500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _record.spec.categoryLabel.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _record.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_record.subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                _record.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appTextSecondary),
              ),
            ],
            if (_record.status != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Chip(
                  label: Text(_record.status!.replaceAll('_', ' ')),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _opening ? null : _openRecord,
              icon: _opening
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new_rounded),
              label: const Text('Open record'),
            ),
            if (canQuickEdit) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _savingNote ? null : _addNote,
                icon: _savingNote
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.note_add_outlined),
                label: const Text('Add quick note'),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy QR link'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => widget.scanAgainPage),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan another'),
            ),
            if (_record.notes != null && _record.notes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Latest notes',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  border: Border.all(color: context.appBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _record.notes!,
                  style: TextStyle(color: context.appTextSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class QrQuickActionException implements Exception {
  final String message;

  const QrQuickActionException(this.message);

  @override
  String toString() => message;
}
