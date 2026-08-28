import relationalStore from '@ohos.data.relationalStore';
import { DocumentKind, DocumentRecord, EvidenceCard } from '../model/Models';
import { transactionFailure } from './TransactionError';
import { YueJiDatabase } from './YueJiDatabase';

export class LibraryRepository {
  private database: YueJiDatabase;

  constructor(database: YueJiDatabase) {
    this.database = database;
  }

  async insert(record: DocumentRecord): Promise<void> {
    await this.database.getStore().insert('documents', this.documentValues(record));
  }

  async insertWebWithEvidence(record: DocumentRecord, card: EvidenceCard | undefined): Promise<void> {
    const store = this.database.getStore();
    const transaction = await store.createTransaction();
    try {
      await transaction.insert('documents', this.documentValues(record));
      if (card !== undefined) {
        await transaction.insert('evidence_cards', this.evidenceValues(card));
      }
      await transaction.commit();
    } catch (error) {
      try {
        await transaction.rollback();
      } catch (rollbackError) {
        throw transactionFailure('Web document transaction failed', error, rollbackError);
      }
      throw transactionFailure('Web document transaction failed', error);
    }
  }

  async updateWebWithEvidence(
    record: DocumentRecord,
    card: EvidenceCard | undefined,
    removeCardIds: string[]
  ): Promise<void> {
    const store = this.database.getStore();
    const transaction = await store.createTransaction();
    try {
      const documentPredicates = new relationalStore.RdbPredicates('documents');
      documentPredicates.equalTo('id', record.id);
      const documentUpdated = await transaction.update(
        this.documentUpdateValues(record),
        documentPredicates
      );
      if (documentUpdated !== 1) {
        throw new Error('Web document was not updated');
      }
      if (card === undefined) {
        for (const id of removeCardIds) {
          await transaction.delete(this.evidencePredicates(id));
        }
      } else {
        const cardUpdated = await transaction.update(
          this.evidenceUpdateValues(card),
          this.evidencePredicates(card.id)
        );
        if (cardUpdated === 0) {
          await transaction.insert('evidence_cards', this.evidenceValues(card));
        } else if (cardUpdated !== 1) {
          throw new Error('Web evidence card was not updated');
        }
        for (const id of removeCardIds) {
          if (id !== card.id) {
            await transaction.delete(this.evidencePredicates(id));
          }
        }
      }
      await transaction.commit();
    } catch (error) {
      try {
        await transaction.rollback();
      } catch (rollbackError) {
        throw transactionFailure('Web document transaction failed', error, rollbackError);
      }
      throw transactionFailure('Web document transaction failed', error);
    }
  }

  async listAll(): Promise<DocumentRecord[]> {
    const predicates = new relationalStore.RdbPredicates('documents');
    predicates.orderByDesc('last_read_at');
    const resultSet = await this.database.getStore().query(predicates);
    const records: DocumentRecord[] = [];
    try {
      if (!resultSet.goToFirstRow()) {
        return records;
      }
      do {
        records.push(this.readRecord(resultSet));
      } while (resultSet.goToNextRow());
      return records;
    } finally {
      resultSet.close();
    }
  }

  async findById(id: string): Promise<DocumentRecord | undefined> {
    const predicates = new relationalStore.RdbPredicates('documents');
    predicates.equalTo('id', id);
    const resultSet = await this.database.getStore().query(predicates);
    try {
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      return this.readRecord(resultSet);
    } finally {
      resultSet.close();
    }
  }

