/// Zentrale App-Konfiguration.
///
/// Hinweis: `anonKey` ist ein öffentlicher Client-Schlüssel (darf im Web-Build
/// stehen). Die Reviewer-Zugangsdaten gehören zu einem eigenen Review-Konto und
/// werden nur nach Eingabe des Zugangscodes für den Login verwendet.
class AppConfig {
  static const supabaseUrl = 'https://gwaxeojltvibqmfvweim.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd3YXhlb2psdHZpYnFtZnZ3ZWltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4NTY5MjgsImV4cCI6MjA5NjQzMjkyOH0.K7vtiGMeNomqaU6MSpAHBEfEIOgJlcpjagXzNn6Os0M';

  /// Statischer Zugangscode für den Review-Modus (in den Einstellungen).
  /// Frei änderbar.
  static const reviewCode = 'lichtpfad';

  /// Reviewer-Konto (eigenes Supabase-Konto mit Schreibrechten).
  /// ACHTUNG: liegt im öffentlichen Web-Build — nur Wegwerf-Konto verwenden,
  /// bei Nichtgebrauch im Supabase-Dashboard deaktivieren.
  static const reviewerEmail = 'REDACTED';
  static const reviewerPassword = 'REDACTED';

  static bool get reviewerConfigured =>
      reviewerEmail != 'REVIEWER_EMAIL' && reviewerPassword != 'REVIEWER_PASSWORT';
}
