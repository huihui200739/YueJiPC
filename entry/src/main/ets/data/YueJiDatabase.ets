import relationalStore from '@ohos.data.relationalStore';

const DATABASE_NAME = 'yueji.db';
const DOCUMENT_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    title TEXT NOT NULL,
    source TEXT NOT NULL,
    page_count INTEGER NOT NULL DEFAULT 0,
    current_page INTEGER NOT NULL DEFAULT 0,
    tags TEXT NOT NULL DEFAULT '',
    favorite INTEGER NOT NULL DEFAULT 0,
    excerpt TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    last_read_at INTEGER NOT NULL
  )
`;
const EVIDENCE_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS evidence_cards (
    id TEXT PRIMARY KEY,
    document_id TEXT NOT NULL,
    quote TEXT NOT NULL,
    page_index INTEGER NOT NULL DEFAULT 0,
    rects_json TEXT NOT NULL DEFAULT '[]',
    note TEXT NOT NULL DEFAULT '',
    kind TEXT NOT NULL,
    color INTEGER NOT NULL,
    tags TEXT NOT NULL DEFAULT '',
    review_status TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
`;
const EVIDENCE_DOCUMENT_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS evidence_document_index ON evidence_cards(document_id)';
const EVIDENCE_STATUS_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS evidence_status_index ON evidence_cards(review_status)';
const EVIDENCE_UPDATED_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS evidence_updated_index ON evidence_cards(updated_at DESC)';
const DOCUMENT_RECENT_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS document_recent_index ON documents(last_read_at DESC)';
const DOCUMENT_FAVORITE_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS document_favorite_index ON documents(favorite)';
const DOCUMENT_DELETE_TRIGGER_SQL = `
  CREATE TRIGGER IF NOT EXISTS document_delete_evidence
  AFTER DELETE ON documents
  BEGIN
    DELETE FROM evidence_cards WHERE document_id = OLD.id;
  END
`;
const DELETE_ORPHAN_EVIDENCE_SQL =
  'DELETE FROM evidence_cards WHERE document_id NOT IN (SELECT id FROM documents)';

export class YueJiDatabase {
  private store: relationalStore.RdbStore | undefined;

  async initialize(context: Context): Promise<void> {
    if (this.store !== undefined) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: DATABASE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, config);
    await this.store.executeSql(DOCUMENT_TABLE_SQL);
    await this.store.executeSql(EVIDENCE_TABLE_SQL);
    await this.store.executeSql(EVIDENCE_DOCUMENT_INDEX_SQL);
    await this.store.executeSql(EVIDENCE_STATUS_INDEX_SQL);
    await this.store.executeSql(EVIDENCE_UPDATED_INDEX_SQL);
    await this.store.executeSql(DOCUMENT_RECENT_INDEX_SQL);
    await this.store.executeSql(DOCUMENT_FAVORITE_INDEX_SQL);
    await this.store.executeSql(DOCUMENT_DELETE_TRIGGER_SQL);
    await this.store.executeSql(DELETE_ORPHAN_EVIDENCE_SQL);
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === undefined) {
      throw new Error('Database has not been initialized');
    }
    return this.store;
  }
}
