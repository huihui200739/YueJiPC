import {
  DocumentRecord,
  EvidenceCard,
  MAX_SEARCH_LENGTH,
  tagList
} from '../model/Models';

export interface ReviewQuery {
  keyword: string;
  selectedTag: string;
}

export class ReviewFilterService {
  matches(card: EvidenceCard, document: DocumentRecord | undefined, query: ReviewQuery): boolean {
    const selectedTag = this.normalized(query.selectedTag);
    if (selectedTag.length > 0 &&
      !this.hasTag(card.tags, selectedTag) &&
      (document === undefined || !this.hasTag(document.tags, selectedTag))) {
      return false;
    }

    const keyword = this.normalizeKeyword(query.keyword);
    if (keyword.length === 0) {
      return true;
    }
    const cardTexts: string[] = [card.quote, card.note, card.tags];
    const documentTexts: string[] = document === undefined ? [] : [
      document.title,
      document.source,
      document.tags,
      document.excerpt,
      document.note
    ];
    return cardTexts.concat(documentTexts).some((text: string): boolean =>
      this.containsKeyword(text, keyword));
  }

  matchesDocument(
    document: DocumentRecord,
    evidenceCards: EvidenceCard[],
    keyword: string
  ): boolean {
    const normalizedKeyword = this.normalizeKeyword(keyword);
    if (normalizedKeyword.length === 0) {
      return true;
    }
    const documentTexts: string[] = [
      document.title,
      document.source,
      document.tags,
      document.excerpt,
      document.note
    ];
    if (documentTexts.some((text: string): boolean =>
      this.containsKeyword(text, normalizedKeyword))) {
      return true;
    }
    return evidenceCards.some((card: EvidenceCard): boolean =>
      card.documentId === document.id &&
      [card.quote, card.note, card.tags].some((text: string): boolean =>
        this.containsKeyword(text, normalizedKeyword)));
  }

  normalizeKeyword(value: string): string {
    return this.normalized(value).slice(0, MAX_SEARCH_LENGTH);
  }

  hasTag(tags: string, selectedTag: string): boolean {
    const target = this.normalized(selectedTag);
    if (target.length === 0) {
      return true;
    }
    return tagList(tags).some((tag: string): boolean =>
      this.normalized(tag) === target);
  }

  allTags(documents: DocumentRecord[], evidenceCards: EvidenceCard[]): string[] {
    const values: string[] = [];
    const normalizedValues: string[] = [];
    const append = (tags: string): void => {
      tagList(tags).forEach((tag: string): void => {
        const normalized = this.normalized(tag);
        if (normalized.length > 0 && !normalizedValues.includes(normalized)) {
          values.push(tag);
          normalizedValues.push(normalized);
        }
      });
    };
    documents.forEach((document: DocumentRecord): void => append(document.tags));
    evidenceCards.forEach((card: EvidenceCard): void => append(card.tags));
    return values.sort((left: string, right: string): number => {
      const normalizedLeft = this.normalized(left);
      const normalizedRight = this.normalized(right);
      if (normalizedLeft === normalizedRight) {
        return 0;
      }
      return normalizedLeft < normalizedRight ? -1 : 1;
    });
  }

  private normalized(value: string): string {
    return value.trim().toLowerCase();
  }

  private containsKeyword(value: string, keyword: string): boolean {
    return this.normalized(value).includes(keyword);
  }
}
