import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'
import Login from './pages/Login'
import Questions from './pages/Questions'
import QuestionEditor from './pages/QuestionEditor'
import Review from './pages/Review'

type View = 'questions' | 'review' | 'editor'

export default function App() {
  const [session, setSession] = useState<Session | null>(null)
  const [ready, setReady] = useState(false)
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null)
  const [view, setView] = useState<View>('questions')
  const [editId, setEditId] = useState<string | null>(null)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setReady(true)
    })
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => sub.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!session) {
      setIsAdmin(null)
      return
    }
    supabase
      .from('profiles')
      .select('role')
      .eq('id', session.user.id)
      .single()
      .then(({ data }) => setIsAdmin(data?.role === 'admin'))
  }, [session])

  if (!ready) return <div className="center muted">Loading…</div>
  if (!session) return <Login />

  function openEditor(id: string | null) {
    setEditId(id)
    setView('editor')
  }

  return (
    <>
      <div className="topbar">
        <span className="brand">LICHTPFAD · ADMIN</span>
        <button
          className={`nav ${view === 'questions' ? 'active' : ''}`}
          onClick={() => setView('questions')}
        >
          Questions
        </button>
        <button
          className={`nav ${view === 'review' ? 'active' : ''}`}
          onClick={() => setView('review')}
        >
          Review
        </button>
        <span className="spacer" />
        <span className="muted">{session.user.email}</span>
        <button className="ghost" onClick={() => supabase.auth.signOut()}>
          Sign out
        </button>
      </div>

      {isAdmin === false && (
        <div className="container">
          <div className="banner">
            Your account is not an admin. You can browse, but saving/approving needs the{' '}
            <code>admin</code> role. Set it in Supabase:{' '}
            <code>update public.profiles set role='admin' where id='{session.user.id}';</code>
          </div>
        </div>
      )}

      {view === 'questions' && <Questions onEdit={openEditor} />}
      {view === 'review' && <Review onEdit={openEditor} />}
      {view === 'editor' && (
        <QuestionEditor
          id={editId}
          onDone={() => {
            setView('questions')
          }}
        />
      )}
    </>
  )
}
