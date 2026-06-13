import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_outcome.dart';
import 'settings_service.dart';
import 'stats_service.dart';

/// Anzeige-Zustand eines Achievements.
enum AchState { locked, inProgress, unlocked }

/// Zweisprachiger Text (RU fällt über tr-Konvention auf EN zurück).
class AchText {
  final String de;
  final String en;
  const AchText(this.de, this.en);
  String get value =>
      SettingsService.instance.locale.value == 'de' ? de : en;
}

/// Definition eines Achievements (Inhalt + Bedingungs-/Fortschrittslogik).
class Achievement {
  final String id;
  final int block; // 1..5
  final AchText title;
  final AchText condition;
  final AchText tooltip;
  final bool hidden;
  final bool measurable;
  final num threshold;

  /// Aktueller Zählwert (für Fortschrittsbalken), 0..threshold.
  final num Function(AchievementService s) progress;

  /// Bedingung aktuell erfüllt?
  final bool Function(AchievementService s) achieved;

  const Achievement({
    required this.id,
    required this.block,
    required this.title,
    required this.condition,
    required this.tooltip,
    this.hidden = false,
    this.measurable = false,
    this.threshold = 1,
    required this.progress,
    required this.achieved,
  });

  String get titleText => title.value;
  String get conditionText => condition.value;
  String get tooltipText => tooltip.value;
}

/// Lokaler Achievement-Motor (Offline, shared_preferences). Gilt für den
/// Solo-Modus. Hält alle Zähler aus der Spezifikation fort und wertet nach
/// jedem Quiz die 30 Achievements aus.
class AchievementService {
  AchievementService._();
  static final AchievementService instance = AchievementService._();

  static const _key = 'achievements_v1';
  late SharedPreferences _prefs;

  /// Wird bei jeder Änderung erhöht, damit die UI neu zeichnet.
  final ValueNotifier<int> revision = ValueNotifier(0);

  // ---- Zähler / Kennzahlen (Abschnitt 5 der Spec) ----
  int hardCorrect = 0; // korrekt beantwortete Fragen der Stufe 3
  int comebackWins = 0; // Quiz bestanden trotz >=3 Fehlern
  int perfectQuizzes = 0; // 10/10 kumulativ
  int runningStreak = 0; // laufende Richtig-Serie über Quizgrenzen
  bool reachedIron = false; // jemals 25er-Serie erreicht
  bool fastCorrect = false; // Frage <5s richtig
  bool earlyPerfect = false; // makelloses Quiz vor 7:00
  bool midnight = false; // Quiz 0:00–4:00
  bool holyNight = false; // Quiz am 24.12.
  bool narrowPath = false; // seltene Frage (<5% global) richtig
  Map<String, int> areaCorrect = {}; // thema_0x -> richtige Fragen

  // Spiel-Tagesserie (Block 2)
  int playStreak = 0;
  int playStreakLongest = 0;
  String? lastPlayDay;

  // 80%-Tagesserie (Johannes, reise_07)
  String? q80Day;
  int q80Correct = 0;
  int q80Questions = 0;
  int q80Streak = 0;
  String? q80LastQualDay;

  // 100%-Quiz-Tagesserie (Perfekte Woche, koennen_03)
  int perfectDayStreak = 0;
  String? perfectDayLast;

  /// id -> ISO-Zeitpunkt der Freischaltung.
  Map<String, String> unlocked = {};

  // ---- Region -> Themen-Bereich (Block 4) ----
  static const _regionToArea = {
    'torah': 'thema_01',
    'history': 'thema_02',
    'wisdom': 'thema_03',
    'prophets': 'thema_04',
    'gospels': 'thema_05',
    'church': 'thema_06',
  };

  int get _games => StatsService.instance.gamesPlayed.value;
  int get _accuracy => StatsService.instance.accuracyPct;

