import relationalStore from '@ohos.data.relationalStore';
import {
  EvidenceCard,
  EvidenceKind,
  normalizeTags,
  ReviewStatus,
  uniqueIds
} from '../model/Models';
import { EvidenceCardMutationService } from '../services/EvidenceCardMutationService';
import { transactionFailure } from './TransactionError';
import { YueJiDatabase } from './YueJiDatabase';

export class EvidenceRepository {
  private database: YueJiDatabase;
  private mutationService: EvidenceCardMutationService = new EvidenceCardMutationService();

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

  async getById(id: string): Promise<EvidenceCard | undefined> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('id', id);
    const cards = await this.query(predicates);
    return cards[0];
  }

  async updateCard(
    id: string,
    note: string,
    tags: string,
    kind: EvidenceKind,
    color: number,
    reviewStatus: ReviewStatus
  ): Promise<EvidenceCard> {
    const updatedAt = Date.now();
    const existing = await this.requireById(id);
    const updatedCard = this.mutationService.forEdit(
      existing, note, tags, kind, color, reviewStatus, updatedAt);
    const values: relationalStore.ValuesBucket = {
      note: updatedCard.note,
      tags: updatedCard.tags,
      kind: updatedCard.kind,
      color: updatedCard.color,
      review_status: updatedCard.reviewStatus,
      last_reviewed_at: updatedCard.lastReviewedAt,
      next_review_at: updatedCard.nextReviewAt,
      review_count: updatedCard.reviewCount,
      updated_at: updatedCard.updatedAt
    };
    await this.updateById(id, values);
    return updatedCard;
  }

  async updateWebCard(
    id: string,
    quote: string,
    note: string,
    tags: string,
    reviewStatus: ReviewStatus
  ): Promise<EvidenceCard> {
    const updatedAt = Date.now();
    const existing = await this.requireById(id);
    const updatedCard = this.mutationService.forWebEdit(
      existing, quote, note, tags, reviewStatus, updatedAt);
    const values: relationalStore.ValuesBucket = {
      quote: updatedCard.quote,
      page_index: updatedCard.pageIndex,
      rects_json: updatedCard.rectsJson,
      note: updatedCard.note,
      kind: updatedCard.kind,
      tags: updatedCard.tags,
      review_status: updatedCard.reviewStatus,
      last_reviewed_at: updatedCard.lastReviewedAt,
      next_review_at: updatedCard.nextReviewAt,
      review_count: updatedCard.reviewCount,
      updated_at: updatedCard.updatedAt
    };
    await this.updateById(id, values);
    return updatedCard;
  }

  async setReviewStatus(id: string, reviewStatus: ReviewStatus): Promise<EvidenceCard> {
    const updatedAt = Date.now();
    const existing = await this.requireById(id);
    const updatedCard = this.mutationService.forReviewStatus(existing, reviewStatus, updatedAt);
    const values: relationalStore.ValuesBucket = {
      review_status: updatedCard.reviewStatus,
      last_reviewed_at: updatedCard.lastReviewedAt,
      next_review_at: updatedCard.nextReviewAt,
      review_count: updatedCard.reviewCount,
      updated_at: updatedCard.updatedAt
    };
    await this.updateById(id, values);
    return updatedCard;
  }

  async deferReview(id: string): Promise<EvidenceCard> {
    const updatedAt = Date.now();
    const existing = await this.requireById(id);
    const updatedCard = this.mutationService.forDeferredReview(existing, updatedAt);
    await this.updateById(id, {
      review_status: updatedCard.reviewStatus,
      last_reviewed_at: updatedCard.lastReviewedAt,
      next_review_at: updatedCard.nextReviewAt,
      review_count: updatedCard.reviewCount,
      updated_at: updatedCard.updatedAt
    });
    return updatedCard;
  }

  async batchSetReviewStatus(ids: string[], reviewStatus: ReviewStatus): Promise<EvidenceCard[]> {
    const targetIds = uniqueIds(ids);
    if (targetIds.length === 0) {
      return [];
    }
    const cards = await this.listAll();
    const existingIds = targetIds.filter((id: string): boolean =>
      cards.some((card: EvidenceCard): boolean => card.id === id));
    if (existingIds.length === 0) {
      return [];
    }
    const updatedAt = Date.now();
    const store = this.database.getStore();
    const transactionId = await store.beginTrans();
    const updatedCards: EvidenceCard[] = [];
    try {
      for (const id of existingIds) {
        const card = cards.find((item: EvidenceCard): boolean => item.id === id);
        if (card === undefined) {
          continue;
        }
        const updatedCard = this.mutationService.forReviewStatus(card, reviewStatus, updatedAt);
        await store.execute(
          'UPDATE evidence_cards SET review_status = ?, last_reviewed_at = ?, next_review_at = ?, ' +
          'review_count = ?, updated_at = ? WHERE id = ?',
          transactionId,
          [
            updatedCard.reviewStatus,
            updatedCard.lastReviewedAt,
            updatedCard.nextReviewAt,
            updatedCard.reviewCount,
            updatedCard.updatedAt,
            id
          ]
        );
        updatedCards.push(updatedCard);
      }
      await store.commit(transactionId);
      return updatedCards;
    } catch (error) {
      try {
        await store.rollback(transactionId);
      } catch (rollbackError) {
        throw transactionFailure('Batch review status update failed', error, rollbackError);
      }
      throw transactionFailure('Batch review status update failed', error);
    }
  }

  async batchAppendTags(ids: string[], tags: string): Promise<EvidenceCard[]> {
    const targetIds = uniqueIds(ids);
    const normalizedTags = normalizeTags(tags);
    if (targetIds.length === 0 || normalizedTags.length === 0) {
      return [];
    }
    const cards = await this.listAll();
    const targetCards = cards.filter((card: EvidenceCard): boolean => targetIds.includes(card.id));
    if (targetCards.length === 0) {
      return [];
    }
    const updatedAt = Date.now();
    const store = this.database.getStore();
    const transactionId = await store.beginTrans();
    const updatedCards: EvidenceCard[] = [];
    try {
      for (const card of targetCards) {
        const updatedCard = this.mutationService.withAppendedTags(card, normalizedTags, updatedAt);
        await store.execute(
          'UPDATE evidence_cards SET tags = ?, updated_at = ? WHERE id = ?',
          transactionId,
          [updatedCard.tags, updatedCard.updatedAt, card.id]
        );
        updatedCards.push(updatedCard);
      }
      await store.commit(transactionId);
      return updatedCards;
    } catch (error) {
      try {
        await store.rollback(transactionId);
      } catch (rollbackError) {
        throw transactionFailure('Batch tag update failed', error, rollbackError);
      }
      throw transactionFailure('Batch tag update failed', error);
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

  private async requireById(id: string): Promise<EvidenceCard> {
    const card = await this.getById(id);
    if (card === undefined) {
      throw new Error('Evidence card was not found');
    }
    return card;
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
