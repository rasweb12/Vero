class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supportEmail = String.fromEnvironment('VERO_SUPPORT_EMAIL');
  static const feedbackUrl = String.fromEnvironment('VERO_FEEDBACK_URL');

  static bool get hasSupabaseCredentials {
    final uri = Uri.tryParse(supabaseUrl);
    final normalizedKey = supabaseAnonKey.toLowerCase();
    final looksLikeServerSecret =
        normalizedKey.contains('service_role') ||
        normalizedKey.startsWith('sb_secret_');
    return uri != null &&
        uri.hasScheme &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        supabaseAnonKey.length >= 20 &&
        !supabaseUrl.contains('YOUR_PROJECT') &&
        !supabaseAnonKey.contains('YOUR_PUBLIC') &&
        !looksLikeServerSecret;
  }
}
