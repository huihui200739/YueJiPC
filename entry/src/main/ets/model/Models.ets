export type DocumentKind = 'PDF' | 'WEB';
export type EvidenceKind = 'HIGHLIGHT' | 'UNDERLINE' | 'QUOTE';
export type ReviewStatus = 'TO_REVIEW' | 'MASTERED';
export type MainView = 'LIBRARY' | 'READER' | 'REVIEW';

export const MAX_TITLE_LENGTH: number = 160;
export const MAX_URL_LENGTH: number = 2048;
export const MAX_EXCERPT_LENGTH: number = 20000;
export const MAX_NOTE_LENGTH: number = 8000;
export const MAX_TAGS_LENGTH: number = 500;
export const MAX_QUOTE_LENGTH: number = 20000;
export const MAX_SEARCH_LENGTH: number = 200;

export interface DocumentRecord {
  id: string;
  kind: DocumentKind;
  title: string;
  source: string;
  pageCount: number;
  currentPage: number;
  tags: string;
  favorite: boolean;
  excerpt: string;
  note: string;
  createdAt: number;
  lastReadAt: number;
}

export interface EvidenceCard {
  id: string;
  documentId: string;
  quote: string;
  pageIndex: number;
  rectsJson: string;
  note: string;
  kind: EvidenceKind;
  color: number;
  tags: string;
  reviewStatus: ReviewStatus;
  createdAt: number;
  updatedAt: number;
}

export interface AppSettings {
  darkMode: boolean;
  focusMode: boolean;
  leftSidebarOpen: boolean;
  rightSidebarOpen: boolean;
  defaultHighlightColor: number;
}

export interface StoredPdfRect {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface StoredSelection {
  pageIndex: number;
  isRotated: number;
  rectArray: StoredPdfRect[];
}

export function createId(prefix: string): string {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 100000)}`;
}

export function tagList(tags: string): string[] {
  return tags
    .split(',')
    .map((tag: string): string => tag.trim())
    .filter((tag: string): boolean => tag.length > 0);
}

export function normalizeTags(tags: string): string {
  const values: string[] = [];
  const normalizedValues: string[] = [];
  tagList(tags).forEach((tag: string): void => {
    const normalized = tag.toLowerCase();
    if (!normalizedValues.includes(normalized)) {
      values.push(tag);
      normalizedValues.push(normalized);
    }
  });
  return values.join(', ');
}
