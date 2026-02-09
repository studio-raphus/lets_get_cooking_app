import 'package:flutter_dotenv/flutter_dotenv.dart';

class Secrets {
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  static String get anthropicApiKey {
    return dotenv.env['ANTHROPIC_API_KEY'] ?? '';
  }

  static String get revenueCatApiKey {
    return dotenv.env['REVENUE_CAT_API_KEY'] ?? '';
  }
}