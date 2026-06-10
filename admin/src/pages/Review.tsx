import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { QuestionRow } from '../lib/types'

export default function Review({ onEdit }: { onEdit: (id: string) => void }) {
  const [rows, setRows] = useState<QuestionRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  async function load() {
    setLoading(true)
    setError('')
    const { data, error } = await supabase
      .from('questions')
      .select('id,status,difficulty,bible_reference,question_translations(lang,prompt),question_categories(categories(slug))')
      .eq('status', 'pending')
      .order('created_at', { ascending: true })
    if (error) setError(error.message)
    else setRows((data as unknown as QuestionRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    load()
  }, [])

  async function decide(id: string, status: 'approved' | 'rejected') {
    const { data: userRes } = await supabase.auth.getUser()
    const { error } = await supabase
      .from('questions')
      .update({ status, reviewed_by: userRes.user?.id })
      .eq('id', id)
    if (error) setError(error.message)
    else setRows((rs) => rs.filter((r) => r.id !== id))
  }

  function promptOf(r: QuestionRow) {
    return r.question_translations?.find((t) => t.lang === 'en')?.prompt ?? '(no text)'
  }

  return (
    <div className="container">
      <h2>Review queue</h2>
      <p className="muted">User submissions awaiting approval.</p>
      {error && <div className="err">{error}</div>}
      {loading ? (
        <div className="muted">Loading…</div>
      ) : rows.length === 0 ? (
        <div className="muted">Nothing pending. 🎉</div>
      ) : (
        rows.map((r) => (
          <div key={r.id} className="card">
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <strong style={{ flex: 1 }}>{promptOf(r)}</strong>
              <span className="muted">
                {(r.question_categories ?? [])
                  .map((qc) => qc.categories?.slug)
                  .filter(Boolean)
                  .join(', ') || '—'}
              </span>
            </div>
            <div className="row" style={{ marginTop: 12 }}>
              <button className="primary" onClick={() => decide(r.id, 'approved')}>
                ✓ Approve
              </button>
              <button className="danger" onClick={() => decide(r.id, 'rejected')}>
                ✕ Reject
              </button>
              <button className="ghost" onClick={() => onEdit(r.id)}>
                Edit first
              </button>
            </div>
          </div>
        ))
      )}
    </div>
  )
}
