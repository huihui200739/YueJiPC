import { common } from '@kit.AbilityKit';
import { createId, DocumentRecord, MAX_URL_LENGTH, normalizeTags } from '../model/Models';

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
    if (/^https?:\/\//i.test(trimmed)) {
      return trimmed;
    }
    return `https://${trimmed}`;
  }

  isValidUrl(value: string): boolean {
    const normalized = this.normalizeUrl(value);
    if (normalized.length > MAX_URL_LENGTH || /\s/.test(normalized)) {
      return false;
    }
    const match = normalized.match(/^https?:\/\/([^/?#]+)(?:[/?#][^\s]*)?$/i);
    if (match === null || match.length < 2) {
      return false;
    }
    let host = match[1];
    const colonIndex = host.lastIndexOf(':');
    if (colonIndex >= 0) {
      const portText = host.substring(colonIndex + 1);
      if (!/^\d{1,5}$/.test(portText)) {
        return false;
      }
      const port = Number(portText);
      if (!Number.isInteger(port) || port < 1 || port > 65535) {
        return false;
      }
      host = host.substring(0, colonIndex);
    }
    if (host.toLowerCase() === 'localhost') {
      return true;
    }
    if (/^(?:\d{1,3}\.){3}\d{1,3}$/.test(host)) {
      return host.split('.').every((part: string): boolean => {
        const value = Number(part);
        return Number.isInteger(value) && value >= 0 && value <= 255;
      });
    }
    const labels = host.split('.');
    if (labels.length < 2 || labels[labels.length - 1].length < 2) {
      return false;
    }
    return labels.every((label: string): boolean =>
      /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(label));
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
      contentHash: '',
      createdAt: now,
      lastReadAt: now
    };
  }

  async open(context: common.UIAbilityContext, url: string): Promise<void> {
    await context.openLink(this.normalizeUrl(url));
  }
}
