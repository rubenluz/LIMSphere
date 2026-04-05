// to_do_widget.dart - Dashboard to-do list: create, edit, toggle, delete tasks
// stored in the todo_items Supabase table; due-date picker.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

class ToDoWidget extends StatefulWidget {
  const ToDoWidget({super.key});

  @override
  State<ToDoWidget> createState() => _ToDoWidgetState();
}

class _ToDoItem {
  final int id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;

  const _ToDoItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    required this.isCompleted,
  });

  factory _ToDoItem.fromMap(Map<String, dynamic> m) {
    DateTime? due;
    final raw = m['todo_due_date'];
    if (raw is String && raw.isNotEmpty) due = DateTime.tryParse(raw);

    return _ToDoItem(
      id: (m['todo_id'] as num).toInt(),
      title: m['todo_title'] as String,
      description: m['todo_description'] as String?,
      dueDate: due,
      isCompleted: (m['todo_is_completed'] as bool?) ?? false,
    );
  }
}

class _ToDoWidgetState extends State<ToDoWidget> {
  List<_ToDoItem> _items = [];
  bool _loading = true;

  static const _accent = Color(0xFF6366F1); // indigo

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('todo_items')
          .select('todo_id, todo_title, todo_description, todo_due_date, todo_is_completed')
          .order('todo_is_completed', ascending: true)
          .order('todo_due_date', ascending: true, nullsFirst: false)
          .order('todo_id', ascending: true);

      if (!mounted) return;
      setState(() {
        _items = (data as List).map((r) => _ToDoItem.fromMap(r)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('ToDoWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleComplete(_ToDoItem item) async {
    // Optimistic update
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        _items[idx] = _ToDoItem(
          id: item.id,
          title: item.title,
          description: item.description,
          dueDate: item.dueDate,
          isCompleted: !item.isCompleted,
        );
      }
    });
    try {
      await Supabase.instance.client
          .from('todo_items')
          .update({
            'todo_is_completed': !item.isCompleted,
            'todo_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('todo_id', item.id);
      _load();
    } catch (e) {
      debugPrint('ToDoWidget toggle error: $e');
      _load(); // revert on error
    }
  }

  Future<void> _delete(_ToDoItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete to-do?'),
        content: Text('Delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppDS.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _items.removeWhere((i) => i.id == item.id));
    try {
      await Supabase.instance.client
          .from('todo_items')
          .delete()
          .eq('todo_id', item.id);
    } catch (e) {
      debugPrint('ToDoWidget delete error: $e');
      _load();
    }
  }

  Future<void> _clearCompleted() async {
    final completed = _items.where((i) => i.isCompleted).toList();
    if (completed.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear completed?'),
        content: Text('Delete ${completed.length} completed item${completed.length == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppDS.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear all')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = completed.map((i) => i.id).toList();
    setState(() => _items.removeWhere((i) => i.isCompleted));
    try {
      await Supabase.instance.client
          .from('todo_items')
          .delete()
          .inFilter('todo_id', ids);
    } catch (e) {
      debugPrint('ToDoWidget clearCompleted error: $e');
      _load();
    }
  }

  Future<void> _showEditDialog(_ToDoItem item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl  = TextEditingController(text: item.description ?? '');
    DateTime? pickedDate = item.dueDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('Edit To-Do',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 15),
                      label: Text(pickedDate == null
                          ? 'Set due date'
                          : '${pickedDate!.day}/${pickedDate!.month}/${pickedDate!.year}'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: pickedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2099),
                        );
                        if (d != null) setDs(() => pickedDate = d);
                      },
                    ),
                  ),
                  if (pickedDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Clear due date',
                      onPressed: () => setDs(() => pickedDate = null),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await Supabase.instance.client
                      .from('todo_items')
                      .update({
                        'todo_title': title,
                        'todo_description': descCtrl.text.trim().isEmpty
                            ? null : descCtrl.text.trim(),
                        'todo_due_date': pickedDate?.toIso8601String().substring(0, 10),
                        'todo_updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('todo_id', item.id);
                  _load();
                } catch (e) {
                  debugPrint('ToDoWidget edit error: $e');
                }
              },
              child: const Text('Save')),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _showAddDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? pickedDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('New To-Do',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(pickedDate == null
                      ? 'Set due date (optional)'
                      : '${pickedDate!.day}/${pickedDate!.month}/${pickedDate!.year}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2099),
                    );
                    if (d != null) setDs(() => pickedDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await Supabase.instance.client.from('todo_items').insert({
                    'todo_title': title,
                    'todo_description': descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    'todo_due_date': pickedDate?.toIso8601String().substring(0, 10),
                    'todo_is_completed': false,
                  });
                  _load();
                } catch (e) {
                  debugPrint('ToDoWidget add error: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    descCtrl.dispose();
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_rounded, size: 36,
                color: context.appTextMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text('No to-dos yet',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: context.appTextMuted)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.appBorder),
      itemBuilder: (context, i) {
        final item = _items[i];
        final done = item.isCompleted;

        // Due date coloring
        Color? dueBadgeColor;
        String? dueBadgeLabel;
        if (item.dueDate != null && !done) {
          final today = DateTime.now();
          final d = DateTime(item.dueDate!.year, item.dueDate!.month, item.dueDate!.day);
          final diff = d.difference(DateTime(today.year, today.month, today.day)).inDays;
          if (diff < 0) {
            dueBadgeColor = AppDS.red;
            dueBadgeLabel = '${diff.abs()}d overdue';
          } else if (diff == 0) {
            dueBadgeColor = AppDS.orange;
            dueBadgeLabel = 'today';
          } else if (diff <= 3) {
            dueBadgeColor = AppDS.yellow;
            dueBadgeLabel = 'in ${diff}d';
          } else {
            dueBadgeColor = context.appTextMuted;
            dueBadgeLabel = '${d.day}/${d.month}';
          }
        }

        return InkWell(
          onTap: () => _toggleComplete(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: done,
                  activeColor: _accent,
                  side: BorderSide(color: context.appBorder2),
                  onChanged: (_) => _toggleComplete(item),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: done ? context.appTextMuted : context.appTextPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: context.appTextMuted,
                        ),
                      ),
                      if (item.description != null && item.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 11, color: context.appTextMuted),
                        ),
                      ],
                      Row(
                        children: [
                          if (dueBadgeLabel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: dueBadgeColor!.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(dueBadgeLabel,
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: dueBadgeColor)),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                size: 15, color: context.appTextMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: 'Edit',
                            onPressed: () => _showEditDialog(item),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 15, color: context.appTextMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: 'Delete',
                            onPressed: () => _delete(item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    final pending = _items.where((i) => !i.isCompleted).length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _accent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 320 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(children: [
              const Icon(Icons.checklist_rounded, size: 20, color: _accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('To-Do',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (!_loading && _items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              if (!_loading && _items.any((i) => i.isCompleted))
                IconButton(
                  icon: const Icon(Icons.done_all, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Clear completed',
                  color: context.appTextMuted,
                  onPressed: _clearCompleted,
                ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Add to-do',
                color: _accent,
                onPressed: _showAddDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),
          if (desktop)
            Expanded(child: SingleChildScrollView(child: _buildList(context)))
          else
            _buildList(context),
        ],
      ),
    );
  }
}
