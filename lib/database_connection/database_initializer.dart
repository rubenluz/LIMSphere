// database_initializer.dart - DatabaseInitializer: checks whether the schema
// has been applied and triggers the setup flow if required.

import '../supabase/supabase_manager.dart';

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