  async updateReadPosition(id: string, currentPage: number): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      current_page: currentPage,
      last_read_at: Date.now()
    };
    await this.updateById(id, values);
  }

  async updateLastReadAt(id: string): Promise<number> {
    const lastReadAt = Date.now();
    const values: relationalStore.ValuesBucket = {
      last_read_at: lastReadAt
    };
    await this.updateById(id, values);
    return lastReadAt;
  }

  async updatePdfMetadata(id: string, pageCount: number, currentPage: number): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      page_count: pageCount,
      current_page: currentPage,
      last_read_at: Date.now()
    };
    await this.updateById(id, values);
  }

  async updatePdfDetails(id: string, title: string, tags: string): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      title: title,
      tags: tags
    };
    await this.updateById(id, values);
  }

  async updatePdfSourceFingerprint(id: string, source: string, contentHash: string): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      source: source,
      content_hash: contentHash,
      last_read_at: Date.now()
    };
    await this.updateById(id, values);
  }

  async updatePdfRestoration(
    id: string,
    source: string,
    contentHash: string,
    pageCount: number,
    currentPage: number
  ): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      source: source,
      content_hash: contentHash,
      page_count: pageCount,
      current_page: currentPage,
      last_read_at: Date.now()
    };
    await this.updateById(id, values);
  }

  async setFavorite(id: string, favorite: boolean): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      favorite: favorite ? 1 : 0
    };
    await this.updateById(id, values);
  }

  async updateTags(id: string, tags: string): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      tags: tags
    };
    await this.updateById(id, values);
  }

  async updateWebDetails(
    id: string,
    title: string,
    source: string,
    excerpt: string,
    note: string,
    tags: string
  ): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      title: title,
      source: source,
      excerpt: excerpt,
      note: note,
      tags: tags,
      last_read_at: Date.now()
    };
    await this.updateById(id, values);
  }

  async delete(id: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('documents');
    predicates.equalTo('id', id);
    const deletedCount = await this.database.getStore().delete(predicates);
    if (deletedCount !== 1) {
      throw new Error('Document was not deleted');
    }
  }

  private async updateById(id: string, values: relationalStore.ValuesBucket): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('documents');
    predicates.equalTo('id', id);
    const updatedCount = await this.database.getStore().update(values, predicates);
    if (updatedCount !== 1) {
      throw new Error('Document was not updated');
    }
  }

  private readRecord(resultSet: relationalStore.ResultSet): DocumentRecord {
    return {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      kind: resultSet.getString(resultSet.getColumnIndex('kind')) as DocumentKind,
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      source: resultSet.getString(resultSet.getColumnIndex('source')),
      pageCount: resultSet.getLong(resultSet.getColumnIndex('page_count')),
      currentPage: resultSet.getLong(resultSet.getColumnIndex('current_page')),
      tags: resultSet.getString(resultSet.getColumnIndex('tags')),
      favorite: resultSet.getLong(resultSet.getColumnIndex('favorite')) === 1,
      excerpt: resultSet.getString(resultSet.getColumnIndex('excerpt')),
      note: resultSet.getString(resultSet.getColumnIndex('note')),
      contentHash: resultSet.getString(resultSet.getColumnIndex('content_hash')),
      createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
      lastReadAt: resultSet.getLong(resultSet.getColumnIndex('last_read_at'))
    };
  }

  private documentValues(record: DocumentRecord): relationalStore.ValuesBucket {
    return {
      id: record.id,
      kind: record.kind,
      title: record.title,
      source: record.source,
      page_count: record.pageCount,
      current_page: record.currentPage,
      tags: record.tags,
      favorite: record.favorite ? 1 : 0,
      excerpt: record.excerpt,
      note: record.note,
      content_hash: record.contentHash,
      created_at: record.createdAt,
      last_read_at: record.lastReadAt
    };
  }

  private documentUpdateValues(record: DocumentRecord): relationalStore.ValuesBucket {
    return {
      title: record.title,
      source: record.source,
      page_count: record.pageCount,
      current_page: record.currentPage,
      tags: record.tags,
      favorite: record.favorite ? 1 : 0,
      excerpt: record.excerpt,
      note: record.note,
      content_hash: record.contentHash,
      last_read_at: record.lastReadAt
    };
  }

  private evidenceValues(card: EvidenceCard): relationalStore.ValuesBucket {
    return {
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
  }

  private evidenceUpdateValues(card: EvidenceCard): relationalStore.ValuesBucket {
    return {
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
      updated_at: card.updatedAt
    };
  }

  private evidencePredicates(id: string): relationalStore.RdbPredicates {
    const predicates = new relationalStore.RdbPredicates('evidence_cards');
    predicates.equalTo('id', id);
    return predicates;
  }
}
