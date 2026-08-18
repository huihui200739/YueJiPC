import relationalStore from '@ohos.data.relationalStore';
import { DocumentKind, DocumentRecord, EvidenceCard } from '../model/Models';
import { YueJiDatabase } from './YueJiDatabase';

export class LibraryRepository {
  private database: YueJiDatabase;

  constructor(database: YueJiDatabase) {
    this.database = database;
  }

  async insert(record: DocumentRecord): Promise<void> {
    const values: relationalStore.ValuesBucket = {
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
    await this.database.getStore().insert('documents', values);
  }

  async insertWebWithEvidence(record: DocumentRecord, card: EvidenceCard | undefined): Promise<void> {
    const store = this.database.getStore();
    const transactionId = await store.beginTrans();
    try {
      await store.execute(
        `INSERT INTO documents
          (id, kind, title, source, page_count, current_page, tags, favorite, excerpt, note,
           content_hash, created_at, last_read_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        transactionId,
        this.documentValues(record)
      );
      if (card !== undefined) {
        await store.execute(
          `INSERT INTO evidence_cards
            (id, document_id, quote, page_index, rects_json, note, kind, color, tags, review_status,
             last_reviewed_at, next_review_at, review_count, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          transactionId,
          this.evidenceValues(card)
        );
      }
      await store.commit(transactionId);
    } catch (error) {
      await store.rollback(transactionId);
      throw new Error('Web document transaction failed');
    }
  }

  async updateWebWithEvidence(
    record: DocumentRecord,
    card: EvidenceCard | undefined,
    removeCardIds: string[]
  ): Promise<void> {
    const store = this.database.getStore();
    const transactionId = await store.beginTrans();
    try {
      await store.execute(
        `UPDATE documents SET
          title = ?, source = ?, page_count = ?, current_page = ?, tags = ?, favorite = ?,
          excerpt = ?, note = ?, content_hash = ?, last_read_at = ?
          WHERE id = ?`,
        transactionId,
        [
          record.title, record.source, record.pageCount, record.currentPage, record.tags,
          record.favorite ? 1 : 0, record.excerpt, record.note, record.contentHash, record.lastReadAt, record.id
        ]
      );
      if (card === undefined) {
        for (const id of removeCardIds) {
          await store.execute('DELETE FROM evidence_cards WHERE id = ?', transactionId, [id]);
        }
      } else {
        await store.execute(
          `UPDATE evidence_cards SET
            quote = ?, page_index = ?, rects_json = ?, note = ?, kind = ?, color = ?,
            tags = ?, review_status = ?, last_reviewed_at = ?, next_review_at = ?, review_count = ?,
            updated_at = ?
            WHERE id = ?`,
          transactionId,
          [
            card.quote, card.pageIndex, card.rectsJson, card.note, card.kind, card.color,
            card.tags, card.reviewStatus, card.lastReviewedAt, card.nextReviewAt, card.reviewCount,
            card.updatedAt, card.id
          ]
        );
        if (removeCardIds.length === 0 && card.id.length > 0) {
          // The caller may be saving the first web evidence card for a legacy record.
          await store.execute(
            `INSERT OR IGNORE INTO evidence_cards
              (id, document_id, quote, page_index, rects_json, note, kind, color, tags, review_status,
               last_reviewed_at, next_review_at, review_count, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            transactionId,
            this.evidenceValues(card)
          );
        }
        for (const id of removeCardIds) {
          if (id !== card.id) {
            await store.execute('DELETE FROM evidence_cards WHERE id = ?', transactionId, [id]);
          }
        }
      }
      await store.commit(transactionId);
    } catch (error) {
      await store.rollback(transactionId);
      throw new Error('Web document transaction failed');
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

  async updateLastReadAt(id: string): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      last_read_at: Date.now()
    };
    await this.updateById(id, values);
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

  private documentValues(record: DocumentRecord): relationalStore.ValueType[] {
    return [
      record.id, record.kind, record.title, record.source, record.pageCount, record.currentPage,
      record.tags, record.favorite ? 1 : 0, record.excerpt, record.note, record.contentHash,
      record.createdAt, record.lastReadAt
    ];
  }

  private evidenceValues(card: EvidenceCard): relationalStore.ValueType[] {
    return [
      card.id, card.documentId, card.quote, card.pageIndex, card.rectsJson, card.note,
      card.kind, card.color, card.tags, card.reviewStatus, card.lastReviewedAt, card.nextReviewAt,
      card.reviewCount, card.createdAt, card.updatedAt
    ];
  }
}
