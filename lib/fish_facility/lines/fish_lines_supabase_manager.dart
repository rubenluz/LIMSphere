// fish_lines_supabase_manager.dart - Fish-line-specific Supabase query
// helpers (fetch active lines, upsert) extracted for reuse.

import '../../supabase/supabase_manager.dart';
import '/core/fish_db_schema.dart';
import 'fish_lines_connection_model.dart';

class FishLinesSupabaseManager {
  // ── Fish Lines ────────────────────────────────────────────────────────────

  Future<List<FishLine>> fetchLines() async {
    final rows = await SupabaseManager.client
        .from(FishSch.linesTable)
        .select()
        .order(FishSch.lineName) as List<dynamic>;
    return rows.map((r) => FishLine.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> upsertLine(FishLine line) async {
    final data = line.toMap();
    data[FishSch.lineUpdatedAt] = DateTime.now().toIso8601String();
    await SupabaseManager.client.from(FishSch.linesTable).upsert(data);
  }

  Future<void> deleteLine(int lineId) async {
    await SupabaseManager.client
        .from(FishSch.linesTable)
        .delete()
        .eq(FishSch.lineId, lineId);
  }
}