  /// Provisorische 80%-Tagesserie inkl. des heute laufenden Tages.
  int get johannesDayStreak {
    final todayQual =
        q80Questions > 0 && q80Correct / q80Questions >= 0.8;
    if (!todayQual || q80Day == null) return q80Streak;
    if (q80LastQualDay != null && _isNextDay(q80LastQualDay!, q80Day!)) {
      return q80Streak + 1;
    }
    return 1; // heute beginnt eine frische Serie
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _fromJson(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {/* defekter Stand -> Defaults */}
    }
    // Rückwirkende Freischaltung mengenbasierter Achievements (z. B. bestehende
    // Nutzer mit schon vielen Spielen). Nutzt vorhandene Zähler.
    _evaluateAll();
    await _save();
  }

  /// Nach einem beendeten Solo-Quiz aufrufen. Liefert neu freigeschaltete.
  Future<List<Achievement>> recordQuiz(QuizOutcome o) async {
    // 1) Pro Antwort in Reihenfolge (laufende Serie, schwere Fragen, Bereiche)
    for (final a in o.answers) {
      if (a.correct) {
        runningStreak++;
        if (runningStreak >= 25) reachedIron = true;
        if (a.difficulty >= 3) hardCorrect++;
        if (a.elapsedMs < 5000) fastCorrect = true;
        for (final c in a.categories) {
          final area = _regionToArea[c];
          if (area != null) areaCorrect[area] = (areaCorrect[area] ?? 0) + 1;
        }
      } else {
        runningStreak = 0;
      }
    }

    // 2) Quiz-Ebene
    final perfect = o.isPerfect;
    if (perfect) perfectQuizzes++;
    final wrong = o.total - o.correct;
    final passed = o.total > 0 && o.correct / o.total >= 0.6;
    if (wrong >= 3 && passed) comebackWins++;

    final t = o.finishedAt;
    final hour = t.hour;
    if (perfect && hour < 7) earlyPerfect = true;
    if (hour < 4) midnight = true; // 0:00–3:59 Ortszeit
    if (t.month == 12 && t.day == 24) holyNight = true;

    // 3) Spiel-Tagesserie
    final today = _dayKey(t);
    if (lastPlayDay == null) {
      playStreak = 1;
    } else if (today == lastPlayDay) {
      // schon heute gespielt – Serie unverändert
    } else if (_isNextDay(lastPlayDay!, today)) {
      playStreak++;
    } else {
      playStreak = 1;
    }
    lastPlayDay = today;
    if (playStreak > playStreakLongest) playStreakLongest = playStreak;

    // 4) 100%-Quiz-Tagesserie (Perfekte Woche)
    if (perfect) {
      if (perfectDayLast == null) {
        perfectDayStreak = 1;
      } else if (today == perfectDayLast) {
        // heute schon ein perfektes Quiz gezählt
      } else if (_isNextDay(perfectDayLast!, today)) {
        perfectDayStreak++;
      } else {
        perfectDayStreak = 1;
      }
      perfectDayLast = today;
    }

    // 5) 80%-Tagesserie (Johannes): alten Tag abschließen, dann heute addieren
    if (q80Day == null) {
      q80Day = today;
      q80Correct = 0;
      q80Questions = 0;
    } else if (today != q80Day) {
      final qualified =
          q80Questions > 0 && q80Correct / q80Questions >= 0.8;
      if (qualified) {
        if (q80LastQualDay != null && _isNextDay(q80LastQualDay!, q80Day!)) {
          q80Streak++;
        } else {
          q80Streak = 1;
        }
        q80LastQualDay = q80Day;
      }
      q80Day = today;
      q80Correct = 0;
      q80Questions = 0;
    }
    q80Correct += o.correct;
    q80Questions += o.total;

    final newly = _evaluateAll();
    await _save();
    return newly;
  }

  /// „Schmaler Pfad" extern ausgelöst (globale <5%-Trefferquote).
  Future<List<Achievement>> markNarrowPath() async {
    if (narrowPath) return const [];
    narrowPath = true;
    final newly = _evaluateAll();
    await _save();
    return newly;
  }

  bool isUnlocked(String id) => unlocked.containsKey(id);
  DateTime? unlockedAt(String id) {
    final s = unlocked[id];
    return s == null ? null : DateTime.tryParse(s);
  }

