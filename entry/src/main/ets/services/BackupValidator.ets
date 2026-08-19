import {
  AppSettings,
  BACKUP_SCHEMA_VERSION,
  BackupPayload,
  CollectionItem,
  CollectionRecord,
  isCollectionItemKind,
  isDocumentKind,
  isEvidenceKind,
  isReviewStatus,
  LEGACY_BACKUP_SCHEMA_VERSION,
  MAX_BACKUP_FILE_SIZE,
  MAX_COLLECTION_DESCRIPTION_LENGTH,
  MAX_COLLECTION_NAME_LENGTH,
  MAX_EXCERPT_LENGTH,
  MAX_NOTE_LENGTH,
  MAX_QUOTE_LENGTH,
  MAX_TAGS_LENGTH,
  MAX_TITLE_LENGTH,
  MAX_URL_LENGTH,
  validateEvidenceSource
} from '../model/Models';
import { isValidHttpUrl } from './UrlValidation';

export interface BackupValidationResult {
  valid: boolean;
  message: string;
  payload?: BackupPayload;
}

interface BackupDocumentInput {
  id: string;
  kind: string;
  title: string;
  source: string;
  pageCount: number;
  currentPage: number;
  tags: string;
  favorite: boolean;
  excerpt: string;
  note: string;
  contentHash?: string;
  createdAt: number;
  lastReadAt: number;
}

interface BackupEvidenceInput {
  id: string;
  documentId: string;
  quote: string;
  pageIndex: number;
  rectsJson: string;
  note: string;
  kind: string;
  color: number;
  tags: string;
  reviewStatus: string;
  lastReviewedAt?: number;
  nextReviewAt?: number;
  reviewCount?: number;
  createdAt: number;
  updatedAt: number;
}

interface BackupPayloadInput {
  schemaVersion: number;
  exportedAt: number;
  documents: BackupDocumentInput[];
  evidenceCards: BackupEvidenceInput[];
  collections: CollectionRecord[];
  collectionItems: CollectionItem[];
  settings: AppSettings;
}

export class BackupValidator {
  validateJson(json: string): BackupValidationResult {
    if (json.length === 0) {
      return { valid: false, message: '备份文件为空' };
    }
    if (json.length > MAX_BACKUP_FILE_SIZE) {
      return { valid: false, message: '备份文件超过 20 MB，已拒绝导入' };
    }
    let value: BackupPayloadInput;
    try {
      value = JSON.parse(json) as BackupPayloadInput;
    } catch (error) {
      return { valid: false, message: '备份文件不是有效 JSON' };
    }
    try {
      const root = value;
      if (root === undefined || root === null ||
        (root.schemaVersion !== BACKUP_SCHEMA_VERSION &&
          root.schemaVersion !== LEGACY_BACKUP_SCHEMA_VERSION)) {
        return {
          valid: false,
          message: `暂不支持备份版本 ${root === undefined || root === null ? '未知' : root.schemaVersion}`
        };
      }
      if (!this.isTimestamp(root.exportedAt) ||
        !Array.isArray(root.documents) ||
        !Array.isArray(root.evidenceCards) ||
        !Array.isArray(root.collections) ||
        !Array.isArray(root.collectionItems) ||
        root.settings === undefined ||
        root.settings === null) {
        return { valid: false, message: '备份文件结构不完整' };
      }
      const allowLegacyFields = root.schemaVersion === LEGACY_BACKUP_SCHEMA_VERSION;
      if (!this.validateDocuments(root.documents, allowLegacyFields)) {
        return { valid: false, message: '备份中的资料记录无效' };
      }
      if (!this.validateEvidenceCards(root.evidenceCards, root.documents, allowLegacyFields)) {
        return { valid: false, message: '备份中的证据卡无效或来源不存在' };
      }
      if (!this.validateCollections(root.collections)) {
        return { valid: false, message: '备份中的主题集合无效' };
      }
      if (!this.validateCollectionItems(root.collectionItems, root.documents, root.evidenceCards, root.collections)) {
        return { valid: false, message: '备份中的集合关联无效' };
      }
      if (!this.validateSettings(root.settings)) {
        return { valid: false, message: '备份中的界面设置无效' };
      }
      return { valid: true, message: '备份校验通过', payload: root as BackupPayload };
    } catch (error) {
      return { valid: false, message: '备份文件包含无法识别的数据' };
    }
  }

