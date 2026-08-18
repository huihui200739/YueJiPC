import relationalStore from '@ohos.data.relationalStore';
import {
  EvidenceCard,
  EvidenceKind,
  normalizeTags,
  ReviewStatus,
  uniqueIds
} from '../model/Models';
import { ReviewScheduler } from '../services/ReviewScheduler';
import { YueJiDatabase } from './YueJiDatabase';

export class EvidenceRepository {
  private database: YueJiDatabase;
  private reviewScheduler: ReviewScheduler = new ReviewScheduler();

  constructor(database: YueJiDatabase) {
    this.database = database;
  }

  async insert(card: EvidenceCard): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      id: card.id,
      document_id: card.documentId,
      quote: card.quote,
      page_index: card.pageIndex,
      rects_json: card.rectsJson,
      note: card.note,
      kind: card.kind,
      color: card.color,
      tags: card.tags,
      review_status: card.reviewStatus,
      last_reviewed_at: card.lastReviewedAt,
      next_review_at: card.nextReviewAt,
      review_count: card.reviewCount,
      created_at: card.createdAt,
      updated_at: card.updatedAt
    };
    await this.database.getStore().insert('evidence_cards', values);
  }

  async listAll(): Promise<EvidenceCard[]> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.orderByDesc('updated_at');
    return this.query(predicates);
  }

  async listByDocument(documentId: string): Promise<EvidenceCard[]> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('document_id', documentId);
    predicates.orderByAsc('page_index');
    return this.query(predicates);
  }

  async updateCard(
    id: string,
    note: string,
    tags: string,
    kind: EvidenceKind,
    color: number,
    reviewStatus: ReviewStatus
  ): Promise<number> {
    const updatedAt = Date.now();
    const existing = (await this.listAll()).find((card: EvidenceCard): boolean => card.id === id);
    if (existing === undefined) {
      throw new Error('Evidence card was not found');
    }
    const review = this.reviewScheduler.valuesForEdit(existing, reviewStatus, updatedAt);
    const values: relationalStore.ValuesBucket = {
      note: note,
      tags: tags,
      kind: kind,
      color: color,
      review_status: reviewStatus,
      last_reviewed_at: review.lastReviewedAt,
      next_review_at: review.nextReviewAt,
      review_count: review.reviewCount,
      updated_at: updatedAt
    };
    await this.updateById(id, values);
    return updatedAt;
  }

  async updateWebCard(
    id: string,
    quote: string,
    note: string,
    tags: string,
    reviewStatus: ReviewStatus
  ): Promise<number> {
    const updatedAt = Date.now();
    const existing = (await this.listAll()).find((card: EvidenceCard): boolean => card.id === id);
    if (existing === undefined) {
      throw new Error('Evidence card was not found');
    }
    const review = this.reviewScheduler.valuesForEdit(existing, reviewStatus, updatedAt);
    const values: relationalStore.ValuesBucket = {
      quote: quote,
      page_index: 0,
      rects_json: '[]',
      note: note,
      kind: 'QUOTE',
      tags: tags,
      review_status: reviewStatus,
      last_reviewed_at: review.lastReviewedAt,
      next_review_at: review.nextReviewAt,
      review_count: review.reviewCount,
      updated_at: updatedAt
    };
    await this.updateById(id, values);
    return updatedAt;
  }

  async setReviewStatus(id: string, reviewStatus: ReviewStatus): Promise<number> {
    const updatedAt = Date.now();
    const existing = (await this.listAll()).find((card: EvidenceCard): boolean => card.id === id);
    if (existing === undefined) {
      throw new Error('Evidence card was not found');
    }
    const review = this.reviewScheduler.valuesForReviewAction(existing, reviewStatus, updatedAt);
    const values: relationalStore.ValuesBucket = {
      review_status: reviewStatus,
      last_reviewed_at: review.lastReviewedAt,
      next_review_at: review.nextReviewAt,
      review_count: review.reviewCount,
      updated_at: updatedAt
    };
    await this.updateById(id, values);
    return updatedAt;
  }

  async deferReview(id: string): Promise<number> {
    const updatedAt = Date.now();
    const existing = (await this.listAll()).find((card: EvidenceCard): boolean => card.id === id);
    if (existing === undefined) {
      throw new Error('Evidence card was not found');
    }
    const review = this.reviewScheduler.deferValues(existing, updatedAt);
    await this.updateById(id, {
      review_status: 'TO_REVIEW',
      last_reviewed_at: review.lastReviewedAt,
      next_review_at: review.nextReviewAt,
      review_count: review.reviewCount,
      updated_at: updatedAt
    });
    return updatedAt;
  }

  async batchSetReviewStatus(ids: string[], reviewStatus: ReviewStatus): Promise<number> {
    const targetIds = uniqueIds(ids);
    if (targetIds.length === 0) {
      return 0;
    }
    const cards = await this.listAll();
    const existingIds = targetIds.filter((id: string): boolean =>
      cards.some((card: EvidenceCard): boolean => card.id === id));
    if (existingIds.length === 0) {
      return 0;
    }
    const updatedAt = Date.now();
    const store = this.database.getStore();
    const transactionId = await store.beginTrans();
    try {
      for (const id of existingIds) {
        const card = cards.find((item: EvidenceCard): boolean => item.id === id);
        if (card === undefined) {
          continue;
        }
        const review = this.reviewScheduler.valuesForReviewAction(card, reviewStatus, updatedAt);
        await store.execute(
          'UPDATE evidence_cards SET review_status = ?, last_reviewed_at = ?, next_review_at = ?, ' +
          'review_count = ?, updated_at = ? WHERE id = ?',
          transactionId,
          [reviewStatus, review.lastReviewedAt, review.nextReviewAt, review.reviewCount, updatedAt, id]
        );
      }
      await store.commit(transactionId);
      return existingIds.length;
    } catch (error) {
      await store.rollback(transactionId);
      throw new Error('Batch review status update failed');
    }
  }

  async batchAppendTags(ids: string[], tags: string): Promise<number> {
    const targetIds = uniqueIds(ids);
    const normalizedTags = normalizeTags(tags);
    if (targetIds.length === 0 || normalizedTags.length === 0) {
      return 0;
    }
    const cards = await this.listAll();
    const targetCards = cards.filter((card: EvidenceCard): boolean => targetIds.includes(card.id));
    if (targetCards.length === 0) {
      return 0;
    }
    const updatedAt = Date.now();
    const store = this.database.getStore();
    const transactionId = await store.beginTrans();
    try {
      for (const card of targetCards) {
        const mergedTags = normalizeTags(
          card.tags.length > 0 ? `${card.tags}, ${normalizedTags}` : normalizedTags
        );
        await store.execute(
          'UPDATE evidence_cards SET tags = ?, updated_at = ? WHERE id = ?',
          transactionId,
          [mergedTags, updatedAt, card.id]
        );
      }
      await store.commit(transactionId);
      return targetCards.length;
    } catch (error) {
      await store.rollback(transactionId);
      throw new Error('Batch tag update failed');
    }
  }

  async delete(id: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('id', id);
    const deletedCount = await this.database.getStore().delete(predicates);
    if (deletedCount !== 1) {
      throw new Error('Evidence card was not deleted');
    }
  }

  async deleteByDocument(documentId: string): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('document_id', documentId);
    return await this.database.getStore().delete(predicates);
  }

  private async updateById(id: string, values: relationalStore.ValuesBucket): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('id', id);
    const updatedCount = await this.database.getStore().update(values, predicates);
    if (updatedCount !== 1) {
      throw new Error('Evidence card was not updated');
    }
  }

  private async query(predicates: relationalStore.RdbPredicates): Promise<EvidenceCard[]> {
    const resultSet = await this.database.getStore().query(predicates);
    const cards: EvidenceCard[] = [];
    try {
      if (!resultSet.goToFirstRow()) {
        return cards;
      }
      do {
        cards.push(this.readCard(resultSet));
      } while (resultSet.goToNextRow());
      return cards;
    } finally {
      resultSet.close();
    }
  }

  private readCard(resultSet: relationalStore.ResultSet): EvidenceCard {
    return {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      documentId: resultSet.getString(resultSet.getColumnIndex('document_id')),
      quote: resultSet.getString(resultSet.getColumnIndex('quote')),
      pageIndex: resultSet.getLong(resultSet.getColumnIndex('page_index')),
      rectsJson: resultSet.getString(resultSet.getColumnIndex('rects_json')),
      note: resultSet.getString(resultSet.getColumnIndex('note')),
      kind: resultSet.getString(resultSet.getColumnIndex('kind')) as EvidenceKind,
      color: resultSet.getLong(resultSet.getColumnIndex('color')),
      tags: resultSet.getString(resultSet.getColumnIndex('tags')),
      reviewStatus: resultSet.getString(resultSet.getColumnIndex('review_status')) as ReviewStatus,
      lastReviewedAt: resultSet.getLong(resultSet.getColumnIndex('last_reviewed_at')),
      nextReviewAt: resultSet.getLong(resultSet.getColumnIndex('next_review_at')),
      reviewCount: resultSet.getLong(resultSet.getColumnIndex('review_count')),
      createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
      updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
    };
  }

}
