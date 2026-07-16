import '../services/settings_service.dart';

/// Leichtgewichtige UI-Übersetzung (de/ru/en) ohne ARB-Codegen.
/// Erweiterbar: einfach Keys ergänzen. Inhaltsfragen bleiben (vorerst) Englisch.
const supportedLangs = ['en', 'de', 'ru'];

const Map<String, Map<String, String>> _t = {
  'tagline': {
    'en': 'A journey of light through Scripture',
    'de': 'Eine Lichtreise durch die Schrift',
    'ru': 'Путь света через Писание',
  },
  'quickPlay': {'en': 'Quick Play', 'de': 'Schnellspiel', 'ru': 'Быстрая игра'},
  'regions': {'en': 'Regions', 'de': 'Regionen', 'ru': 'Регионы'},
  'games': {'en': 'games', 'de': 'Spiele', 'ru': 'игр'},
  'bestScore': {'en': 'best score', 'de': 'Bestwert', 'ru': 'рекорд'},
  'accuracy': {'en': 'accuracy', 'de': 'Trefferquote', 'ru': 'точность'},
  'questions': {'en': 'questions', 'de': 'Fragen', 'ru': 'вопросов'},
  'settings': {'en': 'Settings', 'de': 'Einstellungen', 'ru': 'Настройки'},
  'sound': {'en': 'Sound', 'de': 'Ton', 'ru': 'Звук'},
  'soundSub': {'en': 'Effects & chimes', 'de': 'Effekte & Klänge', 'ru': 'Эффекты и звуки'},
  'volume': {'en': 'Volume', 'de': 'Lautstärke', 'ru': 'Громкость'},
  'language': {'en': 'Language', 'de': 'Sprache', 'ru': 'Язык'},
  'difficulty': {'en': 'Difficulty', 'de': 'Schwierigkeit', 'ru': 'Сложность'},
  'diffAll': {'en': 'All', 'de': 'Alle', 'ru': 'Все'},
  'diffEasy': {'en': 'Easy', 'de': 'Leicht', 'ru': 'Легко'},
  'diffMedium': {'en': 'Medium', 'de': 'Mittel', 'ru': 'Средне'},
  'diffHard': {'en': 'Hard', 'de': 'Schwer', 'ru': 'Сложно'},
  'noQuestions': {
    'en': 'No questions for this filter.',
    'de': 'Keine Fragen für diesen Filter.',
    'ru': 'Нет вопросов для этого фильтра.',
  },
  // Endlos-/Survival-Modus
  'endless': {'en': 'Endless', 'de': 'Endlos', 'ru': 'Бесконечный'},
  'gameOver': {'en': 'Game over', 'de': 'Vorbei!', 'ru': 'Игра окончена'},
  'survived': {
    'en': 'correct answers',
    'de': 'richtige Antworten',
    'ru': 'правильных ответов',
  },
  'newBest': {'en': 'New record!', 'de': 'Neuer Rekord!', 'ru': 'Новый рекорд!'},
  'retry': {'en': 'Again', 'de': 'Nochmal', 'ru': 'Ещё раз'},
  'survivalBest': {'en': 'record', 'de': 'Rekord', 'ru': 'рекорд'},
  // 2-Spieler (Hotseat)
  'twoPlayers': {'en': '2 Players', 'de': '2 Spieler', 'ru': '2 игрока'},
  'duelSetup': {'en': 'Local duel', 'de': 'Duell am Gerät', 'ru': 'Дуэль на устройстве'},
  'player1': {'en': 'Player 1', 'de': 'Spieler 1', 'ru': 'Игрок 1'},
  'player2': {'en': 'Player 2', 'de': 'Spieler 2', 'ru': 'Игрок 2'},
  'playerName': {'en': 'Name', 'de': 'Name', 'ru': 'Имя'},
  'rounds': {'en': 'Questions', 'de': 'Fragen', 'ru': 'Вопросы'},
  'category': {'en': 'Category', 'de': 'Kategorie', 'ru': 'Категория'},
  'mixed': {'en': 'Mixed', 'de': 'Gemischt', 'ru': 'Смешанные'},
  'start': {'en': 'Start', 'de': 'Start', 'ru': 'Начать'},
  'yourTurn': {'en': 'your turn', 'de': 'ist dran', 'ru': 'ходит'},
  'tapToAnswer': {'en': 'Tap your answer', 'de': 'Tippe deine Antwort', 'ru': 'Выбери ответ'},
  'next': {'en': 'Next', 'de': 'Weiter', 'ru': 'Дальше'},
  'leave': {'en': 'Leave', 'de': 'Verlassen', 'ru': 'Выйти'},
  'leaveGame': {'en': 'Leave the game?', 'de': 'Spiel verlassen?', 'ru': 'Выйти из игры?'},
  'leaveGameMsg': {
    'en': 'The current score will be lost.',
    'de': 'Der aktuelle Spielstand geht verloren.',
    'ru': 'Текущий счёт будет потерян.',
  },
  'cancel': {'en': 'Cancel', 'de': 'Abbrechen', 'ru': 'Отмена'},
  'wins': {'en': 'wins!', 'de': 'gewinnt!', 'ru': 'побеждает!'},
  'draw': {'en': 'Draw!', 'de': 'Unentschieden!', 'ru': 'Ничья!'},
  'rematch': {'en': 'Rematch', 'de': 'Revanche', 'ru': 'Реванш'},
  'correctAnswer': {'en': 'Correct', 'de': 'Richtig', 'ru': 'Правильно'},
  'strength': {'en': 'Level', 'de': 'Stärke', 'ru': 'Уровень'},
  'review': {'en': 'Review', 'de': 'Review', 'ru': 'Проверка'},
  'reviewMode': {'en': 'Question review', 'de': 'Fragen-Review', 'ru': 'Проверка вопросов'},
  'enterCode': {'en': 'Enter access code', 'de': 'Zugangscode eingeben', 'ru': 'Введите код доступа'},
  'wrongCode': {'en': 'Wrong code', 'de': 'Falscher Code', 'ru': 'Неверный код'},
  'load': {'en': 'Load', 'de': 'Laden', 'ru': 'Загрузить'},
  'saveNext': {'en': 'Save & next', 'de': 'Speichern & weiter', 'ru': 'Сохранить и далее'},
  'skip': {'en': 'Skip', 'de': 'Überspringen', 'ru': 'Пропустить'},
  'saved': {'en': 'Saved ✓', 'de': 'Gespeichert ✓', 'ru': 'Сохранено ✓'},
  'saveDisabled': {
    'en': 'Saving disabled — reviewer account not set up yet.',
    'de': 'Speichern deaktiviert — Reviewer-Konto noch nicht eingerichtet.',
    'ru': 'Сохранение отключено — аккаунт проверяющего не настроен.',
  },
  'reviewDone': {'en': 'All done — thank you!', 'de': 'Alles durch — danke!', 'ru': 'Готово — спасибо!'},
  'markCorrectHint': {
    'en': 'Tap the circle to mark the correct answer',
    'de': 'Tippe den Kreis an, um die richtige Antwort zu markieren',
    'ru': 'Нажми кружок, чтобы отметить верный ответ',
  },
  'handicapHint': {
    'en': 'Each player picks their own level — fair across ages.',
    'de': 'Jeder wählt seine eigene Stärke — fair über alle Altersgruppen.',
    'ru': 'Каждый выбирает свой уровень — честно для всех возрастов.',
  },
  'lightsKindled': {'en': 'lights kindled', 'de': 'Lichter entzündet', 'ru': 'огней зажжено'},
  'scoreLbl': {'en': 'Score', 'de': 'Punkte', 'ru': 'Очки'},
  'bestStreakLbl': {'en': 'Best streak', 'de': 'Beste Serie', 'ru': 'Лучшая серия'},
  'home': {'en': 'Home', 'de': 'Start', 'ru': 'Домой'},
  'contentNote': {
    'en': 'Questions are currently in English.',
    'de': 'Die Fragen sind derzeit auf Englisch.',
    'ru': 'Вопросы пока на английском.',
  },
  // Crowd-Einstufung der Schwierigkeit
  'rateQuestion': {
    'en': 'Report difficulty',
    'de': 'Schwierigkeit melden',
    'ru': 'Сообщить о сложности',
  },
  'rateCurrent': {'en': 'Current level', 'de': 'Aktuelle Stufe', 'ru': 'Текущий уровень'},
  'rateTooEasy': {
    'en': 'Too easy for this level',
    'de': 'Zu leicht für diese Stufe',
    'ru': 'Слишком легко для уровня',
  },
  'rateTooHard': {
    'en': 'Too hard for this level',
    'de': 'Zu schwer für diese Stufe',
    'ru': 'Слишком сложно для уровня',
  },
  'rateThanks': {
    'en': 'Thanks! Your report counts.',
    'de': 'Danke! Deine Meldung zählt.',
    'ru': 'Спасибо! Ваш отзыв учтён.',
  },
  'rateAlready': {'en': 'Already reported ✓', 'de': 'Schon gemeldet ✓', 'ru': 'Уже отмечено ✓'},
  // Achievements
  'achievements': {'en': 'Achievements', 'de': 'Erfolge', 'ru': 'Достижения'},
  'achUnlockedToast': {'en': 'Unlocked', 'de': 'Freigeschaltet', 'ru': 'Открыто'},
  'achUnlockedOn': {'en': 'Unlocked', 'de': 'Freigeschaltet am', 'ru': 'Открыто'},
  'achHiddenHint': {
    'en': 'Hidden — discover how to unlock it.',
    'de': 'Versteckt — finde heraus, wie du es freischaltest.',
    'ru': 'Скрыто — узнай, как открыть.',
  },
  'block1': {'en': 'The Journey', 'de': 'Die Reise', 'ru': 'Путь'},
  'block2': {'en': 'Daily Streaks', 'de': 'Tagesserien', 'ru': 'Серии дней'},
  'block3': {'en': 'Skill', 'de': 'Können', 'ru': 'Мастерство'},
  'block4': {'en': 'Topic Mastery', 'de': 'Themen-Meisterschaft', 'ru': 'Мастерство тем'},
  'block5': {'en': 'Hidden', 'de': 'Versteckt', 'ru': 'Скрытые'},
  // Sternbild der Weisheit (Daniel 12,3)
  'skyTitle': {
    'en': 'Constellation of Wisdom',
    'de': 'Sternbild der Weisheit',
    'ru': 'Созвездие мудрости',
  },
  'skyVerse': {
    'en': 'Those who are wise will shine like the brightness of the heavens, and those who lead many to righteousness, like the stars for ever and ever.',
    'de': 'Und die Verständigen werden leuchten wie des Himmels Glanz, und die vielen zur Gerechtigkeit weisen, wie die Sterne immer und ewiglich.',
    'ru': 'И разумные будут сиять, как светила на тверди, и обратившие многих к правде — как звёзды, вовеки, навсегда.',
  },
  'skyRef': {'en': 'Daniel 12:3', 'de': 'Daniel 12,3', 'ru': 'Даниил 12:3'},
  'skyStarsLabel': {
    'en': 'shining stars',
    'de': 'leuchtende Sterne',
    'ru': 'сияющих звёзд',
  },
  'skyEmpty': {
    'en': 'Answer questions correctly to kindle your sky.',
    'de': 'Beantworte Fragen richtig, um deinen Himmel zu entzünden.',
    'ru': 'Отвечай верно, чтобы зажечь своё небо.',
  },
  'skyNext': {
    'en': 'more to the next constellation',
    'de': 'bis zum nächsten Sternbild',
    'ru': 'до следующего созвездия',
  },
  'skyRank0': {'en': 'The First Spark', 'de': 'Der erste Funke', 'ru': 'Первая искра'},
  'skyRank1': {'en': 'First Lights', 'de': 'Erste Lichter', 'ru': 'Первые огни'},
  'skyRank2': {'en': 'A Walking Path', 'de': 'Wandelnder Pfad', 'ru': 'Идущий путь'},
  'skyRank3': {'en': 'A Shining Path', 'de': 'Leuchtender Pfad', 'ru': 'Сияющий путь'},
  'skyRank4': {'en': 'A Radiant Covenant', 'de': 'Strahlender Bund', 'ru': 'Сияющий завет'},
  'skyRank5': {
    'en': 'Brightness of the Heavens',
    'de': 'Himmelsglanz',
    'ru': 'Небесное сияние',
  },
  'skyRank6': {
    'en': 'Like the Stars, Forever',
    'de': 'Wie die Sterne, ewig',
    'ru': 'Как звёзды, навеки',
  },
  // Kategorienamen je slug
  'cat.torah': {'en': 'Law (Torah)', 'de': 'Gesetz (Tora)', 'ru': 'Закон (Тора)'},
  'cat.history': {'en': 'History of Israel', 'de': 'Geschichte Israels', 'ru': 'История Израиля'},
  'cat.wisdom': {'en': 'Wisdom & Poetry', 'de': 'Weisheit & Poesie', 'ru': 'Мудрость и поэзия'},
  'cat.prophets': {'en': 'Prophets', 'de': 'Propheten', 'ru': 'Пророки'},
  'cat.gospels': {'en': 'Gospels (Jesus)', 'de': 'Evangelien (Jesus)', 'ru': 'Евангелия (Иисус)'},
  'cat.church': {'en': 'Early Church', 'de': 'Frühe Gemeinde', 'ru': 'Ранняя церковь'},
  'cat.revelation': {'en': 'Revelation', 'de': 'Offenbarung', 'ru': 'Откровение'},
  'cat.general': {'en': 'General Bible', 'de': 'Bibel allgemein', 'ru': 'Общие вопросы'},
};

/// Übersetzt einen Key in die aktuell gewählte Sprache.
String tr(String key) {
  final lang = SettingsService.instance.locale.value;
  final entry = _t[key];
  if (entry == null) return key;
  return entry[lang] ?? entry['en'] ?? key;
}

/// Lokalisierter Kategoriename (Fallback: gelieferter Name aus dem Asset).
String trCategory(String slug, String fallback) {
  final entry = _t['cat.$slug'];
  if (entry == null) return fallback;
  final lang = SettingsService.instance.locale.value;
  return entry[lang] ?? entry['en'] ?? fallback;
}

const langLabels = {'en': 'English', 'de': 'Deutsch', 'ru': 'Русский'};