  private validateDocuments(documents: BackupDocumentInput[], allowMissingNewFields: boolean): boolean {
    const ids: string[] = [];
    return documents.every((document: BackupDocumentInput): boolean => {
      if (typeof document.id !== 'string' ||
        typeof document.kind !== 'string' ||
        typeof document.title !== 'string' ||
        typeof document.source !== 'string' ||
        typeof document.tags !== 'string' ||
        typeof document.excerpt !== 'string' ||
        typeof document.note !== 'string' ||
        !this.validContentHash(document.contentHash, allowMissingNewFields) ||
        typeof document.favorite !== 'boolean' ||
        typeof document.pageCount !== 'number' ||
        typeof document.currentPage !== 'number' ||
        typeof document.createdAt !== 'number' ||
        typeof document.lastReadAt !== 'number' ||
        !this.uniqueAndNonEmpty(ids, document.id) ||
        !isDocumentKind(document.kind) ||
        document.title.length === 0 ||
        document.title.length > MAX_TITLE_LENGTH ||
        document.source.length === 0 ||
        document.source.length > MAX_URL_LENGTH ||
        !Number.isInteger(document.pageCount) ||
        document.pageCount < 0 ||
        !Number.isInteger(document.currentPage) ||
        document.currentPage < 0 ||
        document.currentPage > Math.max(0, document.pageCount - 1) ||
        document.tags.length > MAX_TAGS_LENGTH ||
        document.excerpt.length > MAX_EXCERPT_LENGTH ||
        document.note.length > MAX_NOTE_LENGTH ||
        !this.isTimestamp(document.createdAt) ||
        !this.isTimestamp(document.lastReadAt)) {
        return false;
      }
      if (document.kind === 'WEB' && !isValidHttpUrl(document.source, false)) {
        return false;
      }
      if (document.kind === 'WEB' && (document.pageCount !== 0 || document.currentPage !== 0)) {
        return false;
      }
      return true;
    });
  }

  private validateEvidenceCards(
    cards: BackupEvidenceInput[],
    documents: BackupDocumentInput[],
    allowMissingNewFields: boolean
  ): boolean {
    const ids: string[] = [];
    return cards.every((card: BackupEvidenceInput): boolean => {
      if (typeof card.id !== 'string' ||
        typeof card.documentId !== 'string' ||
        typeof card.quote !== 'string' ||
        typeof card.rectsJson !== 'string' ||
        typeof card.note !== 'string' ||
        typeof card.kind !== 'string' ||
        typeof card.tags !== 'string' ||
        typeof card.reviewStatus !== 'string' ||
        typeof card.pageIndex !== 'number' ||
        typeof card.color !== 'number' ||
        typeof card.createdAt !== 'number' ||
        typeof card.updatedAt !== 'number' ||
        !this.isReviewValue(card.lastReviewedAt, allowMissingNewFields) ||
        !this.isReviewValue(card.nextReviewAt, allowMissingNewFields) ||
        !this.isReviewValue(card.reviewCount, allowMissingNewFields) ||
        !this.uniqueAndNonEmpty(ids, card.id) ||
        !documents.some((document: BackupDocumentInput): boolean => document.id === card.documentId) ||
        card.quote.length === 0 ||
        card.quote.length > MAX_QUOTE_LENGTH ||
        !Number.isInteger(card.pageIndex) ||
        card.pageIndex < 0 ||
        card.note.length > MAX_NOTE_LENGTH ||
        card.tags.length > MAX_TAGS_LENGTH ||
        !isEvidenceKind(card.kind) ||
        !isReviewStatus(card.reviewStatus) ||
        !Number.isInteger(card.color) ||
        card.color < 0 ||
        card.color > 0xFFFFFFFF ||
        !this.isTimestamp(card.createdAt) ||
        !this.isTimestamp(card.updatedAt) ||
        card.updatedAt < card.createdAt) {
        return false;
      }
      const document = documents.find((item: BackupDocumentInput): boolean => item.id === card.documentId);
      if (document === undefined) {
        return false;
      }
      const sourceValidation = validateEvidenceSource(
        document.kind,
        document.pageCount,
        card.kind,
        card.pageIndex,
        card.rectsJson
      );
      return sourceValidation.sourceCompatible &&
        sourceValidation.selectionValid &&
        sourceValidation.pageInRange;
    });
  }

