class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supportEmail = String.fromEnvironment('VERO_SUPPORT_EMAIL');
  static const feedbackUrl = String.fromEnvironment('VERO_FEEDBACK_URL');

  static bool get hasSupabaseCredentials {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        supabaseAnonKey.length >= 20 &&
        !supabaseUrl.contains('YOUR_PROJECT') &&
        !supabaseAnonKey.contains('YOUR_PUBLIC');
  }
}
