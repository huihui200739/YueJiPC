import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import {
  AppSettings,
  BACKUP_SCHEMA_VERSION,
  BackupPayload,
  CollectionItem,
  CollectionRecord,
  DocumentRecord,
  EvidenceCard
} from '../model/Models';
import { canonicalPdfPath } from '../model/Models';
import { YueJiDatabase } from '../data/YueJiDatabase';
import { BackupValidationResult, BackupValidator } from './BackupValidator';

export interface BackupFileResult {
  uri: string;
  fileName: string;
}

export interface BackupSnapshotResult {
  path: string;
  fileName: string;
}

export interface DeletedPdfArchive {
  originalPath: string;
  archivePath: string;
}

export class BackupService {
  private validator: BackupValidator = new BackupValidator();

  buildPayload(
    documents: DocumentRecord[],
    evidenceCards: EvidenceCard[],
    collections: CollectionRecord[],
    collectionItems: CollectionItem[],
    settings: AppSettings
  ): BackupPayload {
    return {
      schemaVersion: BACKUP_SCHEMA_VERSION,
      exportedAt: Date.now(),
      documents: documents,
      evidenceCards: evidenceCards,
      collections: collections,
      collectionItems: collectionItems,
      settings: settings
    };
  }

  serialize(payload: BackupPayload): string {
    return `${JSON.stringify(payload, null, 2)}\n`;
  }

  validateJson(json: string): BackupValidationResult {
    return this.validator.validateJson(json);
  }

  async chooseAndRead(context: Context): Promise<BackupPayload | undefined> {
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.select({
      fileSuffixFilters: ['JSON|.json'],
      maxSelectNumber: 1
    });
    if (uris.length === 0) {
      return undefined;
    }
    const json = await fs.readText(uris[0]);
    const result = this.validateJson(json);
    if (!result.valid || result.payload === undefined) {
      throw new Error(result.message);
    }
    return result.payload;
  }

  async save(context: Context, payload: BackupPayload): Promise<BackupFileResult | undefined> {
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.save({
      newFileNames: [`阅迹备份-${this.dateStamp()}.json`],
      fileSuffixChoices: ['JSON|.json']
    });
    if (uris.length === 0) {
      return undefined;
    }
    const json = this.serialize(payload);
    const file = await fs.open(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      await fs.write(file.fd, json);
    } finally {
      await fs.close(file);
    }
    return {
      uri: uris[0],
      fileName: this.fileNameFromUri(uris[0], '阅迹备份.json')
    };
  }

  async savePreRestoreSnapshot(context: Context, payload: BackupPayload): Promise<BackupSnapshotResult> {
    return this.saveLocalSnapshot(context, payload, 'pre-restore');
  }

  async savePreDeleteSnapshot(context: Context, payload: BackupPayload): Promise<BackupSnapshotResult> {
    return this.saveLocalSnapshot(context, payload, 'pre-delete');
  }

  async archivePdfForDelete(
    context: Context,
    document: DocumentRecord
  ): Promise<DeletedPdfArchive | undefined> {
    if (document.kind !== 'PDF' || !this.fileExists(document.source)) {
      return undefined;
    }
    const directory = `${context.filesDir}/backups/deleted/${document.id}-${Date.now()}`;
    const archivePath = `${directory}/source.pdf`;
    await fs.mkdir(directory, true);
    await fs.moveFile(document.source, archivePath);
    return {
      originalPath: document.source,
      archivePath: archivePath
    };
  }

  async restoreArchivedPdf(archive: DeletedPdfArchive): Promise<void> {
    if (!this.fileExists(archive.archivePath)) {
      return;
    }
    const lastSlash = archive.originalPath.lastIndexOf('/');
    if (lastSlash > 0) {
      const directory = archive.originalPath.substring(0, lastSlash);
      if (!this.directoryExists(directory)) {
        await fs.mkdir(directory, true);
      }
    }
    await fs.moveFile(archive.archivePath, archive.originalPath);
  }

  normalizePayload(payload: BackupPayload, filesDir: string): BackupPayload {
    return {
      schemaVersion: BACKUP_SCHEMA_VERSION,
      exportedAt: payload.exportedAt,
      documents: payload.documents.map((document: DocumentRecord): DocumentRecord =>
        document.kind === 'PDF' ?
          {
            id: document.id,
            kind: document.kind,
            title: document.title,
            source: canonicalPdfPath(filesDir, document.id),
            pageCount: document.pageCount,
            currentPage: document.currentPage,
            tags: document.tags,
            favorite: document.favorite,
            excerpt: document.excerpt,
            note: document.note,
            contentHash: document.contentHash ?? '',
            createdAt: document.createdAt,
            lastReadAt: document.lastReadAt
          } :
          {
            id: document.id,
            kind: document.kind,
            title: document.title,
            source: document.source,
            pageCount: document.pageCount,
            currentPage: document.currentPage,
            tags: document.tags,
            favorite: document.favorite,
            excerpt: document.excerpt,
            note: document.note,
            contentHash: document.contentHash ?? '',
            createdAt: document.createdAt,
            lastReadAt: document.lastReadAt
          }),
      evidenceCards: payload.evidenceCards.map((card: EvidenceCard): EvidenceCard => ({
        id: card.id,
        documentId: card.documentId,
        quote: card.quote,
        pageIndex: card.pageIndex,
        rectsJson: card.rectsJson,
        note: card.note,
        kind: card.kind,
        color: card.color,
        tags: card.tags,
        reviewStatus: card.reviewStatus,
        lastReviewedAt: card.lastReviewedAt ?? 0,
        nextReviewAt: card.nextReviewAt ?? 0,
        reviewCount: card.reviewCount ?? 0,
        createdAt: card.createdAt,
        updatedAt: card.updatedAt
      })),
      collections: payload.collections.map((collection: CollectionRecord): CollectionRecord => ({
        id: collection.id,
        name: collection.name,
        description: collection.description,
        createdAt: collection.createdAt,
        updatedAt: collection.updatedAt
      })),
      collectionItems: payload.collectionItems.map((item: CollectionItem): CollectionItem => ({
        collectionId: item.collectionId,
        itemId: item.itemId,
        itemKind: item.itemKind,
        createdAt: item.createdAt
      })),
      settings: {
        darkMode: payload.settings.darkMode,
        focusMode: payload.settings.focusMode,
        leftSidebarOpen: payload.settings.leftSidebarOpen,
        rightSidebarOpen: payload.settings.rightSidebarOpen,
        defaultHighlightColor: payload.settings.defaultHighlightColor
      }
    };
  }