  AchState stateOf(Achievement a) {
    if (isUnlocked(a.id)) return AchState.unlocked;
    final p = a.progress(this);
    if (a.measurable && p > 0) return AchState.inProgress;
    return AchState.locked;
  }

  int get unlockedCount => unlocked.length;

  /// Wertet alle Achievements aus (Fixpunkt wegen Abhängigkeiten Paulus/
  /// Komplettist). Liefert die in diesem Aufruf neu freigeschalteten.
  List<Achievement> _evaluateAll() {
    final newly = <Achievement>[];
    final nowIso = DateTime.now().toIso8601String();
    bool changed = true;
    while (changed) {
      changed = false;
      for (final a in catalog) {
        if (unlocked.containsKey(a.id)) continue;
        if (a.achieved(this)) {
          unlocked[a.id] = nowIso;
          newly.add(a);
          changed = true;
        }
      }
    }
    if (newly.isNotEmpty) revision.value++;
    return newly;
  }

  // ---------- Persistenz ----------
  Future<void> _save() async {
    await _prefs.setString(_key, json.encode(_toJson()));
    revision.value++;
  }

  Map<String, dynamic> _toJson() => {
        'hardCorrect': hardCorrect,
        'comebackWins': comebackWins,
        'perfectQuizzes': perfectQuizzes,
        'runningStreak': runningStreak,
        'reachedIron': reachedIron,
        'fastCorrect': fastCorrect,
        'earlyPerfect': earlyPerfect,
        'midnight': midnight,
        'holyNight': holyNight,
        'narrowPath': narrowPath,
        'areaCorrect': areaCorrect,
        'playStreak': playStreak,
        'playStreakLongest': playStreakLongest,
        'lastPlayDay': lastPlayDay,
        'q80Day': q80Day,
        'q80Correct': q80Correct,
        'q80Questions': q80Questions,
        'q80Streak': q80Streak,
        'q80LastQualDay': q80LastQualDay,
        'perfectDayStreak': perfectDayStreak,
        'perfectDayLast': perfectDayLast,
        'unlocked': unlocked,
      };

