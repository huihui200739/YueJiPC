import {
  EvidenceCard,
  EvidenceKind,
  normalizeTags,
  ReviewStatus
} from '../model/Models';
import { ReviewScheduleValues, ReviewScheduler } from './ReviewScheduler';

export class EvidenceCardMutationService {
  private reviewScheduler: ReviewScheduler = new ReviewScheduler();

  forEdit(
    card: EvidenceCard,
    note: string,
    tags: string,
    kind: EvidenceKind,
    color: number,
    reviewStatus: ReviewStatus,
    updatedAt: number
  ): EvidenceCard {
    const review = this.reviewScheduler.valuesForEdit(card, reviewStatus, updatedAt);
    return this.withReviewValues(
      card,
      card.quote,
      card.pageIndex,
      card.rectsJson,
      note,
      kind,
      color,
      normalizeTags(tags),
      reviewStatus,
      review,
      updatedAt
    );
  }

  forWebEdit(
    card: EvidenceCard,
    quote: string,
    note: string,
    tags: string,
    reviewStatus: ReviewStatus,
    updatedAt: number
  ): EvidenceCard {
    const review = this.reviewScheduler.valuesForEdit(card, reviewStatus, updatedAt);
    return this.withReviewValues(
      card,
      quote.trim(),
      0,
      '[]',
      note.trim(),
      'QUOTE',
      card.color,
      normalizeTags(tags),
      reviewStatus,
      review,
      updatedAt
    );
  }

  forReviewStatus(
    card: EvidenceCard,
    reviewStatus: ReviewStatus,
    updatedAt: number
  ): EvidenceCard {
    const review = this.reviewScheduler.valuesForReviewAction(card, reviewStatus, updatedAt);
    return this.withReviewValues(
      card,
      card.quote,
      card.pageIndex,
      card.rectsJson,
      card.note,
      card.kind,
      card.color,
      card.tags,
      reviewStatus,
      review,
      updatedAt
    );
  }

  forDeferredReview(card: EvidenceCard, updatedAt: number): EvidenceCard {
    const review = this.reviewScheduler.deferValues(card, updatedAt);
    return this.withReviewValues(
      card,
      card.quote,
      card.pageIndex,
      card.rectsJson,
      card.note,
      card.kind,
      card.color,
      card.tags,
      'TO_REVIEW',
      review,
      updatedAt
    );
  }

  withAppendedTags(card: EvidenceCard, tags: string, updatedAt: number): EvidenceCard {
    const normalizedTags = normalizeTags(tags);
    const mergedTags = normalizeTags(
      card.tags.length > 0 ? `${card.tags}, ${normalizedTags}` : normalizedTags
    );
    return {
      id: card.id,
      documentId: card.documentId,
      quote: card.quote,
      pageIndex: card.pageIndex,
      rectsJson: card.rectsJson,
      note: card.note,
      kind: card.kind,
      color: card.color,
      tags: mergedTags,
      reviewStatus: card.reviewStatus,
      lastReviewedAt: card.lastReviewedAt,
      nextReviewAt: card.nextReviewAt,
      reviewCount: card.reviewCount,
      createdAt: card.createdAt,
      updatedAt: updatedAt
    };
  }

  private withReviewValues(
    card: EvidenceCard,
    quote: string,
    pageIndex: number,
    rectsJson: string,
    note: string,
    kind: EvidenceKind,
    color: number,
    tags: string,
    reviewStatus: ReviewStatus,
    review: ReviewScheduleValues,
    updatedAt: number
  ): EvidenceCard {
    return {
      id: card.id,
      documentId: card.documentId,
      quote: quote,
      pageIndex: pageIndex,
      rectsJson: rectsJson,
      note: note,
      kind: kind,
      color: color,
      tags: tags,
      reviewStatus: reviewStatus,
      lastReviewedAt: review.lastReviewedAt,
      nextReviewAt: review.nextReviewAt,
      reviewCount: review.reviewCount,
      createdAt: card.createdAt,
      updatedAt: updatedAt
    };
  }
}
