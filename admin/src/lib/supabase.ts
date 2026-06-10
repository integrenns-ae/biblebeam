import { createClient } from '@supabase/supabase-js'

// Konfiguration aus .env (siehe .env.example). Fällt auf Platzhalter zurück,
// damit die UI auch ohne Konfiguration rendert (Login schlägt dann fehl).
const url = import.meta.env.VITE_SUPABASE_URL || 'http://localhost:54321'
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'public-anon-placeholder'

export const isConfigured = Boolean(
  import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY,
)

export const supabase = createClient(url, anonKey)

export const LANGS = ['en', 'de', 'ru'] as const
export type Lang = (typeof LANGS)[number]