  void _fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    bool b(String k) => j[k] as bool? ?? false;
    hardCorrect = i('hardCorrect');
    comebackWins = i('comebackWins');
    perfectQuizzes = i('perfectQuizzes');
    runningStreak = i('runningStreak');
    reachedIron = b('reachedIron');
    fastCorrect = b('fastCorrect');
    earlyPerfect = b('earlyPerfect');
    midnight = b('midnight');
    holyNight = b('holyNight');
    narrowPath = b('narrowPath');
    areaCorrect = ((j['areaCorrect'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    playStreak = i('playStreak');
    playStreakLongest = i('playStreakLongest');
    lastPlayDay = j['lastPlayDay'] as String?;
    q80Day = j['q80Day'] as String?;
    q80Correct = i('q80Correct');
    q80Questions = i('q80Questions');
    q80Streak = i('q80Streak');
    q80LastQualDay = j['q80LastQualDay'] as String?;
    perfectDayStreak = i('perfectDayStreak');
    perfectDayLast = j['perfectDayLast'] as String?;
    unlocked = ((j['unlocked'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, v as String));
  }

  // ---------- Datums-Helfer (lokale Zeitzone) ----------
  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isNextDay(String prev, String today) {
    final p = DateTime.parse(prev);
    final next = DateTime(p.year, p.month, p.day + 1);
    final t = DateTime.parse(today);
    return t.year == next.year && t.month == next.month && t.day == next.day;
  }

  // ====================================================================
  //  Katalog der 30 Achievements
  // ====================================================================
  late final List<Achievement> catalog = [
    // ---- Block 1: Die Reise ----
    Achievement(
      id: 'reise_01', block: 1, measurable: true, threshold: 1,
      title: const AchText('Erster Schritt', 'First Step'),
      condition: const AchText('1 Quiz gespielt', '1 quiz played'),
      tooltip: const AchText('Das erste Quiz ist gespielt.', 'The first quiz is done.'),
      progress: (s) => s._games, achieved: (s) => s._games >= 1,
    ),
    Achievement(
      id: 'reise_02', block: 1, measurable: true, threshold: 10,
      title: const AchText('Henoch', 'Enoch'),
      condition: const AchText('10 Quizze gespielt', '10 quizzes played'),
      tooltip: const AchText('Henoch „wandelte mit Gott" (Gen 5,24) – das regelmäßige Mitgehen beginnt.',
          'Enoch "walked with God" (Gen 5:24) — steady companionship begins.'),
      progress: (s) => s._games, achieved: (s) => s._games >= 10,
    ),
    Achievement(
      id: 'reise_03', block: 1, measurable: true, threshold: 50,
      title: const AchText('Abraham', 'Abraham'),
      condition: const AchText('50 Quizze gespielt', '50 quizzes played'),
      tooltip: const AchText('Abraham brach ins Unbekannte auf, der Vater des Glaubens.',
          'Abraham set out into the unknown, father of faith.'),
      progress: (s) => s._games, achieved: (s) => s._games >= 50,
    ),
    Achievement(
      id: 'reise_04', block: 1, measurable: true, threshold: 100,
      title: const AchText('Esra', 'Ezra'),
      condition: const AchText('100 Quizze gespielt', '100 quizzes played'),
      tooltip: const AchText('Esra erforschte das Gesetz (Esra 7,10) – der Schriftgelehrte.',
          'Ezra studied the Law (Ezra 7:10) — the scribe.'),
      progress: (s) => s._games, achieved: (s) => s._games >= 100,
    ),
    Achievement(
      id: 'reise_05', block: 1, measurable: true, threshold: 300,
      title: const AchText('Salomo', 'Solomon'),
      condition: const AchText('300 Quizze + 30 schwere Fragen richtig',
          '300 quizzes + 30 hard questions correct'),
      tooltip: const AchText('Salomo bat um Weisheit statt Reichtum (1 Kön 3) – Meisterung des Schweren.',
          'Solomon asked for wisdom over riches (1 Kgs 3) — mastery of the hard.'),
      progress: (s) => s._games,
      achieved: (s) => s._games >= 300 && s.hardCorrect >= 30,
    ),
    Achievement(
      id: 'reise_06', block: 1, measurable: true, threshold: 700,
      title: const AchText('Petrus', 'Peter'),
      condition: const AchText('700 Quizze + 15 Comeback-Siege',
          '700 quizzes + 15 comeback wins'),
      tooltip: const AchText('Petrus fiel und stand wieder auf – der Fels (Mt 16,18).',
          'Peter fell and rose again — the rock (Mt 16:18).'),
      progress: (s) => s._games,
      achieved: (s) => s._games >= 700 && s.comebackWins >= 15,
    ),
    Achievement(
      id: 'reise_07', block: 1, measurable: true, threshold: 1200,
      title: const AchText('Johannes', 'John'),
      condition: const AchText('1200 Quizze + 30-Tage-Serie mit je ≥80 %',
          '1200 quizzes + 30-day streak of ≥80% each'),
      tooltip: const AchText('Johannes, der treue Jünger – Beständigkeit über lange Zeit.',
          'John, the faithful disciple — endurance over a long time.'),
      progress: (s) => s._games,
      achieved: (s) => s._games >= 1200 && s.johannesDayStreak >= 30,
    ),
    Achievement(
      id: 'reise_08', block: 1, measurable: true, threshold: 2000,
      title: const AchText('Paulus', 'Paul'),
      condition: const AchText('2000 Quizze + alle Vorgänger + Genauigkeit ≥75 %',
          '2000 quizzes + all predecessors + accuracy ≥75%'),
      tooltip: const AchText('„Ich habe den Lauf vollendet" (2 Tim 4,7) – die Krönung.',
          '"I have finished the race" (2 Tim 4:7) — the crown.'),
      progress: (s) => s._games,
      achieved: (s) =>
          s._games >= 2000 &&
          s._accuracy >= 75 &&
          ['reise_01', 'reise_02', 'reise_03', 'reise_04', 'reise_05',
                  'reise_06', 'reise_07']
              .every(s.isUnlocked),
    ),

    // ---- Block 2: Tagesserien ----
    _streak('serie_01', 3, const AchText('Dranbleiber', 'Sticker'),
        const AchText('Drei Tage in Folge.', 'Three days in a row.')),
    _streak('serie_02', 7, const AchText('Eine Woche treu', 'A Faithful Week'),
        const AchText('Eine ganze Woche.', 'A whole week.')),
    _streak('serie_03', 14, const AchText('Beständig', 'Steadfast'),
        const AchText('Zwei Wochen ohne Unterbrechung.', 'Two weeks unbroken.')),
    _streak('serie_04', 30, const AchText('Monatsbegleiter', 'Month Companion'),
        const AchText('Einen Monat lang dabei.', 'A month straight.')),
    _streak('serie_05', 100, const AchText('Unermüdlich', 'Tireless'),
        const AchText('Hundert Tage in Folge.', 'A hundred days in a row.')),
    _streak('serie_06', 365, const AchText('Henochs Jahr', "Enoch's Year"),
        const AchText('Henoch lebte 365 Jahre (Gen 5,23) – ein volles Jahr Treue.',
            'Enoch lived 365 years (Gen 5:23) — a full year of faithfulness.')),

    // ---- Block 3: Können ----
    Achievement(
      id: 'koennen_01', block: 3,
      title: const AchText('Makellos', 'Flawless'),
      condition: const AchText('Ein Quiz mit voller Punktzahl (10/10)',
          'A quiz with a perfect score (10/10)'),
      tooltip: const AchText('Ein fehlerfreies Quiz.', 'A flawless quiz.'),
      progress: (s) => s.perfectQuizzes >= 1 ? 1 : 0,
      achieved: (s) => s.perfectQuizzes >= 1,
    ),
    Achievement(
      id: 'koennen_02', block: 3,
      title: const AchText('Blitzdenker', 'Quick Thinker'),
      condition: const AchText('Eine Frage in unter 5 Sekunden richtig',
          'A question answered correctly in under 5 seconds'),
      tooltip: const AchText('Schnell und sicher.', 'Fast and sure.'),
      progress: (s) => s.fastCorrect ? 1 : 0, achieved: (s) => s.fastCorrect,
    ),
    Achievement(
      id: 'koennen_03', block: 3, measurable: true, threshold: 7,
      title: const AchText('Perfekte Woche', 'Perfect Week'),
      condition: const AchText('7 Tage in Folge je ein Quiz mit 100 %',
          '7 days in a row with a 100% quiz each'),
      tooltip: const AchText('Eine makellose Woche.', 'A flawless week.'),
      progress: (s) => s.perfectDayStreak, achieved: (s) => s.perfectDayStreak >= 7,
    ),
    Achievement(
      id: 'koennen_04', block: 3, measurable: true, threshold: 10,
      title: const AchText('Scharfschütze', 'Sharpshooter'),
      condition: const AchText('10 Quizze mit voller Punktzahl (kumulativ)',
          '10 perfect quizzes (cumulative)'),
      tooltip: const AchText('Zehnmal makellos.', 'Flawless ten times.'),
      progress: (s) => s.perfectQuizzes, achieved: (s) => s.perfectQuizzes >= 10,
    ),
    Achievement(
      id: 'koennen_05', block: 3, measurable: true, threshold: 25,
      title: const AchText('Eisern', 'Iron'),
      condition: const AchText('25 richtige Antworten in Folge (über Quizze hinweg)',
          '25 correct answers in a row (across quizzes)'),
      tooltip: const AchText('Kein Fehltritt über lange Strecke.', 'No misstep over a long stretch.'),
      progress: (s) => s.reachedIron ? 25 : s.runningStreak,
      achieved: (s) => s.reachedIron,
    ),
    Achievement(
      id: 'koennen_06', block: 3,
      title: const AchText('Frühaufsteher', 'Early Riser'),
      condition: const AchText('Ein makelloses Quiz vor 7:00 Uhr Ortszeit',
          'A flawless quiz before 7:00 local time'),
      tooltip: const AchText('In aller Frühe.', 'In the early morning.'),
      progress: (s) => s.earlyPerfect ? 1 : 0, achieved: (s) => s.earlyPerfect,
    ),

    // ---- Block 4: Themen-Meisterschaft (30 richtige je Bereich) ----
    _theme('thema_01', const AchText('Am Anfang', 'In the Beginning'),
        const AchText('Meister der fünf Bücher Mose.', 'Master of the five books of Moses.')),
    _theme('thema_02', const AchText('Throne & Schlachten', 'Thrones & Battles'),
        const AchText('Kenner von Israels Geschichte.', 'Versed in Israel\'s history.')),
    _theme('thema_03', const AchText('Saitenspiel', 'Strings'),
        const AchText('Vertraut mit Psalmen und Weisheit.', 'At home in Psalms and wisdom.')),
    _theme('thema_04', const AchText('Stimme der Propheten', 'Voice of the Prophets'),
        const AchText('Hört auf die Propheten.', 'Heeds the prophets.')),
    _theme('thema_05', const AchText('Vier Zeugen', 'Four Witnesses'),
        const AchText('Kenner der vier Evangelien.', 'Knows the four Gospels.')),
    _theme('thema_06', const AchText('Bis ans Ende der Welt', 'To the Ends of the Earth'),
        const AchText('Vertraut mit der frühen Kirche.', 'Familiar with the early church.')),

    // ---- Block 5: Versteckt ----
    Achievement(
      id: 'geheim_01', block: 5, hidden: true,
      title: const AchText('Mitternachtsöl', 'Midnight Oil'),
      condition: const AchText('Ein Quiz zwischen 0:00 und 4:00 Uhr gespielt',
          'A quiz played between 0:00 and 4:00'),
      tooltip: const AchText('Wachsam zu später Stunde.', 'Watchful in the late hours.'),
      progress: (s) => s.midnight ? 1 : 0, achieved: (s) => s.midnight,
    ),
    Achievement(
      id: 'geheim_02', block: 5, hidden: true,
      title: const AchText('Heilige Nacht', 'Holy Night'),
      condition: const AchText('Am 24. Dezember ein Quiz gespielt',
          'A quiz played on December 24'),
      tooltip: const AchText('An Heiligabend dabei.', 'Present on Christmas Eve.'),
      progress: (s) => s.holyNight ? 1 : 0, achieved: (s) => s.holyNight,
    ),
    Achievement(
      id: 'geheim_03', block: 5, hidden: true,
      title: const AchText('Schmaler Pfad', 'Narrow Path'),
      condition: const AchText('Eine Frage richtig, die <5 % aller Spieler treffen',
          'A question correct that <5% of players get right'),
      tooltip: const AchText('Den schmalen Weg gefunden.', 'Found the narrow way.'),
      progress: (s) => s.narrowPath ? 1 : 0, achieved: (s) => s.narrowPath,
    ),
    Achievement(
      id: 'geheim_04', block: 5, hidden: true,
      title: const AchText('Komplettist', 'Completionist'),
      condition: const AchText('Alle 29 anderen Achievements freigeschaltet',
          'All 29 other achievements unlocked'),
      tooltip: const AchText('Alles gesammelt.', 'Collected everything.'),
      progress: (s) => s.unlocked.length,
      achieved: (s) =>
          s.catalog.where((a) => a.id != 'geheim_04').every((a) => s.isUnlocked(a.id)),
    ),
  ];

  // Hilfs-Konstruktoren für die wiederkehrenden Blöcke 2 & 4.
  static Achievement _streak(String id, int days, AchText title, AchText tip) => Achievement(
        id: id, block: 2, measurable: true, threshold: days,
        title: title,
        condition: AchText('$days Tage in Folge gespielt', '$days days in a row'),
        tooltip: tip,
        progress: (s) => s.playStreak,
        achieved: (s) => s.playStreakLongest >= days,
      );

  static Achievement _theme(String id, AchText title, AchText tip) => Achievement(
        id: id, block: 4, measurable: true, threshold: 30,
        title: title,
        condition: const AchText('30 Fragen dieses Bereichs richtig',
            '30 questions of this area correct'),
        tooltip: tip,
        progress: (s) => s.areaCorrect[id] ?? 0,
        achieved: (s) => (s.areaCorrect[id] ?? 0) >= 30,
      );
}
