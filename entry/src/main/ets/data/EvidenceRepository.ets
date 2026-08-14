import relationalStore from '@ohos.data.relationalStore';
import { EvidenceCard, EvidenceKind, ReviewStatus } from '../model/Models';
import { YueJiDatabase } from './YueJiDatabase';

export class EvidenceRepository {
  private database: YueJiDatabase;

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

  async updateCard(id: string, note: string, tags: string, reviewStatus: ReviewStatus): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      note: note,
      tags: tags,
      review_status: reviewStatus,
      updated_at: Date.now()
    };
    await this.updateById(id, values);
  }

  async setReviewStatus(id: string, reviewStatus: ReviewStatus): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      review_status: reviewStatus,
      updated_at: Date.now()
    };
    await this.updateById(id, values);
  }

  async delete(id: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('id', id);
    await this.database.getStore().delete(predicates);
  }

  async deleteByDocument(documentId: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('document_id', documentId);
    await this.database.getStore().delete(predicates);
  }

  private async updateById(id: string, values: relationalStore.ValuesBucket): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('id', id);
    await this.database.getStore().update(values, predicates);
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
      createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
      updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
    };
  }
}