  private validateCollections(collections: CollectionRecord[]): boolean {
    const ids: string[] = [];
    const names: string[] = [];
    return collections.every((collection: CollectionRecord): boolean =>
      typeof collection.id === 'string' &&
      typeof collection.name === 'string' &&
      typeof collection.description === 'string' &&
      typeof collection.createdAt === 'number' &&
      typeof collection.updatedAt === 'number' &&
      this.uniqueAndNonEmpty(ids, collection.id) &&
      this.uniqueAndNonEmpty(names, collection.name.trim().toLocaleLowerCase()) &&
      collection.name.trim().length > 0 &&
      collection.name.length <= MAX_COLLECTION_NAME_LENGTH &&
      collection.description.length <= MAX_COLLECTION_DESCRIPTION_LENGTH &&
      this.isTimestamp(collection.createdAt) &&
      this.isTimestamp(collection.updatedAt) &&
      collection.updatedAt >= collection.createdAt);
  }

  private validateCollectionItems(
    items: CollectionItem[],
    documents: BackupDocumentInput[],
    cards: BackupEvidenceInput[],
    collections: CollectionRecord[]
  ): boolean {
    const seenItems: CollectionItem[] = [];
    return items.every((item: CollectionItem): boolean => {
      if (typeof item.collectionId !== 'string' ||
        typeof item.itemId !== 'string' ||
        typeof item.itemKind !== 'string' ||
        typeof item.createdAt !== 'number') {
        return false;
      }
      const duplicated = seenItems.some((seen: CollectionItem): boolean =>
        seen.collectionId === item.collectionId &&
        seen.itemId === item.itemId &&
        seen.itemKind === item.itemKind);
      if (duplicated ||
        item.itemId.length === 0 ||
        !collections.some((collection: CollectionRecord): boolean => collection.id === item.collectionId) ||
        !isCollectionItemKind(item.itemKind) ||
        !this.isTimestamp(item.createdAt)) {
        return false;
      }
      seenItems.push(item);
      return item.itemKind === 'DOCUMENT' ?
        documents.some((document: BackupDocumentInput): boolean => document.id === item.itemId) :
        cards.some((card: BackupEvidenceInput): boolean => card.id === item.itemId);
    });
  }

  private validateSettings(settings: AppSettings): boolean {
    return typeof settings.darkMode === 'boolean' &&
      typeof settings.focusMode === 'boolean' &&
      typeof settings.leftSidebarOpen === 'boolean' &&
      typeof settings.rightSidebarOpen === 'boolean' &&
      Number.isInteger(settings.defaultHighlightColor) &&
      settings.defaultHighlightColor >= 0 &&
      settings.defaultHighlightColor <= 0xFFFFFFFF;
  }

  private uniqueAndNonEmpty(values: string[], value: string): boolean {
    if (value.length === 0 || values.includes(value)) {
      return false;
    }
    values.push(value);
    return true;
  }

  private isTimestamp(value: number): boolean {
    return Number.isInteger(value) && value > 0;
  }

  private isReviewValue(value: number | undefined, allowMissing: boolean): boolean {
    return value === undefined ? allowMissing : Number.isInteger(value) && value >= 0;
  }

  private validContentHash(value: string | undefined, allowMissing: boolean): boolean {
    return value === undefined ? allowMissing : value.length === 0 || /^[a-f0-9]{64}$/.test(value);
  }
}
