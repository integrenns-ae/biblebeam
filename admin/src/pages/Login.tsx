import { useState } from 'react'
import { supabase, isConfigured } from '../lib/supabase'

export default function Login() {
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')
  const [busy, setBusy] = useState(false)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setInfo('')
    setBusy(true)
    try {
      if (mode === 'signup') {
        const { error } = await supabase.auth.signUp({ email, password })
        if (error) throw error
        setInfo('Account created. Check your email if confirmation is required, then sign in.')
        setMode('signin')
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email, password })
        if (error) throw error
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="center">
      <div className="card loginbox">
        <h2 style={{ color: 'var(--gold)', marginTop: 0 }}>Lichtpfad · Admin</h2>
        {!isConfigured && (
          <div className="banner">
            Supabase not configured. Create <code>admin/.env</code> from{' '}
            <code>.env.example</code> with your project URL & anon key.
          </div>
        )}
        <form onSubmit={submit}>
          <label>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoComplete="email"
          />
          <label>Password</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            autoComplete="current-password"
          />
          <div className="row" style={{ marginTop: 16, justifyContent: 'space-between' }}>
            <button type="submit" className="primary" disabled={busy}>
              {mode === 'signin' ? 'Sign in' : 'Sign up'}
            </button>
            <button
              type="button"
              className="ghost"
              onClick={() => setMode(mode === 'signin' ? 'signup' : 'signin')}
            >
              {mode === 'signin' ? 'Need an account?' : 'Have an account?'}
            </button>
          </div>
          {error && <div className="err">{error}</div>}
          {info && <div className="muted" style={{ marginTop: 8 }}>{info}</div>}
        </form>
      </div>
    </div>
  )
}
