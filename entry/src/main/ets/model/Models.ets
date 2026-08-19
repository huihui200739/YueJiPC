export type DocumentKind = 'PDF' | 'WEB';
export type EvidenceKind = 'HIGHLIGHT' | 'UNDERLINE' | 'QUOTE';
export type ReviewStatus = 'TO_REVIEW' | 'MASTERED';
export type MainView = 'LIBRARY' | 'READER' | 'REVIEW';
export type CollectionItemKind = 'DOCUMENT' | 'EVIDENCE';
export type LibraryScope = 'ALL' | 'RECENT' | 'FAVORITE';
export type ReviewFilter = 'ALL' | 'TO_REVIEW' | 'MASTERED';

export const MAX_TITLE_LENGTH: number = 160;
export const MAX_URL_LENGTH: number = 2048;
export const MAX_EXCERPT_LENGTH: number = 20000;
export const MAX_NOTE_LENGTH: number = 8000;
export const MAX_TAGS_LENGTH: number = 500;
export const MAX_QUOTE_LENGTH: number = 20000;
export const MAX_SEARCH_LENGTH: number = 200;
export const MAX_COLLECTION_NAME_LENGTH: number = 100;
export const MAX_COLLECTION_DESCRIPTION_LENGTH: number = 1000;
export const MAX_BACKUP_FILE_SIZE: number = 20 * 1024 * 1024;
export const BACKUP_SCHEMA_VERSION: number = 2;
export const LEGACY_BACKUP_SCHEMA_VERSION: number = 1;
export const DATABASE_SCHEMA_VERSION: number = 3;
export const APP_VERSION: string = '1.0.0';
export const MIN_ZOOM_PERCENT: number = 50;
export const MAX_ZOOM_PERCENT: number = 400;

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
  contentHash: string;
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
  lastReviewedAt: number;
  nextReviewAt: number;
  reviewCount: number;
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

export interface WorkspaceState {
  mainView: MainView;
  libraryScope: LibraryScope;
  reviewFilter: ReviewFilter;
  activeDocumentId: string;
  selectedCollectionId: string;
  zoomPercent: number;
  librarySearch: string;
  selectedTag: string;
  reviewSearch: string;
  reviewSelectedTag: string;
  searchText: string;
  savedAt: number;
}

export interface CollectionRecord {
  id: string;
  name: string;
  description: string;
  createdAt: number;
  updatedAt: number;
}

export interface CollectionItem {
  collectionId: string;
  itemId: string;
  itemKind: CollectionItemKind;
  createdAt: number;
}

export interface BackupPayload {
  schemaVersion: number;
  exportedAt: number;
  documents: DocumentRecord[];
  evidenceCards: EvidenceCard[];
  collections: CollectionRecord[];
  collectionItems: CollectionItem[];
  settings: AppSettings;
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

export interface EvidenceSourceValidation {
  sourceCompatible: boolean;
  selectionValid: boolean;
  pageInRange: boolean;
}

export function createId(prefix: string): string {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 100000)}`;
}

export function normalizeZoomPercent(value: number, fallback: number = 100): number {
  const safeFallback = Number.isFinite(fallback) ?
    Math.min(MAX_ZOOM_PERCENT, Math.max(MIN_ZOOM_PERCENT, Math.round(fallback))) : 100;
  return Number.isFinite(value) ?
    Math.min(MAX_ZOOM_PERCENT, Math.max(MIN_ZOOM_PERCENT, Math.round(value))) :
    safeFallback;
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

export function isDocumentKind(value: string): boolean {
  return value === 'PDF' || value === 'WEB';
}

export function isEvidenceKind(value: string): boolean {
  return value === 'HIGHLIGHT' || value === 'UNDERLINE' || value === 'QUOTE';
}

export function isReviewStatus(value: string): boolean {
  return value === 'TO_REVIEW' || value === 'MASTERED';
}

export function isCollectionItemKind(value: string): boolean {
  return value === 'DOCUMENT' || value === 'EVIDENCE';
}

export function isValidStoredSelectionJson(value: string): boolean {
  if (value.length === 0 || value.length > MAX_QUOTE_LENGTH) {
    return false;
  }
  try {
    const parsed = JSON.parse(value) as StoredSelection[];
    if (!Array.isArray(parsed) || parsed.length === 0) {
      return false;
    }
    return parsed.every((selection: StoredSelection): boolean => {
      if (!Number.isInteger(selection.pageIndex) || selection.pageIndex < 0 ||
        !Number.isFinite(selection.isRotated) ||
        !Array.isArray(selection.rectArray) || selection.rectArray.length === 0) {
        return false;
      }
      return selection.rectArray.every((rect: StoredPdfRect): boolean =>
        Number.isFinite(rect.left) &&
        Number.isFinite(rect.top) &&
        Number.isFinite(rect.right) &&
        Number.isFinite(rect.bottom) &&
        rect.right >= rect.left &&
        rect.bottom >= rect.top);
    });
  } catch (error) {
    return false;
  }
}

export function validateEvidenceSource(
  documentKind: string,
  documentPageCount: number,
  evidenceKind: string,
  pageIndex: number,
  rectsJson: string
): EvidenceSourceValidation {
  if (documentKind === 'WEB') {
    return {
      sourceCompatible: evidenceKind === 'QUOTE' && pageIndex === 0 && rectsJson === '[]',
      selectionValid: true,
      pageInRange: pageIndex === 0
    };
  }
  if (documentKind !== 'PDF') {
    return {
      sourceCompatible: false,
      selectionValid: false,
      pageInRange: false
    };
  }

  let pageInRange = Number.isInteger(pageIndex) &&
    pageIndex >= 0 &&
    (documentPageCount === 0 || pageIndex < documentPageCount);
  let selectionValid = isValidStoredSelectionJson(rectsJson);
  if (selectionValid) {
    try {
      const selections = JSON.parse(rectsJson) as StoredSelection[];
      selectionValid = selections[0].pageIndex === pageIndex;
      if (documentPageCount > 0 &&
        selections.some((selection: StoredSelection): boolean =>
          selection.pageIndex >= documentPageCount)) {
        pageInRange = false;
      }
    } catch (error) {
      selectionValid = false;
    }
  }
  return {
    sourceCompatible: evidenceKind === 'HIGHLIGHT' || evidenceKind === 'UNDERLINE',
    selectionValid: selectionValid,
    pageInRange: pageInRange
  };
}

export function uniqueIds(values: string[]): string[] {
  const result: string[] = [];
  values.forEach((value: string): void => {
    if (value.length > 0 && !result.includes(value)) {
      result.push(value);
    }
  });
  return result;
}

export function canonicalPdfPath(filesDir: string, documentId: string): string {
  return `${filesDir}/library/${documentId}/source.pdf`;
}
