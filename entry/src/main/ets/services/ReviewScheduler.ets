import { EvidenceCard, ReviewStatus } from '../model/Models';

export interface ReviewScheduleValues {
  lastReviewedAt: number;
  nextReviewAt: number;
  reviewCount: number;
}

export class ReviewScheduler {
  valuesForStatus(
    card: EvidenceCard,
    reviewStatus: ReviewStatus,
    updatedAt: number
  ): ReviewScheduleValues {
    if (reviewStatus === 'MASTERED') {
      const shouldRecordReview = card.reviewStatus !== 'MASTERED' || this.isDue(card, updatedAt);
      if (shouldRecordReview) {
        const reviewCount = card.reviewCount + 1;
        return {
          lastReviewedAt: updatedAt,
          nextReviewAt: this.nextReviewAt(reviewCount, updatedAt),
          reviewCount: reviewCount
        };
      }
      return {
        lastReviewedAt: card.lastReviewedAt,
        nextReviewAt: card.nextReviewAt,
        reviewCount: card.reviewCount
      };
    }
    return {
      lastReviewedAt: card.lastReviewedAt,
      nextReviewAt: card.reviewStatus === 'TO_REVIEW' ? card.nextReviewAt : 0,
      reviewCount: card.reviewCount
    };
  }

  deferValues(card: EvidenceCard, updatedAt: number): ReviewScheduleValues {
    return {
      lastReviewedAt: card.lastReviewedAt,
      nextReviewAt: updatedAt + this.reviewDayMilliseconds(),
      reviewCount: card.reviewCount
    };
  }

  isDue(card: EvidenceCard, now: number): boolean {
    if (card.reviewStatus === 'TO_REVIEW') {
      return card.nextReviewAt <= 0 || card.nextReviewAt <= now;
    }
    return card.nextReviewAt > 0 && card.nextReviewAt <= now;
  }

  nextReviewAt(reviewCount: number, reviewedAt: number): number {
    const days = reviewCount <= 1 ? 1 : reviewCount === 2 ? 3 : reviewCount === 3 ? 7 : 14;
    return reviewedAt + days * this.reviewDayMilliseconds();
  }

  private reviewDayMilliseconds(): number {
    return 24 * 60 * 60 * 1000;
  }
}
