import 'supabase_manager.dart';

class DatabaseInitializer {
  static Future<bool> isDatabaseInitialized() async {
    try {
      final response = await SupabaseManager.client
          .from('app_meta')
          .select()
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      // table does not exist
      return false;
    }
  }
}