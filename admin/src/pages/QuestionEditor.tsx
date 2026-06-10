import { useEffect, useMemo, useState } from 'react'
import { supabase, LANGS } from '../lib/supabase'
import type { Lang } from '../lib/supabase'
import { emptyQuestion, type Category, type QuestionForm, type Status } from '../lib/types'

const STATUSES: Status[] = ['draft', 'pending', 'approved', 'rejected']
const DIFFICULTIES: [number, string][] = [
  [1, 'Easy'],
  [2, 'Medium'],
  [3, 'Hard'],
]
const KIND_ORDER = ['testament', 'type', 'book']
const KIND_LABEL: Record<string, string> = {
  testament: 'Testament',
  type: 'Type',
  book: 'Book',
}

export default function QuestionEditor({
  id,
  onDone,
}: {
  id: string | null
  onDone: () => void
}) {
  const [form, setForm] = useState<QuestionForm>(emptyQuestion())
  const [cats, setCats] = useState<Category[]>([])
  const [lang, setLang] = useState<Lang>('en')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    ;(async () => {
      setLoading(true)
      const { data: catData } = await supabase
        .from('categories')
        .select('id,slug,kind,sort')
        .order('kind')
        .order('sort')
      setCats((catData as Category[]) ?? [])
      if (id) {
        const { data, error } = await supabase
          .from('questions')
          .select(
            'id,difficulty,bible_reference,status,' +
              'question_translations(lang,prompt,explanation),' +
              'answer_options(id,is_correct,sort,answer_option_translations(lang,text)),' +
              'question_categories(category_id)',
          )
          .eq('id', id)
          .single()
        if (error) setError(error.message)
        else if (data) setForm(toForm(data as unknown as Record<string, unknown>))
      }
      setLoading(false)
    })()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id])

  const groups = useMemo(() => {
    const byKind: Record<string, Category[]> = {}
    for (const c of cats) {
      const k = c.kind ?? 'book'
      ;(byKind[k] ??= []).push(c)
    }
    return KIND_ORDER.filter((k) => byKind[k]?.length).map((k) => ({ kind: k, items: byKind[k] }))
  }, [cats])

  function set<K extends keyof QuestionForm>(k: K, v: QuestionForm[K]) {
    setForm((f) => ({ ...f, [k]: v }))
  }
  function setLangField(field: 'prompt' | 'explanation', value: string) {
    setForm((f) => ({ ...f, [field]: { ...f[field], [lang]: value } }))
  }
  function setOption(i: number, value: string) {
    setForm((f) => ({
      ...f,
      options: f.options.map((o, idx) =>
        idx === i ? { ...o, text: { ...o.text, [lang]: value } } : o,
      ),
    }))
  }
  function setCorrect(i: number) {
    setForm((f) => ({
      ...f,
      options: f.options.map((o, idx) => ({ ...o, is_correct: idx === i })),
    }))
  }
  function addOption() {
    setForm((f) =>
      f.options.length >= 6
        ? f
        : { ...f, options: [...f.options, { is_correct: false, text: { en: '', de: '', ru: '' } }] },
    )
  }
  function removeOption(i: number) {
    setForm((f) => {
      if (f.options.length <= 2) return f
      const removingCorrect = f.options[i].is_correct
      let options = f.options.filter((_, idx) => idx !== i)
      if (removingCorrect && !options.some((o) => o.is_correct))
        options = options.map((o, idx) => ({ ...o, is_correct: idx === 0 }))
      return { ...f, options }
    })
  }
  function toggleCat(cid: string) {
    setForm((f) => ({
      ...f,
      categoryIds: f.categoryIds.includes(cid)
        ? f.categoryIds.filter((x) => x !== cid)
        : [...f.categoryIds, cid],
    }))
  }

  async function save() {
    setError('')
    if (!form.prompt.en.trim()) return setError('English prompt is required.')
    if (!form.options.some((o) => o.is_correct)) return setError('Mark one option correct.')
    if (form.options.filter((o) => o.text.en.trim()).length < 2)
      return setError('At least two options (English) required.')
    setSaving(true)
    try {
      const { data: userRes } = await supabase.auth.getUser()
      const uid = userRes.user?.id

      let qid = form.id
      if (qid) {
        const { error } = await supabase
          .from('questions')
          .update({
            difficulty: form.difficulty,
            bible_reference: form.bible_reference || null,
            status: form.status,
          })
          .eq('id', qid)
        if (error) throw error
      } else {
        const { data, error } = await supabase
          .from('questions')
          .insert({
            difficulty: form.difficulty,
            bible_reference: form.bible_reference || null,
            status: form.status,
            created_by: uid,
            source: 'admin',
          })
          .select('id')
          .single()
        if (error) throw error
        qid = data!.id
      }

      // Übersetzungen
      const trRows = LANGS.filter((l) => form.prompt[l].trim()).map((l) => ({
        question_id: qid,
        lang: l,
        prompt: form.prompt[l].trim(),
        explanation: form.explanation[l].trim() || null,
      }))
      if (trRows.length) {
        const { error } = await supabase
          .from('question_translations')
          .upsert(trRows, { onConflict: 'question_id,lang' })
        if (error) throw error
      }

      // Kategorien (n:m): ersetzen
      await supabase.from('question_categories').delete().eq('question_id', qid)
      if (form.categoryIds.length) {
        const { error } = await supabase
          .from('question_categories')
          .insert(form.categoryIds.map((cid) => ({ question_id: qid, category_id: cid })))
        if (error) throw error
      }

      // Optionen: ersetzen
      const { error: delErr } = await supabase.from('answer_options').delete().eq('question_id', qid)
      if (delErr) throw delErr
      const validOpts = form.options.filter((o) => o.text.en.trim())
      for (let i = 0; i < validOpts.length; i++) {
        const o = validOpts[i]
        const { data: optRow, error: optErr } = await supabase
          .from('answer_options')
          .insert({ question_id: qid, is_correct: o.is_correct, sort: i })
          .select('id')
          .single()
        if (optErr) throw optErr
        const optTr = LANGS.filter((l) => o.text[l].trim()).map((l) => ({
          option_id: optRow!.id,
          lang: l,
          text: o.text[l].trim(),
        }))
        if (optTr.length) {
          const { error } = await supabase.from('answer_option_translations').insert(optTr)
          if (error) throw error
        }
      }
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <div className="container muted">Loading…</div>

  return (
    <div className="container">
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <h2>{id ? 'Edit question' : 'New question'}</h2>
        <button className="ghost" onClick={onDone}>
          ← Back
        </button>
      </div>

      <div className="row lang-tabs" style={{ margin: '8px 0 4px' }}>
        {LANGS.map((l) => (
          <button key={l} className={lang === l ? 'active' : ''} onClick={() => setLang(l)}>
            {l.toUpperCase()}
            {l !== 'en' && !form.prompt[l].trim() ? ' ·' : ''}
          </button>
        ))}
      </div>

      <div className="card">
        <label>Prompt ({lang.toUpperCase()}){lang === 'en' ? ' *' : ''}</label>
        <textarea value={form.prompt[lang]} onChange={(e) => setLangField('prompt', e.target.value)} />
        <label>Explanation ({lang.toUpperCase()}) — optional</label>
        <textarea
          value={form.explanation[lang]}
          onChange={(e) => setLangField('explanation', e.target.value)}
        />
      </div>

      <div className="card">
        <label>Answer options ({lang.toUpperCase()}) — select the correct one</label>
        {form.options.map((o, i) => (
          <div className="row" key={i} style={{ marginBottom: 8 }}>
            <input
              type="radio"
              name="correct"
              className="opt-correct"
              checked={o.is_correct}
              onChange={() => setCorrect(i)}
              style={{ width: 20 }}
              title="Mark as correct"
            />
            <input
              style={{ flex: 1 }}
              value={o.text[lang]}
              placeholder={`Option ${i + 1}${o.is_correct ? ' (correct)' : ''}`}
              onChange={(e) => setOption(i, e.target.value)}
            />
            <button
              type="button"
              className="ghost"
              title="Remove option"
              onClick={() => removeOption(i)}
              disabled={form.options.length <= 2}
              style={{ padding: '6px 12px' }}
            >
              ✕
            </button>
          </div>
        ))}
        <button
          type="button"
          className="ghost"
          onClick={addOption}
          disabled={form.options.length >= 6}
          style={{ marginTop: 4 }}
        >
          + Add option
        </button>
      </div>

      <div className="card">
        <div className="row">
          <div style={{ width: 180 }}>
            <label>Difficulty</label>
            <select
              value={form.difficulty}
              onChange={(e) => set('difficulty', Number(e.target.value))}
            >
              {DIFFICULTIES.map(([v, l]) => (
                <option key={v} value={v}>
                  {l}
                </option>
              ))}
            </select>
          </div>
          <div style={{ width: 180 }}>
            <label>Status</label>
            <select value={form.status} onChange={(e) => set('status', e.target.value as Status)}>
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
        </div>
        <label>Bible reference</label>
        <input
          value={form.bible_reference}
          placeholder="e.g. John 3:16"
          onChange={(e) => set('bible_reference', e.target.value)}
        />
      </div>

      <div className="card">
        <label>Categories / tags ({form.categoryIds.length} selected)</label>
        {groups.map((g) => (
          <div key={g.kind} style={{ marginBottom: 12 }}>
            <div className="muted" style={{ marginBottom: 6 }}>
              {KIND_LABEL[g.kind] ?? g.kind}
            </div>
            <div className="row" style={{ gap: 6 }}>
              {g.items.map((c) => {
                const on = form.categoryIds.includes(c.id)
                return (
                  <button
                    key={c.id}
                    type="button"
                    onClick={() => toggleCat(c.id)}
                    className={on ? '' : 'ghost'}
                    style={{
                      padding: '4px 12px',
                      fontSize: 13,
                      background: on ? 'var(--gold)' : undefined,
                      color: on ? 'var(--night-deep)' : undefined,
                      borderColor: on ? 'var(--gold)' : undefined,
                    }}
                  >
                    {c.slug}
                  </button>
                )
              })}
            </div>
          </div>
        ))}
      </div>

      {error && <div className="err">{error}</div>}
      <div className="row" style={{ marginTop: 12 }}>
        <button className="primary" onClick={save} disabled={saving}>
          {saving ? 'Saving…' : 'Save'}
        </button>
      </div>
    </div>
  )
}

function toForm(data: Record<string, unknown>): QuestionForm {
  const f = emptyQuestion()
  f.id = data.id as string
  f.difficulty = (data.difficulty as number) ?? 2
  f.bible_reference = (data.bible_reference as string) ?? ''
  f.status = (data.status as Status) ?? 'pending'
  f.categoryIds = ((data.question_categories as { category_id: string }[]) ?? []).map(
    (qc) => qc.category_id,
  )
  for (const t of (data.question_translations as {
    lang: string
    prompt: string
    explanation: string | null
  }[]) ?? []) {
    if (t.lang in f.prompt) {
      f.prompt[t.lang as Lang] = t.prompt ?? ''
      f.explanation[t.lang as Lang] = t.explanation ?? ''
    }
  }
  const opts = ((data.answer_options as {
    id: string
    is_correct: boolean
    sort: number
    answer_option_translations: { lang: string; text: string }[]
  }[]) ?? []).sort((a, b) => a.sort - b.sort)
  if (opts.length) {
    f.options = opts.map((o) => {
      const text = { en: '', de: '', ru: '' }
      for (const tr of o.answer_option_translations ?? []) {
        if (tr.lang in text) text[tr.lang as Lang] = tr.text
      }
      return { id: o.id, is_correct: o.is_correct, text }
    })
  }
  return f
}
