import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { DIFFICULTY_LABELS, type QuestionRow, type Status } from '../lib/types'

const STATUSES: (Status | 'all')[] = ['all', 'pending', 'approved', 'rejected', 'draft']

export default function Questions({ onEdit }: { onEdit: (id: string | null) => void }) {
  const [rows, setRows] = useState<QuestionRow[]>([])
  const [filter, setFilter] = useState<Status | 'all'>('all')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  async function load() {
    setLoading(true)
    setError('')
    let query = supabase
      .from('questions')
      .select(
        'id,status,difficulty,bible_reference,question_translations(lang,prompt),question_categories(categories(slug))',
      )
      .order('created_at', { ascending: false })
      .limit(500)
    if (filter !== 'all') query = query.eq('status', filter)
    const { data, error } = await query
    if (error) setError(error.message)
    else setRows((data as unknown as QuestionRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter])

  function promptOf(r: QuestionRow) {
    const en = r.question_translations?.find((t) => t.lang === 'en')
    return en?.prompt ?? r.question_translations?.[0]?.prompt ?? '(no text)'
  }

  function catsOf(r: QuestionRow) {
    const slugs = (r.question_categories ?? [])
      .map((qc) => qc.categories?.slug)
      .filter(Boolean) as string[]
    return slugs.slice(0, 3).join(', ') + (slugs.length > 3 ? ' …' : '')
  }

  return (
    <div className="container">
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <h2>Questions</h2>
        <button className="primary" onClick={() => onEdit(null)}>
          + New question
        </button>
      </div>
      <div className="row lang-tabs" style={{ margin: '8px 0 16px' }}>
        {STATUSES.map((s) => (
          <button
            key={s}
            className={filter === s ? 'active' : ''}
            onClick={() => setFilter(s)}
          >
            {s}
          </button>
        ))}
      </div>
      {error && <div className="err">{error}</div>}
      {loading ? (
        <div className="muted">Loading…</div>
      ) : rows.length === 0 ? (
        <div className="muted">No questions.</div>
      ) : (
        rows.map((r) => (
          <div key={r.id} className="qitem" onClick={() => onEdit(r.id)}>
            <span className="prompt">{promptOf(r)}</span>
            <span className="muted">{catsOf(r) || '—'}</span>
            <span className="pill">{DIFFICULTY_LABELS[r.difficulty] ?? r.difficulty}</span>
            <span className={`pill ${r.status}`}>{r.status}</span>
          </div>
        ))
      )}
    </div>
  )
}
