import relationalStore from '@ohos.data.relationalStore';
import { DATABASE_SCHEMA_VERSION } from '../model/Models';

const DATABASE_NAME = 'yueji.db';
const SCHEMA_META_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS schema_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
`;
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
    content_hash TEXT NOT NULL DEFAULT '',
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
    last_reviewed_at INTEGER NOT NULL DEFAULT 0,
    next_review_at INTEGER NOT NULL DEFAULT 0,
    review_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
`;
const COLLECTION_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS collections (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
`;
const COLLECTION_ITEM_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS collection_items (
    collection_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    item_kind TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (collection_id, item_id, item_kind)
  )
`;
const EVIDENCE_DOCUMENT_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS evidence_document_index ON evidence_cards(document_id)';
const EVIDENCE_STATUS_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS evidence_status_index ON evidence_cards(review_status)';
const EVIDENCE_NEXT_REVIEW_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS evidence_next_review_index ON evidence_cards(next_review_at)';
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
const DOCUMENT_DELETE_COLLECTION_TRIGGER_SQL = `
  CREATE TRIGGER IF NOT EXISTS document_delete_collection_items
  AFTER DELETE ON documents
  BEGIN
    DELETE FROM collection_items
      WHERE item_id = OLD.id AND item_kind = 'DOCUMENT';
  END
`;
const EVIDENCE_DELETE_COLLECTION_TRIGGER_SQL = `
  CREATE TRIGGER IF NOT EXISTS evidence_delete_collection_items
  AFTER DELETE ON evidence_cards
  BEGIN
    DELETE FROM collection_items
      WHERE item_id = OLD.id AND item_kind = 'EVIDENCE';
  END
`;
const COLLECTION_DELETE_ITEMS_TRIGGER_SQL = `
  CREATE TRIGGER IF NOT EXISTS collection_delete_items
  AFTER DELETE ON collections
  BEGIN
    DELETE FROM collection_items WHERE collection_id = OLD.id;
  END
`;
const COLLECTION_UPDATED_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS collection_updated_index ON collections(updated_at DESC)';
const COLLECTION_ITEM_COLLECTION_INDEX_SQL =
  'CREATE INDEX IF NOT EXISTS collection_item_collection_index ON collection_items(collection_id)';
const DELETE_ORPHAN_EVIDENCE_SQL =
  'DELETE FROM evidence_cards WHERE document_id NOT IN (SELECT id FROM documents)';
const DELETE_ORPHAN_COLLECTION_ITEMS_SQL = `
  DELETE FROM collection_items
  WHERE collection_id NOT IN (SELECT id FROM collections)
    OR item_kind NOT IN ('DOCUMENT', 'EVIDENCE')
    OR (item_kind = 'DOCUMENT' AND item_id NOT IN (SELECT id FROM documents))
    OR (item_kind = 'EVIDENCE' AND item_id NOT IN (SELECT id FROM evidence_cards))
`;

export class YueJiDatabase {
  private store: relationalStore.RdbStore | undefined;
  private schemaVersion: number = 0;

  async initialize(context: Context): Promise<void> {
    if (this.store !== undefined) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: DATABASE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store = await relationalStore.getRdbStore(context, config);
    await store.executeSql(SCHEMA_META_TABLE_SQL);
    await store.executeSql(DOCUMENT_TABLE_SQL);
    await store.executeSql(EVIDENCE_TABLE_SQL);
    await store.executeSql(COLLECTION_TABLE_SQL);
    await store.executeSql(COLLECTION_ITEM_TABLE_SQL);
    await store.executeSql(EVIDENCE_DOCUMENT_INDEX_SQL);
    await store.executeSql(EVIDENCE_STATUS_INDEX_SQL);
    await store.executeSql(EVIDENCE_NEXT_REVIEW_INDEX_SQL);
    await store.executeSql(EVIDENCE_UPDATED_INDEX_SQL);
    await store.executeSql(DOCUMENT_RECENT_INDEX_SQL);
    await store.executeSql(DOCUMENT_FAVORITE_INDEX_SQL);
    await store.executeSql(DOCUMENT_DELETE_TRIGGER_SQL);
    await store.executeSql(DOCUMENT_DELETE_COLLECTION_TRIGGER_SQL);
    await store.executeSql(EVIDENCE_DELETE_COLLECTION_TRIGGER_SQL);
    await store.executeSql(COLLECTION_DELETE_ITEMS_TRIGGER_SQL);
    await store.executeSql(COLLECTION_UPDATED_INDEX_SQL);
    await store.executeSql(COLLECTION_ITEM_COLLECTION_INDEX_SQL);
    await store.executeSql(DELETE_ORPHAN_EVIDENCE_SQL);
    await store.executeSql(DELETE_ORPHAN_COLLECTION_ITEMS_SQL);
    const recordedVersion = await this.readSchemaVersion(store);
    if (recordedVersion > DATABASE_SCHEMA_VERSION) {
      throw new Error(`Unsupported database schema version ${recordedVersion}`);
    }
    if (recordedVersion < DATABASE_SCHEMA_VERSION) {
      await this.migrateToCurrentVersion(store, recordedVersion);
      await store.executeSql(
        `INSERT OR REPLACE INTO schema_meta (key, value) VALUES ('schema_version', '${DATABASE_SCHEMA_VERSION}')`
      );
    }
    this.schemaVersion = DATABASE_SCHEMA_VERSION;
    this.store = store;
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === undefined) {
      throw new Error('Database has not been initialized');
    }
    return this.store;
  }

  getSchemaVersion(): number {
    return this.schemaVersion;
  }

  private async readSchemaVersion(store: relationalStore.RdbStore): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('schema_meta');
    predicates.equalTo('key', 'schema_version');
    const resultSet = await store.query(predicates);
    try {
      if (!resultSet.goToFirstRow()) {
        return 0;
      }
      const value = resultSet.getString(resultSet.getColumnIndex('value'));
      const version = Number.parseInt(value, 10);
      return Number.isFinite(version) ? version : 0;
    } finally {
      resultSet.close();
    }
  }

  private async migrateToCurrentVersion(
    store: relationalStore.RdbStore,
    fromVersion: number
  ): Promise<void> {
    if (fromVersion < 2) {
      // Version 2 formalizes the indexes, cleanup rules and schema marker used by release upgrades.
      await store.executeSql(EVIDENCE_DOCUMENT_INDEX_SQL);
      await store.executeSql(EVIDENCE_STATUS_INDEX_SQL);
      await store.executeSql(EVIDENCE_NEXT_REVIEW_INDEX_SQL);
      await store.executeSql(EVIDENCE_UPDATED_INDEX_SQL);
      await store.executeSql(DOCUMENT_RECENT_INDEX_SQL);
      await store.executeSql(DOCUMENT_FAVORITE_INDEX_SQL);
      await store.executeSql(COLLECTION_UPDATED_INDEX_SQL);
      await store.executeSql(COLLECTION_ITEM_COLLECTION_INDEX_SQL);
      await store.executeSql(DELETE_ORPHAN_EVIDENCE_SQL);
      await store.executeSql(DELETE_ORPHAN_COLLECTION_ITEMS_SQL);
    }
    if (fromVersion < 3) {
      await this.addColumnIfMissing(store, 'documents', 'content_hash', "TEXT NOT NULL DEFAULT ''");
      await this.addColumnIfMissing(store, 'evidence_cards', 'last_reviewed_at', 'INTEGER NOT NULL DEFAULT 0');
      await this.addColumnIfMissing(store, 'evidence_cards', 'next_review_at', 'INTEGER NOT NULL DEFAULT 0');
      await this.addColumnIfMissing(store, 'evidence_cards', 'review_count', 'INTEGER NOT NULL DEFAULT 0');
      await store.executeSql(EVIDENCE_NEXT_REVIEW_INDEX_SQL);
    }
  }

  private async addColumnIfMissing(
    store: relationalStore.RdbStore,
    tableName: string,
    columnName: string,
    columnDefinition: string
  ): Promise<void> {
    const resultSet = await store.querySql(`PRAGMA table_info(${tableName})`);
    let exists = false;
    try {
      if (resultSet.goToFirstRow()) {
        do {
          if (resultSet.getString(resultSet.getColumnIndex('name')) === columnName) {
            exists = true;
            break;
          }
        } while (resultSet.goToNextRow());
      }
    } finally {
      resultSet.close();
    }
    if (!exists) {
      await store.executeSql(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${columnDefinition}`);
    }
  }
}
