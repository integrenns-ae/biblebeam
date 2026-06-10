/// Datenmodelle für den Offline-Fragenkatalog (gebündeltes Asset).
class QuizCategory {
  final String slug;
  final String name;
  final int count;

  const QuizCategory({required this.slug, required this.name, required this.count});

  factory QuizCategory.fromJson(Map<String, dynamic> j) => QuizCategory(
        slug: j['slug'] as String,
        name: j['name'] as String,
        count: (j['count'] as num).toInt(),
      );
}

class Question {
  final String id;
  final List<String> categories; // Lichtpfad-Regionen
  final int difficulty; // 1=leicht, 2=mittel, 3=schwer
  final String question;
  final List<String> options;
  final String answer;

  const Question({
    required this.id,
    required this.categories,
    required this.difficulty,
    required this.question,
    required this.options,
    required this.answer,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        categories: (j['categories'] as List?)?.cast<String>() ?? const [],
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 2,
        question: j['question'] as String,
        options: (j['options'] as List).cast<String>(),
        answer: j['answer'] as String,
      );

  bool isCorrect(String option) => option == answer;
}

class QuestionPack {
  final int version;
  final String lang;
  final List<QuizCategory> categories;
  final List<Question> questions;

  const QuestionPack({
    required this.version,
    required this.lang,
    required this.categories,
    required this.questions,
  });

  factory QuestionPack.fromJson(Map<String, dynamic> j) => QuestionPack(
        version: (j['version'] as num).toInt(),
        lang: j['lang'] as String,
        categories: (j['categories'] as List)
            .map((e) => QuizCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        questions: (j['questions'] as List)
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  List<Question> byCategory(String slug) =>
      questions.where((q) => q.categories.contains(slug)).toList();
}
