import { common } from '@kit.AbilityKit';
import { createId, DocumentRecord, normalizeTags } from '../model/Models';

export interface WebDraft {
  title: string;
  url: string;
  excerpt: string;
  note: string;
  tags: string;
}

export class LinkService {
  normalizeUrl(value: string): string {
    const trimmed = value.trim();
    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
      return trimmed;
    }
    return `https://${trimmed}`;
  }

  isValidUrl(value: string): boolean {
    const normalized = this.normalizeUrl(value);
    return /^https?:\/\/[^\s.]+\.[^\s]+$/i.test(normalized);
  }

  createDocument(draft: WebDraft): DocumentRecord {
    const now = Date.now();
    return {
      id: createId('web'),
      kind: 'WEB',
      title: draft.title.trim().length > 0 ? draft.title.trim() : this.normalizeUrl(draft.url),
      source: this.normalizeUrl(draft.url),
      pageCount: 0,
      currentPage: 0,
      tags: normalizeTags(draft.tags),
      favorite: false,
      excerpt: draft.excerpt.trim(),
      note: draft.note.trim(),
      createdAt: now,
      lastReadAt: now
    };
  }

  async open(context: common.UIAbilityContext, url: string): Promise<void> {
    await context.openLink(this.normalizeUrl(url));
  }
}
