/// Zentrale App-Konfiguration.
///
/// Hinweis: `supabaseAnonKey` ist ein öffentlicher Client-Schlüssel (darf im
/// Web-Build stehen). Es liegen bewusst KEINE Login-Zugangsdaten mehr hier:
/// der Review-Schreibzugriff läuft über serverseitige RPCs
/// (`review_check_code` / `review_save_question`), die hinter einem Zugangscode
/// die schmalen Review-Writes erlauben. Der Code selbst wird vom Reviewer
/// eingegeben und nur serverseitig (gehasht in `review_config`) geprüft.
class AppConfig {
  static const supabaseUrl = 'https://gwaxeojltvibqmfvweim.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd3YXhlb2psdHZpYnFtZnZ3ZWltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4NTY5MjgsImV4cCI6MjA5NjQzMjkyOH0.K7vtiGMeNomqaU6MSpAHBEfEIOgJlcpjagXzNn6Os0M';
}
