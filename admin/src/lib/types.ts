export type Status = 'draft' | 'pending' | 'approved' | 'rejected'

export interface Category {
  id: string
  slug: string
  kind: string | null // 'testament' | 'book' | 'type'
  sort: number
}

export interface OptionForm {
  id?: string
  is_correct: boolean
  text: { en: string; de: string; ru: string }
}

export interface QuestionForm {
  id?: string
  categoryIds: string[]
  difficulty: number // 1=easy, 2=medium, 3=hard
  bible_reference: string
  status: Status
  prompt: { en: string; de: string; ru: string }
  explanation: { en: string; de: string; ru: string }
  options: OptionForm[]
}

export interface QuestionRow {
  id: string
  status: Status
  difficulty: number
  bible_reference: string | null
  question_translations: { lang: string; prompt: string }[]
  question_categories: { categories: { slug: string } | null }[]
}

export const DIFFICULTY_LABELS: Record<number, string> = {
  1: 'Easy',
  2: 'Medium',
  3: 'Hard',
}

export function emptyQuestion(): QuestionForm {
  return {
    categoryIds: [],
    difficulty: 2,
    bible_reference: '',
    status: 'pending',
    prompt: { en: '', de: '', ru: '' },
    explanation: { en: '', de: '', ru: '' },
    options: [
      { is_correct: true, text: { en: '', de: '', ru: '' } },
      { is_correct: false, text: { en: '', de: '', ru: '' } },
      { is_correct: false, text: { en: '', de: '', ru: '' } },
      { is_correct: false, text: { en: '', de: '', ru: '' } },
    ],
  }
}
