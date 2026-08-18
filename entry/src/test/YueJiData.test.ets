import { describe, expect, it } from '@ohos/hypium';
import {
  AppSettings,
  BACKUP_SCHEMA_VERSION,
  BackupPayload,
  CollectionItem,
  CollectionRecord,
  DocumentKind,
  DocumentRecord,
  EvidenceCard,
  EvidenceKind,
  isValidStoredSelectionJson,
  normalizeTags,
  ReviewStatus,
  uniqueIds
} from '../main/ets/model/Models';
import { BackupService } from '../main/ets/services/BackupService';
import { BackupValidator } from '../main/ets/services/BackupValidator';
import {
  DataHealthIssue,
  DataHealthReport,
  DataHealthService
} from '../main/ets/services/DataHealthService';
import { DiagnosticService } from '../main/ets/services/DiagnosticService';
import { ReviewScheduler } from '../main/ets/services/ReviewScheduler';

interface BackupDocumentWithoutNewFields {
  id: string;
  kind: DocumentKind;
  title: string;
  source: string;
  pageCount: number;
  currentPage: number;
  tags: string;
  favorite: boolean;
  excerpt: string;
  note: string;
  createdAt: number;
  lastReadAt: number;
}

interface BackupEvidenceWithoutNewFields {
  id: string;
  documentId: string;
  quote: string;
  pageIndex: number;
  rectsJson: string;
  note: string;
  kind: EvidenceKind;
  color: number;
  tags: string;
  reviewStatus: ReviewStatus;
  createdAt: number;
  updatedAt: number;
}

interface BackupPayloadWithoutNewFields {
  schemaVersion: number;
  exportedAt: number;
  documents: BackupDocumentWithoutNewFields[];
  evidenceCards: BackupEvidenceWithoutNewFields[];
  collections: CollectionRecord[];
  collectionItems: CollectionItem[];
  settings: AppSettings;
}

function createDocument(id: string = 'document-1'): DocumentRecord {
  return {
    id: id,
    kind: 'PDF',
    title: '测试论文',
    source: '/data/storage/el2/base/files/library/document-1/source.pdf',
    pageCount: 3,
    currentPage: 1,
    tags: '论文, 课程',
    favorite: true,
    excerpt: '',
    note: '',
    contentHash: '',
    createdAt: 1000,
    lastReadAt: 2000
  };
}

function createEvidence(documentId: string = 'document-1'): EvidenceCard {
  return {
    id: 'evidence-1',
    documentId: documentId,
    quote: '一段可追溯的原文',
    pageIndex: 1,
    rectsJson: '[{"pageIndex":1,"isRotated":0,"rectArray":' +
      '[{"left":10,"top":20,"right":80,"bottom":40}]}]',
    note: '复习笔记',
    kind: 'HIGHLIGHT',
    color: 0xFFFFD95A,
    tags: '论文',
    reviewStatus: 'TO_REVIEW',
    lastReviewedAt: 0,
    nextReviewAt: 0,
    reviewCount: 0,
    createdAt: 2000,
    updatedAt: 3000
  };
}

function createWebDocument(): DocumentRecord {
  return {
    id: 'web-1',
    kind: 'WEB',
    title: '网页资料',
    source: 'https://example.com/article',
    pageCount: 0,
    currentPage: 0,
    tags: '课程',
    favorite: false,
    excerpt: '网页中的一段摘录',
    note: '网页笔记',
    contentHash: '',
    createdAt: 1000,
    lastReadAt: 2000
  };
}

function createWebEvidence(): EvidenceCard {
  return {
    id: 'web-evidence-1',
    documentId: 'web-1',
    quote: '网页中的一段摘录',
    pageIndex: 0,
    rectsJson: '[]',
    note: '网页笔记',
    kind: 'QUOTE',
    color: 0xFFFFD95A,
    tags: '课程',
    reviewStatus: 'TO_REVIEW',
    lastReviewedAt: 0,
    nextReviewAt: 0,
    reviewCount: 0,
    createdAt: 2000,
    updatedAt: 3000
  };
}

function createCollection(): CollectionRecord {
  return {
    id: 'collection-1',
    name: '课程研究',
    description: '跨资料主题',
    createdAt: 1000,
    updatedAt: 2000
  };
}

function createCollectionItem(itemId: string, itemKind: 'DOCUMENT' | 'EVIDENCE'): CollectionItem {
  return {
    collectionId: 'collection-1',
    itemId: itemId,
    itemKind: itemKind,
    createdAt: 3000
  };
}

function createSettings(): AppSettings {
  return {
    darkMode: false,
    focusMode: false,
    leftSidebarOpen: true,
    rightSidebarOpen: true,
    defaultHighlightColor: 0xFFFFD95A
  };
}

