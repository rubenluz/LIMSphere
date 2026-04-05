// tanks_supabase_manager.dart - Tank-specific Supabase query helpers
// (upsert, delete) extracted for reuse across tanks_page and dialogs.

import '../../supabase/supabase_manager.dart';
import '/core/fish_db_schema.dart';
import 'tanks_connection_model.dart';

class TanksSupabaseManager {
  // Fetch tanks
  Future<List<ZebrafishTank>> fetchTanks({String? rack}) async {
    var q = SupabaseManager.client.from(FishSch.stocksTable).select();
    if (rack != null) q = q.eq(FishSch.stockRack, rack) as dynamic;

    final rows = await q.order(FishSch.stockTankId) as List<dynamic>;
    return rows.map((r) => ZebrafishTank.fromMap(r as Map<String, dynamic>)).toList();
  }

  // Upsert tank
  Future<void> upsertTank(ZebrafishTank tank) async {
    await SupabaseManager.client
        .from(FishSch.stocksTable)
        .upsert(tank.toMap(), onConflict: FishSch.stockTankId);
  }

  // Delete tank
  Future<void> deleteTank(String tankId) async {
    await SupabaseManager.client
        .from(FishSch.stocksTable)
        .delete()
        .eq(FishSch.stockTankId, tankId);
  }
}
