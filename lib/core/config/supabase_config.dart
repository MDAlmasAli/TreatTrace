// ─────────────────────────────────────────────────────────────────────────────
// supabase_config.dart
//
// SETUP INSTRUCTIONS:
// 1. Go to https://supabase.com and create a free project.
// 2. In your Supabase dashboard go to: Settings → API
// 3. Copy your "Project URL" and "anon public" key.
// 4. Paste them below in place of the placeholder strings.
//
// ⚠️  IMPORTANT: Never commit real credentials to a public Git repository.
//     For production, use environment variables or a .env file.
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseConfig {
  // Your Supabase project URL — looks like: https://xyzabc.supabase.co
  static const String supabaseUrl = 'https://prwnsmocfzlwtlvfucnz.supabase.co';

  // Your Supabase anonymous/public API key — a long JWT string
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByd25zbW9jZnpsd3RsdmZ1Y256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NTUyNTgsImV4cCI6MjA5MzEzMTI1OH0.wLafWGvLwNlSunO-F1i7twUofmqMXgFVQGap-g4Q-A0';
}
