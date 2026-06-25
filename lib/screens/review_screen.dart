import 'package:flutter/material.dart';

import '../data/review_repository.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';

class ReviewScreen extends StatefulWidget {
  /// Serverseitig geprüfter Zugangscode (vom Settings-Gate übergeben).
  final String code;
  const ReviewScreen({super.key, required this.code});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _repo = ReviewRepository();
  // Review läuft standardmäßig auf Deutsch (Umschalter auf EN bleibt verfügbar).
  String _lang = 'de';
  String? _category; // null = alle
  List<({String slug, String? kind})> _cats = [];
  List<ReviewQuestion> _questions = [];
  int _index = 0;
  bool _loadingList = false;
  // Code wurde im Settings-Gate bereits serverseitig geprüft; die RPC prüft
  // ihn beim Speichern erneut.
  final bool _canSave = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Standard: Deutsch (Umschalter erlaubt EN bei Bedarf).
    _lang = 'de';
    _repo.fetchCategories().then((c) {
      if (mounted) setState(() => _cats = c);
    }).catchError((_) {});
  }

  Future<void> _load() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final qs = await _repo.fetchQuestions(categorySlug: _category, lang: _lang);
      setState(() {
        _questions = qs;
        _index = 0;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingList = false);
    }
  }

  Future<void> _save(ReviewQuestion q) async {
    try {
      await _repo.saveQuestion(q, _lang, widget.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('saved')), duration: const Duration(milliseconds: 900)),
      );
      _advance();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _advance() {
    if (_index + 1 < _questions.length) {
      setState(() => _index++);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('reviewDone'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.cream),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(tr('reviewMode'),
                        style: AppTheme.ui(19, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                _controls(),
                const SizedBox(height: 12),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Sprache
        ...['de', 'en'].map((l) {
          final sel = _lang == l;
          return GestureDetector(
            onTap: () => setState(() => _lang = l),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.gold : AppColors.cardBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: sel ? AppColors.gold : AppColors.cardBorder),
              ),
              child: Text(l.toUpperCase(),
                  style: AppTheme.ui(13,
                      w: FontWeight.w700,
                      c: sel ? AppColors.nightDeep : AppColors.cream)),
            ),
          );
        }),
        // Kategorie
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: DropdownButton<String?>(
            value: _category,
            dropdownColor: AppColors.cardBg,
            underline: const SizedBox.shrink(),
            iconEnabledColor: AppColors.gold,
            style: AppTheme.ui(13, c: AppColors.cream),
            items: [
              DropdownMenuItem(value: null, child: Text(tr('mixed'))),
              ..._cats.map((c) => DropdownMenuItem(
                  value: c.slug, child: Text('${c.kind ?? ''} · ${c.slug}'))),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
        ),
        ElevatedButton(
          onPressed: _loadingList ? null : _load,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.nightDeep,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(tr('load'), style: AppTheme.ui(13, w: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: AppTheme.ui(13, c: AppColors.wrong)));
    }
    if (_questions.isEmpty) {
      return Center(
          child: Text(tr('load'), style: AppTheme.ui(14, c: AppColors.creamDim)));
    }
    final q = _questions[_index];
    return Column(
      children: [
        Text('${_index + 1} / ${_questions.length}   ·   ${q.id}',
            style: AppTheme.ui(12, c: AppColors.creamDim)),
        const SizedBox(height: 8),
        Expanded(
          child: _QuestionEditor(
            key: ValueKey(q.id),
            question: q,
            canSave: _canSave,
            onSave: _save,
            onSkip: _advance,
          ),
        ),
      ],
    );
  }
}

class _QuestionEditor extends StatefulWidget {
  final ReviewQuestion question;
  final bool canSave;
  final Future<void> Function(ReviewQuestion) onSave;
  final VoidCallback onSkip;
  const _QuestionEditor({
    super.key,
    required this.question,
    required this.canSave,
    required this.onSave,
    required this.onSkip,
  });

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final TextEditingController _prompt;
  late final List<TextEditingController> _opts;
  late int _correct;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prompt = TextEditingController(text: widget.question.prompt);
    _opts = widget.question.options
        .map((o) => TextEditingController(text: o.text))
        .toList();
    _correct = widget.question.options.indexWhere((o) => o.isCorrect);
    if (_correct < 0) _correct = 0;
  }

  @override
  void dispose() {
    _prompt.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final q = widget.question;
    q.prompt = _prompt.text;
    for (var i = 0; i < q.options.length; i++) {
      q.options[i].text = _opts[i].text;
      q.options[i].isCorrect = i == _correct;
    }
    setState(() => _saving = true);
    await widget.onSave(q);
    if (mounted) setState(() => _saving = false);
  }

  InputDecoration _dec() => InputDecoration(
        filled: true,
        fillColor: AppColors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              Text(tr('reviewMode'),
                  style: AppTheme.ui(12, c: AppColors.creamDim)),
              const SizedBox(height: 6),
              TextField(
                controller: _prompt,
                style: AppTheme.ui(17, w: FontWeight.w600),
                maxLines: null,
                decoration: _dec(),
              ),
              const SizedBox(height: 14),
              Text(tr('markCorrectHint'),
                  style: AppTheme.ui(11, c: AppColors.creamDim)),
              const SizedBox(height: 8),
              ...List.generate(_opts.length, (i) {
                final correct = i == _correct;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _correct = i),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: correct ? AppColors.gold : Colors.transparent,
                            border: Border.all(
                                color: correct ? AppColors.gold : AppColors.cardBorder,
                                width: 2),
                          ),
                          child: correct
                              ? const Icon(Icons.check,
                                  size: 18, color: AppColors.nightDeep)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _opts[i],
                          style: AppTheme.ui(15,
                              c: correct ? AppColors.goldBright : AppColors.cream),
                          decoration: _dec(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : widget.onSkip,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                ),
                child: Text(tr('skip'),
                    style: AppTheme.ui(14, w: FontWeight.w600, c: AppColors.cream)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (!widget.canSave || _saving) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.nightDeep,
                  disabledBackgroundColor: AppColors.cardBorder,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                ),
                child: Text(_saving ? '…' : tr('saveNext'),
                    style: AppTheme.ui(15, w: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
