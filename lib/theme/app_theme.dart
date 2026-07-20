import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Lichtpfad"-Designsystem: Nachtblau/Indigo Grund, Gold/Bernstein Akzent,
/// Cremeweiß für Text. Würdevoll, warm – kein Arcade/Casino.
class AppColors {
  static const night = Color(0xFF0E1330); // tiefes Nachtblau
  static const nightDeep = Color(0xFF070A1C);
  static const indigo = Color(0xFF1B2350);
  static const gold = Color(0xFFE7B85C); // Bernstein/Gold
  static const goldBright = Color(0xFFFFD98A);
  static const cream = Color(0xFFF4ECDD);
  static const creamDim = Color(0xFFB9B3A4);
  static const correct = Color(0xFFE7B85C);
  static const wrong = Color(0xFF6B7299); // gedämpft, nicht aggressiv-rot

  static const cardBg = Color(0xFF161E45);
  static const cardBorder = Color(0xFF2B356B);

  // 2-Spieler-Modus: Spieler 1 = Gold, Spieler 2 = sanftes Türkis
  static const player1 = gold;
  static const player2 = Color(0xFF63C2C9);
  static const player2Bright = Color(0xFF8FE0E6);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.cormorantGaramondTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.cream, displayColor: AppColors.cream);
    return base.copyWith(
      // Im Web transparent, damit der WebGL-Nebel (nebula.js) durchscheint.
      scaffoldBackgroundColor: kIsWeb ? Colors.transparent : AppColors.night,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.goldBright,
        surface: AppColors.cardBg,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.cream,
      ),
    );
  }

  /// Sans-Schrift für UI-Elemente/Optionen (gute Lesbarkeit).
  static TextStyle ui(double size, {FontWeight w = FontWeight.w500, Color? c}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: c ?? AppColors.cream);
}

/// Symbol & Farbton je Kategorie (Lichtpfad-Regionen).
class CategoryStyle {
  final IconData icon;
  final Color tint;
  const CategoryStyle(this.icon, this.tint);

  static const _map = {
    'bibel': CategoryStyle(Icons.auto_stories_rounded, Color(0xFF8FB8E0)),
    'torah': CategoryStyle(Icons.menu_book_rounded, Color(0xFFE7B85C)),
    'history': CategoryStyle(Icons.castle_rounded, Color(0xFFC98A5E)),
    'wisdom': CategoryStyle(Icons.light_mode_rounded, Color(0xFFE0C36A)),
    'prophets': CategoryStyle(Icons.auto_awesome_rounded, Color(0xFF9DB4E0)),
    'gospels': CategoryStyle(Icons.water_drop_rounded, Color(0xFF7FB7C9)),
    'church': CategoryStyle(Icons.local_fire_department_rounded, Color(0xFFE39A6A)),
    'revelation': CategoryStyle(Icons.brightness_7_rounded, Color(0xFFE7C45C)),
    'general': CategoryStyle(Icons.public_rounded, Color(0xFFBCA6E0)),
  };

  static CategoryStyle of(String slug) =>
      _map[slug] ?? const CategoryStyle(Icons.help_outline_rounded, AppColors.gold);
}

/// Farbcode je Schwierigkeit: leicht = Hellblau, mittel = Gold, schwer = Rot.
/// Steuert den Kometen-Schweif und das Stufen-Label (sichtbar auch im
/// „Alle"-Filter, wo die Stufe pro Frage wechselt).
class DifficultyStyle {
  final Color base;
  final Color bright;
  final String labelKey; // tr()-Schlüssel

  const DifficultyStyle(this.base, this.bright, this.labelKey);

  static const _easy =
      DifficultyStyle(Color(0xFF3E9BD6), Color(0xFF8FD4F5), 'diffEasy'); // hellblau
  static const _medium =
      DifficultyStyle(AppColors.gold, AppColors.goldBright, 'diffMedium'); // gelb/gold
  static const _hard =
      DifficultyStyle(Color(0xFFDE4A43), Color(0xFFFF8577), 'diffHard'); // rot

  static DifficultyStyle of(int difficulty) {
    if (difficulty <= 1) return _easy;
    if (difficulty >= 3) return _hard;
    return _medium;
  }
}