function createPayload(): BackupPayload {
  return {
    schemaVersion: BACKUP_SCHEMA_VERSION,
    exportedAt: 4000,
    documents: [createDocument()],
    evidenceCards: [createEvidence()],
    collections: [createCollection()],
    collectionItems: [
      createCollectionItem('document-1', 'DOCUMENT'),
      createCollectionItem('evidence-1', 'EVIDENCE')
    ],
    settings: createSettings()
  };
}

function createPayloadWithoutNewFields(schemaVersion: number): BackupPayloadWithoutNewFields {
  const payload = createPayload();
  const document = payload.documents[0];
  const card = payload.evidenceCards[0];
  return {
    schemaVersion: schemaVersion,
    exportedAt: payload.exportedAt,
    documents: [{
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
      createdAt: document.createdAt,
      lastReadAt: document.lastReadAt
    }],
    evidenceCards: [{
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
      createdAt: card.createdAt,
      updatedAt: card.updatedAt
    }],
    collections: payload.collections,
    collectionItems: payload.collectionItems,
    settings: payload.settings
  };
}

export default function yueJiDataTest(): void {
  describe('YueJiDataIntegrity', (): void => {
    it('normalizes tags case-insensitively and keeps first spelling', 0, (): void => {
      expect(normalizeTags('论文, 课程, 论文, 课 程,  COURSE, course'))
        .assertEqual('论文, 课程, 课 程, COURSE');
    });

    it('keeps unique non-empty ids in source order', 0, (): void => {
      const ids = uniqueIds(['e-2', '', 'e-1', 'e-2', 'e-3', 'e-1']);
      expect(ids.length).assertEqual(3);
      expect(ids[0]).assertEqual('e-2');
      expect(ids[1]).assertEqual('e-1');
      expect(ids[2]).assertEqual('e-3');
    });

    it('puts new unscheduled review cards into the queue immediately', 0, (): void => {
      const card = createEvidence();
      expect(new ReviewScheduler().isDue(card, 5000)).assertTrue();
    });

    it('defers a pending card for one day and preserves that date during edits', 0, (): void => {
      const scheduler = new ReviewScheduler();
      const card = createEvidence();
      const updatedAt = 1000000;
      const deferred = scheduler.deferValues(card, updatedAt);
      card.nextReviewAt = deferred.nextReviewAt;

      expect(deferred.nextReviewAt).assertEqual(updatedAt + 24 * 60 * 60 * 1000);
      expect(scheduler.isDue(card, updatedAt)).assertFalse();
      expect(scheduler.isDue(card, deferred.nextReviewAt)).assertTrue();
      expect(scheduler.valuesForEdit(card, 'TO_REVIEW', updatedAt + 1000).nextReviewAt)
        .assertEqual(deferred.nextReviewAt);
    });

    it('returns mastered cards to the queue when their review date arrives', 0, (): void => {
      const card = createEvidence();
      card.reviewStatus = 'MASTERED';
      card.lastReviewedAt = 1000;
      card.nextReviewAt = 5000;
      card.reviewCount = 1;

      const scheduler = new ReviewScheduler();
      expect(scheduler.isDue(card, 4999)).assertFalse();
      expect(scheduler.isDue(card, 5000)).assertTrue();
    });

    it('uses 1, 3, 7 and 14 day intervals as mastery reviews accumulate', 0, (): void => {
      const scheduler = new ReviewScheduler();
      const card = createEvidence();
      const day = 24 * 60 * 60 * 1000;
      let reviewedAt = 1000000;
      let schedule = scheduler.valuesForReviewAction(card, 'MASTERED', reviewedAt);
      expect(schedule.reviewCount).assertEqual(1);
      expect(schedule.nextReviewAt).assertEqual(reviewedAt + day);

      card.reviewStatus = 'MASTERED';
      card.lastReviewedAt = schedule.lastReviewedAt;
      card.nextReviewAt = schedule.nextReviewAt;
      card.reviewCount = schedule.reviewCount;
      reviewedAt = schedule.nextReviewAt;
      schedule = scheduler.valuesForReviewAction(card, 'MASTERED', reviewedAt);
      expect(schedule.reviewCount).assertEqual(2);
      expect(schedule.nextReviewAt).assertEqual(reviewedAt + 3 * day);

      card.lastReviewedAt = schedule.lastReviewedAt;
      card.nextReviewAt = schedule.nextReviewAt;
      card.reviewCount = schedule.reviewCount;
      reviewedAt = schedule.nextReviewAt;
      schedule = scheduler.valuesForReviewAction(card, 'MASTERED', reviewedAt);
      expect(schedule.reviewCount).assertEqual(3);
      expect(schedule.nextReviewAt).assertEqual(reviewedAt + 7 * day);

      card.lastReviewedAt = schedule.lastReviewedAt;
      card.nextReviewAt = schedule.nextReviewAt;
      card.reviewCount = schedule.reviewCount;
      reviewedAt = schedule.nextReviewAt;
      schedule = scheduler.valuesForReviewAction(card, 'MASTERED', reviewedAt);
      expect(schedule.reviewCount).assertEqual(4);
      expect(schedule.nextReviewAt).assertEqual(reviewedAt + 14 * day);
    });

    it('does not count an early repeated mastery action as another review', 0, (): void => {
      const scheduler = new ReviewScheduler();
      const card = createEvidence();
      card.reviewStatus = 'MASTERED';
      card.lastReviewedAt = 1000;
      card.nextReviewAt = 1000 + 24 * 60 * 60 * 1000;
      card.reviewCount = 1;

      const schedule = scheduler.valuesForReviewAction(card, 'MASTERED', 2000);
      expect(schedule.lastReviewedAt).assertEqual(card.lastReviewedAt);
      expect(schedule.nextReviewAt).assertEqual(card.nextReviewAt);
      expect(schedule.reviewCount).assertEqual(1);
    });

    it('does not count editing an overdue mastered card as a review', 0, (): void => {
      const scheduler = new ReviewScheduler();
      const card = createEvidence();
      card.reviewStatus = 'MASTERED';
      card.lastReviewedAt = 1000;
      card.nextReviewAt = 2000;
      card.reviewCount = 2;

      const schedule = scheduler.valuesForEdit(card, 'MASTERED', 5000);
      expect(schedule.lastReviewedAt).assertEqual(1000);
      expect(schedule.nextReviewAt).assertEqual(2000);
      expect(schedule.reviewCount).assertEqual(2);
    });

    it('records mastery selected while editing a pending card', 0, (): void => {
      const scheduler = new ReviewScheduler();
      const card = createEvidence();
      const reviewedAt = 5000;

      const schedule = scheduler.valuesForEdit(card, 'MASTERED', reviewedAt);
      expect(schedule.lastReviewedAt).assertEqual(reviewedAt);
      expect(schedule.reviewCount).assertEqual(1);
      expect(schedule.nextReviewAt).assertEqual(reviewedAt + 24 * 60 * 60 * 1000);
    });

    it('accepts valid stored PDF selections and rejects empty or broken selections', 0, (): void => {
      expect(isValidStoredSelectionJson(
        '[{"pageIndex":0,"isRotated":0,"rectArray":' +
        '[{"left":1,"top":2,"right":3,"bottom":4}]}]'
      )).assertTrue();
      expect(isValidStoredSelectionJson('[]')).assertFalse();
      expect(isValidStoredSelectionJson(
        '[{"pageIndex":-1,"isRotated":0,"rectArray":' +
        '[{"left":1,"top":2,"right":3,"bottom":4}]}]'
      )).assertFalse();
      expect(isValidStoredSelectionJson(
        '[{"pageIndex":0,"isRotated":0,"rectArray":' +
        '[{"left":5,"top":2,"right":3,"bottom":4}]}]'
      )).assertFalse();
    });

    it('accepts a complete versioned backup', 0, (): void => {
      const result = new BackupValidator().validateJson(JSON.stringify(createPayload()));
      expect(result.valid).assertTrue();
      expect(result.payload?.documents.length).assertEqual(1);
      expect(result.payload?.collectionItems.length).assertEqual(2);
    });

    it('accepts legacy backups and fills fields during normalization', 0, (): void => {
      const legacy = createPayloadWithoutNewFields(1);
      const result = new BackupValidator().validateJson(JSON.stringify(legacy));
      expect(result.valid).assertTrue();
      expect(result.payload !== undefined).assertTrue();
      const normalized = new BackupService().normalizePayload(
        result.payload as BackupPayload,
        '/data/current/files'
      );
      expect(normalized.schemaVersion).assertEqual(BACKUP_SCHEMA_VERSION);
      expect(normalized.documents[0].contentHash).assertEqual('');
      expect(normalized.evidenceCards[0].lastReviewedAt).assertEqual(0);
      expect(normalized.evidenceCards[0].nextReviewAt).assertEqual(0);
      expect(normalized.evidenceCards[0].reviewCount).assertEqual(0);
    });

    it('rejects current backups when newly required fields are missing', 0, (): void => {
      const current = createPayloadWithoutNewFields(BACKUP_SCHEMA_VERSION);
      expect(new BackupValidator().validateJson(JSON.stringify(current)).valid).assertFalse();
    });

    it('accepts web documents with quote cards that have no PDF geometry', 0, (): void => {
      const payload = createPayload();
      payload.documents = [createWebDocument()];
      payload.evidenceCards = [createWebEvidence()];
      payload.collectionItems = [
        createCollectionItem('web-1', 'DOCUMENT'),
        createCollectionItem('web-evidence-1', 'EVIDENCE')
      ];
      const result = new BackupValidator().validateJson(JSON.stringify(payload));
      expect(result.valid).assertTrue();
    });

    it('rejects web records that carry PDF page state', 0, (): void => {
      const payload = createPayload();
      payload.documents = [createWebDocument()];
      payload.documents[0].pageCount = 1;
      expect(new BackupValidator().validateJson(JSON.stringify(payload)).valid).assertFalse();
    });

    it('rejects unsupported backup versions and duplicate document ids', 0, (): void => {
      const versioned = createPayload();
      versioned.schemaVersion = BACKUP_SCHEMA_VERSION + 1;
      expect(new BackupValidator().validateJson(JSON.stringify(versioned)).valid).assertFalse();

      const duplicated = createPayload();
      duplicated.documents.push(createDocument('document-1'));
      expect(new BackupValidator().validateJson(JSON.stringify(duplicated)).valid).assertFalse();
    });

    it('rejects orphan evidence cards', 0, (): void => {
      const payload = createPayload();
      payload.evidenceCards[0].documentId = 'missing-document';
      expect(new BackupValidator().validateJson(JSON.stringify(payload)).valid).assertFalse();
    });

    it('rejects duplicate and orphan collection associations', 0, (): void => {
      const duplicated = createPayload();
      duplicated.collectionItems.push(createCollectionItem('document-1', 'DOCUMENT'));
      expect(new BackupValidator().validateJson(JSON.stringify(duplicated)).valid).assertFalse();

      const orphaned = createPayload();
      orphaned.collectionItems[0].itemId = 'missing-document';
      expect(new BackupValidator().validateJson(JSON.stringify(orphaned)).valid).assertFalse();
    });

    it('rejects duplicate collection names regardless of case', 0, (): void => {
      const payload = createPayload();
      payload.collections.push({
        id: 'collection-2',
        name: '  课程研究 ',
        description: '',
        createdAt: 1100,
        updatedAt: 1200
      });
      expect(new BackupValidator().validateJson(JSON.stringify(payload)).valid).assertFalse();
    });

    it('normalizes PDF backup paths for the current device without changing web sources', 0, (): void => {
      const payload = createPayload();
      payload.documents.push(createWebDocument());
      const normalized = new BackupService().normalizePayload(payload, '/data/current/files');

      expect(normalized.documents[0].source)
        .assertEqual('/data/current/files/library/document-1/source.pdf');
      expect(normalized.documents[1].source).assertEqual('https://example.com/article');
      expect(payload.documents[0].source)
        .assertEqual('/data/storage/el2/base/files/library/document-1/source.pdf');
    });

    it('reports broken evidence, selection, page, collection and web relations', 0, (): void => {
      const documents: DocumentRecord[] = [createDocument(), createWebDocument()];
      documents[1].source = 'example.com/article';
      const evidenceCards: EvidenceCard[] = [createEvidence(), createEvidence('missing-document')];
      evidenceCards[0].pageIndex = 4;
      evidenceCards[0].rectsJson = 'broken-selection';
      const collections: CollectionRecord[] = [createCollection()];
      const collectionItems: CollectionItem[] = [
        createCollectionItem('missing-document', 'DOCUMENT'),
        createCollectionItem('evidence-1', 'EVIDENCE')
      ];
      collectionItems[1].collectionId = 'missing-collection';

      const issues = new DataHealthService().inspectRecords(
        documents, evidenceCards, collections, collectionItems);
      const codes: string[] = issues.map((issue: DataHealthIssue): string => issue.code);

      expect(codes.includes('INVALID_WEB_SOURCE')).assertTrue();
      expect(codes.includes('PAGE_OUT_OF_RANGE')).assertTrue();
      expect(codes.includes('INVALID_SELECTION')).assertTrue();
      expect(codes.includes('ORPHAN_EVIDENCE')).assertTrue();
      expect(codes.includes('ORPHAN_COLLECTION_ITEM')).assertTrue();
    });

    it('serializes diagnostics without document content or source URLs', 0, (): void => {
      const report: DataHealthReport = {
        checkedAt: 5000,
        issues: [],
        issueCount: 0,
        missingPdfCount: 0,
        orphanFileCount: 0,
        invalidSelectionCount: 0,
        orphanRelationCount: 0
      };
      const snapshot = new DiagnosticService().buildSnapshot(
        2,
        [createDocument(), createWebDocument()],
        [createEvidence()],
        [createCollection()],
        [createCollectionItem('document-1', 'DOCUMENT')],
        report
      );
      const json = new DiagnosticService().serialize(snapshot);

      expect(json.includes('测试论文')).assertFalse();
      expect(json.includes('一段可追溯的原文')).assertFalse();
      expect(json.includes('https://example.com/article')).assertFalse();
      expect(json.includes('documentCount')).assertTrue();
      expect(json.includes('databaseSchemaVersion')).assertTrue();
    });
  });
}
