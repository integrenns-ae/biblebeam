// Gemeinsame Transform-Logik (v2): roher Katalog {q,a,categories[],level}
// -> Multiple-Choice-Pack. Genutzt von build_questions.mjs (Offline-Asset, Regionen)
// und build_seed.mjs (DB-Seed, Roh-Tags). Eine Quelle -> beide Artefakte.

// ── deterministischer RNG (mulberry32) ──
export function rng(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function shuffle(arr, rand) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function slugify(s) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

// ── Lichtpfad-Regionen (App-Auswahl, 8 Stück) ──
export const REGIONS = [
  { slug: 'torah', name: 'Law (Torah)' },
  { slug: 'history', name: 'History of Israel' },
  { slug: 'wisdom', name: 'Wisdom & Poetry' },
  { slug: 'prophets', name: 'Prophets' },
  { slug: 'gospels', name: 'Gospels (Jesus)' },
  { slug: 'church', name: 'Early Church' },
  { slug: 'revelation', name: 'Revelation' },
  { slug: 'general', name: 'General Bible' },
];

// Buch-Tag -> Region
const BOOK_REGION = {};
const _add = (region, books) => books.forEach((b) => (BOOK_REGION[b.toLowerCase()] = region));
_add('torah', ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy']);
_add('history', ['Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', 'Samuel', '1 Kings', '2 Kings', 'Kings', 'Chronicles', '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther']);
_add('wisdom', ['Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Songs']);
_add('prophets', ['Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi']);
_add('gospels', ['Matthew', 'Mark', 'Luke', 'John', 'Gospels']);
_add('church', ['Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Corinthians', 'Galatians', 'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', 'Thessalonians', '1 Timothy', '2 Timothy', 'Timothy', 'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter', 'Peter', '1 John', '2 John', '3 John', 'Jude']);
_add('revelation', ['Revelation']);

const TYPE_TAGS = new Set(['person', 'number', 'place', 'verse', 'general']);
const TESTAMENT_TAGS = new Set(['ot', 'nt']);

/** Dimension eines Roh-Tags: 'testament' | 'type' | 'book' */
export function classifyTag(tag) {
  const t = tag.toLowerCase();
  if (TESTAMENT_TAGS.has(t)) return 'testament';
  if (TYPE_TAGS.has(t)) return 'type';
  return 'book';
}

function regionsOf(tags) {
  const regions = new Set();
  for (const tag of tags) {
    if (classifyTag(tag) === 'book') {
      regions.add(BOOK_REGION[tag.toLowerCase()] || 'general');
    }
  }
  if (regions.size === 0) regions.add('general');
  return [...regions];
}

// ── Feinklassifizierung der Antworten für typgleiche Ablenker ──
// Ziel: Gewässer↔Gewässer, Städte↔Städte, Frauen↔Frauen, Männer↔Männer,
// Propheten↔Propheten, Könige↔Könige usw. Wichtig v. a. für „hard".
// Nur eindeutige Mitglieder werden fein klassifiziert; mehrdeutige bleiben grob.
const norm = (s) => s.trim().toLowerCase();
const SET = (...names) => new Set(names.map(norm));

const WOMEN = SET(
  'Eve', 'Sarah', 'Sarai', 'Hagar', 'Rebekah', 'Rachel', 'Leah', 'Dinah', 'Miriam', 'Zipporah',
  'Jochebed', 'Deborah', 'Jael', 'Delilah', 'Naomi', 'Ruth', 'Orpah', 'Hannah', 'Peninnah',
  'Abigail', 'Michal', 'Bathsheba', 'Tamar', 'Jezebel', 'Athaliah', 'Huldah', 'Esther', 'Vashti',
  'Mary', 'Martha', 'Elizabeth', 'Anna', 'Dorcas', 'Tabitha', 'Lydia', 'Priscilla', 'Phoebe',
  'Eunice', 'Lois', 'Rhoda', 'Sapphira', 'Magdalene', 'Salome', 'Gomer', 'Bilhah', 'Zilpah',
  'Rahab', 'Herodias', 'Candace', 'Keturah', 'Hagar', 'Abishag',
);
const KINGS = SET(
  'Saul', 'David', 'Solomon', 'Rehoboam', 'Jeroboam', 'Ahab', 'Omri', 'Jehu', 'Hezekiah',
  'Manasseh', 'Josiah', 'Zedekiah', 'Joash', 'Uzziah', 'Jotham', 'Ahaz', 'Jehoshaphat', 'Asa',
  'Nebuchadnezzar', 'Belshazzar', 'Darius', 'Cyrus', 'Xerxes', 'Ahasuerus', 'Herod', 'Agrippa',
  'Sennacherib', 'Jehoiakim', 'Jehoiachin', 'Abijah', 'Baasha', 'Ahaziah', 'Jehoram', 'Hoshea',
  'Pekah', 'Pharaoh', 'Nadab', 'Zimri', 'Tiglath-Pileser', 'Adonijah', 'Absalom', 'Amaziah',
  'Joram', 'Shalmaneser', 'Artaxerxes', 'Sargon', 'Esarhaddon', 'Abimelech', 'Ahasuerus',
);
const PROPHETS = SET(
  'Isaiah', 'Jeremiah', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
  'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi', 'Elijah', 'Elisha', 'Samuel',
  'Nathan', 'Gad', 'Ahijah', 'Balaam', 'Moses', 'Deborah', 'Huldah',
);
const APOSTLES = SET(
  'Peter', 'Andrew', 'James', 'John', 'Philip', 'Bartholomew', 'Thomas', 'Matthew', 'Thaddaeus',
  'Simon', 'Judas', 'Matthias', 'Nathanael', 'Paul',
);
const MEN = SET(
  'Adam', 'Cain', 'Abel', 'Seth', 'Enoch', 'Methuselah', 'Lamech', 'Noah', 'Shem', 'Ham', 'Japheth',
  'Nimrod', 'Abraham', 'Abram', 'Isaac', 'Jacob', 'Esau', 'Laban', 'Joseph', 'Reuben', 'Judah',
  'Benjamin', 'Levi', 'Simeon', 'Ephraim', 'Manasseh', 'Potiphar', 'Aaron', 'Hur', 'Caleb',
  'Joshua', 'Korah', 'Eleazar', 'Phinehas', 'Jethro', 'Gershom', 'Bezalel', 'Ehud', 'Gideon',
  'Jephthah', 'Samson', 'Boaz', 'Obed', 'Jesse', 'Jonathan', 'Abner', 'Joab', 'Uriah',
  'Mephibosheth', 'Nabal', 'Naaman', 'Gehazi', 'Elimelech', 'Mordecai', 'Haman', 'Ezra',
  'Nehemiah', 'Sanballat', 'Job', 'Elihu', 'Lazarus', 'Zacchaeus', 'Bartimaeus', 'Jairus',
  'Nicodemus', 'Stephen', 'Barnabas', 'Silas', 'Apollos', 'Cornelius', 'Gamaliel', 'Eutychus',
  'Demas', 'Onesimus', 'Philemon', 'Timothy', 'Titus', 'Felix', 'Festus', 'Caiaphas', 'Annas',
  'Malchus', 'Tubal-Cain', 'Jubal', 'Lahmi', 'Melchizedek', 'Eliezer', 'Ananias', 'Nun',
  'Shem', 'Goliath',
);
const CITIES = SET(
  'Bethlehem', 'Nazareth', 'Jerusalem', 'Jericho', 'Capernaum', 'Cana', 'Bethel', 'Hebron',
  'Bethany', 'Nain', 'Sychar', 'Damascus', 'Antioch', 'Tarsus', 'Ephesus', 'Smyrna', 'Philadelphia',
  'Laodicea', 'Athens', 'Corinth', 'Rome', 'Babylon', 'Babel', 'Nineveh', 'Ur', 'Haran', 'Sodom',
  'Gomorrah', 'Joppa', 'Gath', 'Shiloh', 'Gibeon', 'Ai', 'Emmaus', 'Bethsaida', 'Tyre', 'Sidon',
  'Magdala', 'Susa', 'Zarephath', 'Shunem', 'Shechem', 'Gilgal', 'Mizpah', 'Ramah', 'Megiddo',
  'Hazor', 'Lachish', 'Caesarea', 'Derbe', 'Lystra', 'Iconium', 'Berea', 'Thessalonica',
  'Colossae', 'Philippi', 'Miletus', 'Troas', 'Jezreel', 'Endor', 'Ziklag', 'Hebron',
);
const REGIONS_PL = SET(
  'Egypt', 'Israel', 'Judah', 'Judea', 'Moab', 'Midian', 'Canaan', 'Assyria', 'Goshen',
  'Edom', 'Samaria', 'Macedonia', 'Syria', 'Babylonia', 'Philistia',
);
const WATERS = SET(
  'Jordan', 'Red Sea', 'Dead', 'Red', 'Nile', 'Euphrates', 'Tigris', 'Jabbok', 'Kishon', 'Chebar',
  'Cherith', 'Kidron', 'Dead Sea', 'Galilee',
);
const MOUNTAINS = SET(
  'Sinai', 'Mount Sinai', 'Horeb', 'Carmel', 'Nebo', 'Mount Nebo', 'Ararat', 'Moriah', 'Hor',
  'Tabor', 'Gilboa', 'Zion', 'Olives', 'Mount of Olives', 'Pisgah', 'Ebal', 'Gerizim', 'Hermon',
);
const ISLANDS = SET('Patmos', 'Malta', 'Cyprus', 'Crete');
const PEOPLES = SET(
  'Philistines', 'Gibeonites', 'Samaritans', 'Pharisees', 'Sadducees', 'Nazirites', 'Egyptians',
  'Amalekites', 'Moabites', 'Edomites', 'Canaanites', 'Assyrians', 'Babylonians', 'Levites', 'Jews',
);
const ANIMALS = SET(
  'Donkey', 'Dove', 'Lion', 'Ram', 'Serpent', 'Snake', 'Lamb', 'Goat', 'Pig', 'Pigs', 'Camel',
  'Camels', 'Bear', 'Bears', 'Raven', 'Ravens', 'Fish', 'Frogs', 'Locusts', 'Gnats', 'Worm',
  'Worms', 'Cows', 'Sheep', 'Rooster', 'Viper', 'Quail', 'Calf', 'Calves',
);
const BOOKS = SET(
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua', 'Judges', 'Ruth', 'Samuel',
  'Kings', 'Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs', 'Ecclesiastes',
  'Song of Songs', 'Lamentations', 'Acts', 'Romans', 'Corinthians', 'Galatians', 'Ephesians',
  'Philippians', 'Colossians', 'Thessalonians', 'Hebrews', 'James', 'Jude', 'Revelation',
  'Pentateuch', 'Torah',
);

// grobe Klasse (für Fallback, wie zuvor)
function coarseOf(item) {
  const tags = item.categories.map((t) => t.toLowerCase());
  if (tags.includes('number') || /^\d/.test(item.a.trim())) return 'number';
  if (tags.includes('place')) return 'place';
  if (tags.includes('verse')) return 'verse';
  if (tags.includes('person')) return 'person';
  return 'misc';
}

// feine Klasse für typgleiche Ablenker
const stripArticle = (s) => s.replace(/^(a|an|the)\s+/i, '');
function fineOf(item) {
  const a = stripArticle(norm(item.a));
  const coarse = coarseOf(item);
  if (coarse === 'number') return 'number';
  if (coarse === 'verse') return 'verse';
  if (coarse === 'place') {
    if (WATERS.has(a)) return 'pl_water';
    if (CITIES.has(a)) return 'pl_city';
    if (MOUNTAINS.has(a)) return 'pl_mountain';
    if (ISLANDS.has(a)) return 'pl_island';
    if (REGIONS_PL.has(a)) return 'pl_region';
    return 'place'; // mehrdeutig -> alle Orte
  }
  if (coarse === 'person') {
    if (WOMEN.has(a)) return 'p_women';
    if (KINGS.has(a)) return 'p_king';
    if (PROPHETS.has(a)) return 'p_prophet';
    if (APOSTLES.has(a)) return 'p_apostle';
    if (MEN.has(a)) return 'p_man';
    if (PEOPLES.has(a)) return 'people';
    return 'person'; // sonstige Person
  }
  // misc: Tiere/Bücher/Objekte/Begriffe
  if (ANIMALS.has(a)) return 'animal';
  if (PEOPLES.has(a)) return 'people';
  if (BOOKS.has(a)) return 'book';
  return 'misc';
}

const LEVEL = { easy: 1, medium: 2, hard: 3 };

export function buildPack(rawQuestions, { seed = 20260606 } = {}) {
  // dedup nach (Frage+Antwort)
  const seen = new Set();
  const items = [];
  for (const it of rawQuestions) {
    // korrekte Antwort: aus `a` ODER aus options[answerIndex]
    const correct = (
      it.a ??
      (Array.isArray(it.options) && Number.isInteger(it.answerIndex) ? it.options[it.answerIndex] : '')
    )
      .toString()
      .trim();
    const key = (it.q.trim() + '||' + correct).toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    items.push({
      q: it.q.trim(),
      a: correct,
      categories: it.categories || [],
      level: it.level,
      // mitgelieferte Optionen übernehmen (sonst werden Ablenker generiert)
      options: Array.isArray(it.options) ? it.options.map((s) => String(s).trim()) : null,
    });
  }

  // Ablenker-Töpfe füllen: fein (typgleich) + grob (Fallback)
  const finePools = {};
  const coarsePools = {};
  for (const it of items) {
    const fk = fineOf(it);
    const ck = coarseOf(it);
    (finePools[fk] ||= new Set()).add(it.a);
    (coarsePools[ck] ||= new Set()).add(it.a);
  }
  const fineArr = Object.fromEntries(Object.entries(finePools).map(([k, v]) => [k, [...v]]));
  const coarseArr = Object.fromEntries(Object.entries(coarsePools).map(([k, v]) => [k, [...v]]));
  const allAnswers = [...new Set(items.map((i) => i.a))];

  const rand = rng(seed);
  const regionCounts = {};
  const questions = items.map((it, i) => {
    const correct = it.a;
    let options;
    if (it.options && it.options.length >= 2) {
      // gelieferte Ablenker verwenden (Reihenfolge wird gemischt, korrekt per Text erkannt)
      options = shuffle(it.options, rand);
    } else {
      const lc = correct.toLowerCase();
      const fk = fineOf(it);
      const ck = coarseOf(it);
      // 1) typgleiche (feine) Ablenker
      let cand = (fineArr[fk] || []).filter((x) => x.toLowerCase() !== lc);
      // 2) Fallback: grobe Klasse (Person/Ort/Zahl/Vers/Misc)
      if (cand.length < 3) {
        cand = [...new Set([...cand, ...(coarseArr[ck] || []).filter((x) => x.toLowerCase() !== lc)])];
      }
      // 3) Fallback: alle Antworten
      if (cand.length < 3) {
        cand = [...new Set([...cand, ...allAnswers.filter((x) => x.toLowerCase() !== lc)])];
      }
      const distractors = shuffle(cand, rand).slice(0, 3);
      options = shuffle([correct, ...distractors], rand);
    }
    const regions = regionsOf(it.categories);
    for (const r of regions) regionCounts[r] = (regionCounts[r] || 0) + 1;
    return {
      id: 'en-' + String(i + 1).padStart(4, '0'),
      categories: regions, // Regionen (für die App)
      tags: it.categories, // Roh-Tags (für DB)
      difficulty: LEVEL[it.level] || 2,
      question: it.q,
      options,
      answer: correct,
    };
  });

  const categories = REGIONS.filter((r) => regionCounts[r.slug]).map((r) => ({
    slug: r.slug,
    name: r.name,
    count: regionCounts[r.slug],
  }));

  return { version: 2, lang: 'en', categories, questions };
}