  private async saveLocalSnapshot(
    context: Context,
    payload: BackupPayload,
    prefix: string
  ): Promise<BackupSnapshotResult> {
    const directory = `${context.filesDir}/backups`;
    if (!this.directoryExists(directory)) {
      await fs.mkdir(directory, true);
    }
    const fileName = `${prefix}-${this.dateStamp()}-${Date.now()}.json`;
    const path = `${directory}/${fileName}`;
    const file = await fs.open(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      await fs.write(file.fd, this.serialize(payload));
    } finally {
      await fs.close(file);
    }
    this.pruneSnapshots(directory, prefix, fileName);
    return { path: path, fileName: fileName };
  }

  async replaceDatabase(database: YueJiDatabase, payload: BackupPayload): Promise<void> {
    const validation = this.validateJson(this.serialize(payload));
    if (!validation.valid) {
      throw new Error(validation.message);
    }
    const store = database.getStore();
    const transactionId = await store.beginTrans();
    try {
      await store.execute('DELETE FROM collection_items', transactionId);
      await store.execute('DELETE FROM evidence_cards', transactionId);
      await store.execute('DELETE FROM documents', transactionId);
      await store.execute('DELETE FROM collections', transactionId);
      for (const record of payload.documents) {
        await store.execute(
          `INSERT INTO documents
            (id, kind, title, source, page_count, current_page, tags, favorite, excerpt, note,
             content_hash, created_at, last_read_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          transactionId,
          [
            record.id, record.kind, record.title, record.source, record.pageCount, record.currentPage,
            record.tags, record.favorite ? 1 : 0, record.excerpt, record.note, record.contentHash,
            record.createdAt, record.lastReadAt
          ]
        );
      }
      for (const card of payload.evidenceCards) {
        await store.execute(
          `INSERT INTO evidence_cards
            (id, document_id, quote, page_index, rects_json, note, kind, color, tags, review_status,
             last_reviewed_at, next_review_at, review_count, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          transactionId,
          [
            card.id, card.documentId, card.quote, card.pageIndex, card.rectsJson, card.note,
            card.kind, card.color, card.tags, card.reviewStatus, card.lastReviewedAt, card.nextReviewAt,
            card.reviewCount, card.createdAt, card.updatedAt
          ]
        );
      }
      for (const collection of payload.collections) {
        await store.execute(
          `INSERT INTO collections (id, name, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)`,
          transactionId,
          [collection.id, collection.name, collection.description, collection.createdAt, collection.updatedAt]
        );
      }
      for (const item of payload.collectionItems) {
        await store.execute(
          `INSERT INTO collection_items (collection_id, item_id, item_kind, created_at)
            VALUES (?, ?, ?, ?)`,
          transactionId,
          [item.collectionId, item.itemId, item.itemKind, item.createdAt]
        );
      }
      await store.commit(transactionId);
    } catch (error) {
      await store.rollback(transactionId);
      throw new Error('Backup database restore failed');
    }
  }

  private dateStamp(): string {
    const value = new Date();
    const month = `${value.getMonth() + 1}`.padStart(2, '0');
    const day = `${value.getDate()}`.padStart(2, '0');
    return `${value.getFullYear()}${month}${day}`;
  }

  private fileNameFromUri(uri: string, fallback: string): string {
    const cleanUri = uri.split('?')[0].split('#')[0];
    const value = cleanUri.substring(cleanUri.lastIndexOf('/') + 1);
    if (value.length === 0) {
      return fallback;
    }
    try {
      return decodeURIComponent(value);
    } catch (error) {
      return value;
    }
  }

  private directoryExists(path: string): boolean {
    try {
      return fs.statSync(path).isDirectory();
    } catch (error) {
      return false;
    }
  }

  private fileExists(path: string): boolean {
    try {
      return fs.statSync(path).isFile();
    } catch (error) {
      return false;
    }
  }

  private pruneSnapshots(directory: string, prefix: string, newestFileName: string): void {
    try {
      const files = fs.listFileSync(directory)
        .filter((fileName: string): boolean =>
          fileName.startsWith(`${prefix}-`) && fileName.endsWith('.json') &&
          fileName !== newestFileName)
        .sort();
      while (files.length > 4) {
        const oldFile = files.shift();
        if (oldFile !== undefined) {
          try {
            fs.unlinkSync(`${directory}/${oldFile}`);
          } catch (error) {
          }
        }
      }
    } catch (error) {
    }
  }
}
