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
  MAX_SEARCH_LENGTH,
  MAX_ZOOM_PERCENT,
  MIN_ZOOM_PERCENT,
  normalizeTags,
  normalizeZoomPercent,
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
import { EvidenceCardMutationService } from '../main/ets/services/EvidenceCardMutationService';
import { isValidHttpUrl, normalizeHttpUrl } from '../main/ets/services/UrlValidation';
import { ReviewFilterService } from '../main/ets/services/ReviewFilterService';
import { ReviewScheduler } from '../main/ets/services/ReviewScheduler';
import {
  TransactionFailureError,
  transactionFailure
} from '../main/ets/data/TransactionError';
import { isManagedTemporaryPath } from '../main/ets/services/StorageMaintenanceService';

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

    it('keeps the complete PDF zoom range when normalizing persisted state', 0, (): void => {
      expect(normalizeZoomPercent(MIN_ZOOM_PERCENT)).assertEqual(MIN_ZOOM_PERCENT);
      expect(normalizeZoomPercent(MAX_ZOOM_PERCENT)).assertEqual(MAX_ZOOM_PERCENT);
      expect(normalizeZoomPercent(450)).assertEqual(MAX_ZOOM_PERCENT);
      expect(normalizeZoomPercent(49)).assertEqual(MIN_ZOOM_PERCENT);
      expect(normalizeZoomPercent(274.6)).assertEqual(275);
      expect(normalizeZoomPercent(Number.POSITIVE_INFINITY, 320)).assertEqual(320);
    });

    it('uses one strict HTTP URL rule for input and persisted sources', 0, (): void => {
      expect(normalizeHttpUrl('  example.com/article  ')).assertEqual('https://example.com/article');
      expect(isValidHttpUrl('example.com/article')).assertTrue();
      expect(isValidHttpUrl('HTTPS://Example.com/article', false)).assertTrue();
      expect(isValidHttpUrl('https://localhost:8080', false)).assertTrue();
      expect(isValidHttpUrl('https://192.168.1.10:443/read', false)).assertTrue();
      expect(isValidHttpUrl('https://', false)).assertFalse();
      expect(isValidHttpUrl('example.com/article', false)).assertFalse();
      expect(isValidHttpUrl('https://256.168.1.10', false)).assertFalse();
      expect(isValidHttpUrl('https://example.com:65536', false)).assertFalse();
    });

    it('matches review cards against card and document content with case-insensitive tags', 0, (): void => {
      const service = new ReviewFilterService();
      const document = createDocument();
      document.title = '操作系统课程论文';
      document.source = 'https://example.com/operating-systems';
      document.tags = 'Course, 期末';
      document.excerpt = '课程资料摘录';
      const card = createEvidence();
      card.tags = '重点';

      expect(service.matches(card, document, {
        keyword: 'OPERATING-SYSTEMS',
        selectedTag: ''
      })).assertTrue();
      expect(service.matches(card, document, {
        keyword: '',
        selectedTag: 'course'
      })).assertTrue();
      expect(service.matches(card, document, {
        keyword: '',
        selectedTag: '重点'
      })).assertTrue();
      expect(service.matches(card, document, {
        keyword: '不存在的关键词',
        selectedTag: ''
      })).assertFalse();
      expect(service.matches(card, document, {
        keyword: '',
        selectedTag: '实验'
      })).assertFalse();
    });

    it('shares bounded, case-insensitive document search with the library view', 0, (): void => {
      const service = new ReviewFilterService();
      const document = createDocument();
      document.title = '操作系统课程论文';
      const card = createEvidence();
      card.quote = '可追溯的正文摘录';

      expect(service.matchesDocument(document, [card], '  正文摘录  ')).assertTrue();
      expect(service.matchesDocument(document, [card], '  课程论文  ')).assertTrue();
      expect(service.normalizeKeyword(`  ${'a'.repeat(MAX_SEARCH_LENGTH + 20)}  `).length)
        .assertEqual(MAX_SEARCH_LENGTH);
      expect(service.matchesDocument(
        document,
        [card],
        `  ${'a'.repeat(MAX_SEARCH_LENGTH + 20)}  `
      )).assertFalse();
    });

    it('deduplicates tag suggestions across document and evidence card data', 0, (): void => {
      const service = new ReviewFilterService();
      const document = createDocument();
      document.tags = 'Course, 课程';
      const card = createEvidence();
      card.tags = 'course, 重点';
      const tags = service.allTags([document], [card]);

      expect(tags.length).assertEqual(3);
      expect(tags.includes('Course')).assertTrue();
      expect(tags.includes('课程')).assertTrue();
      expect(tags.includes('重点')).assertTrue();
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

    it('returns complete evidence state for edits without advancing an unchanged review schedule', 0, (): void => {
      const card = createEvidence();
      card.reviewStatus = 'MASTERED';
      card.lastReviewedAt = 5000;
      card.nextReviewAt = 6000;
      card.reviewCount = 2;

      const updated = new EvidenceCardMutationService().forEdit(
        card,
        '  新笔记  ',
        '论文, 新标签, 论文',
        'UNDERLINE',
        0xFF57C7A5,
        'MASTERED',
        7000
      );

      expect(updated.note).assertEqual('  新笔记  ');
      expect(updated.tags).assertEqual('论文, 新标签');
      expect(updated.kind).assertEqual('UNDERLINE');
      expect(updated.color).assertEqual(0xFF57C7A5);
      expect(updated.lastReviewedAt).assertEqual(5000);
      expect(updated.nextReviewAt).assertEqual(6000);
      expect(updated.reviewCount).assertEqual(2);
      expect(updated.updatedAt).assertEqual(7000);
    });

    it('returns the exact deferred card state used by focused review', 0, (): void => {
      const card = createEvidence();
      card.reviewStatus = 'MASTERED';
      card.lastReviewedAt = 4000;
      card.nextReviewAt = 5000;
      card.reviewCount = 3;
      const updatedAt = 1000000;

      const updated = new EvidenceCardMutationService().forDeferredReview(card, updatedAt);

      expect(updated.reviewStatus).assertEqual('TO_REVIEW');
      expect(updated.lastReviewedAt).assertEqual(4000);
      expect(updated.nextReviewAt).assertEqual(updatedAt + 24 * 60 * 60 * 1000);
      expect(updated.reviewCount).assertEqual(3);
      expect(updated.updatedAt).assertEqual(updatedAt);
    });

    it('normalizes web evidence and batch tags in returned persisted cards', 0, (): void => {
      const service = new EvidenceCardMutationService();
      const webCard = createWebEvidence();
      webCard.pageIndex = 2;
      webCard.rectsJson = createEvidence().rectsJson;
      webCard.kind = 'HIGHLIGHT';

      const updatedWebCard = service.forWebEdit(
        webCard,
        '  新网页摘录  ',
        '  新网页笔记  ',
        '课程, 研究, 课程',
        'TO_REVIEW',
        8000
      );
      const taggedCard = service.withAppendedTags(updatedWebCard, '研究, 期末', 9000);

      expect(updatedWebCard.quote).assertEqual('新网页摘录');
      expect(updatedWebCard.note).assertEqual('新网页笔记');
      expect(updatedWebCard.pageIndex).assertEqual(0);
      expect(updatedWebCard.rectsJson).assertEqual('[]');
      expect(updatedWebCard.kind).assertEqual('QUOTE');
      expect(updatedWebCard.tags).assertEqual('课程, 研究');
      expect(taggedCard.tags).assertEqual('课程, 研究, 期末');
      expect(taggedCard.updatedAt).assertEqual(9000);
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

    it('keeps batch review actions deterministic for every selected card', 0, (): void => {
      const scheduler = new ReviewScheduler();
      const first = createEvidence('document-1');
      first.id = 'evidence-1';
      const second = createEvidence('document-1');
      second.id = 'evidence-2';
      second.reviewStatus = 'MASTERED';
      second.lastReviewedAt = 1000;
      second.nextReviewAt = 2000;
      second.reviewCount = 2;

      const updatedAt = 5000;
      const firstSchedule = scheduler.valuesForReviewAction(first, 'MASTERED', updatedAt);
      const secondSchedule = scheduler.valuesForReviewAction(second, 'MASTERED', updatedAt);

      expect(firstSchedule.reviewCount).assertEqual(1);
      expect(firstSchedule.lastReviewedAt).assertEqual(updatedAt);
      expect(secondSchedule.reviewCount).assertEqual(3);
      expect(secondSchedule.lastReviewedAt).assertEqual(updatedAt);
      expect(secondSchedule.nextReviewAt).assertEqual(updatedAt + 7 * 24 * 60 * 60 * 1000);
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

    it('rejects web backups whose source only contains a protocol', 0, (): void => {
      const payload = createPayload();
      payload.documents = [createWebDocument()];
      payload.documents[0].source = 'https://';
      payload.evidenceCards = [createWebEvidence()];
      payload.collectionItems = [
        createCollectionItem('web-1', 'DOCUMENT'),
        createCollectionItem('web-evidence-1', 'EVIDENCE')
      ];
      expect(new BackupValidator().validateJson(JSON.stringify(payload)).valid).assertFalse();
    });

    it('rejects evidence kinds and geometry that do not match their source', 0, (): void => {
      const pdfQuote = createPayload();
      pdfQuote.evidenceCards[0].kind = 'QUOTE';
      pdfQuote.evidenceCards[0].rectsJson = '[]';
      expect(new BackupValidator().validateJson(JSON.stringify(pdfQuote)).valid).assertFalse();

      const webAnnotation = createPayload();
      webAnnotation.documents = [createWebDocument()];
      const card = createWebEvidence();
      card.kind = 'HIGHLIGHT';
      card.rectsJson = createEvidence().rectsJson;
      webAnnotation.evidenceCards = [card];
      webAnnotation.collectionItems = [];
      expect(new BackupValidator().validateJson(JSON.stringify(webAnnotation)).valid).assertFalse();
    });

    it('rejects PDF selections whose anchor or selected pages cannot be restored', 0, (): void => {
      const mismatchedAnchor = createPayload();
      mismatchedAnchor.evidenceCards[0].pageIndex = 0;
      expect(new BackupValidator().validateJson(JSON.stringify(mismatchedAnchor)).valid).assertFalse();

      const selectedPageOutOfRange = createPayload();
      selectedPageOutOfRange.evidenceCards[0].rectsJson =
        '[{"pageIndex":1,"isRotated":0,"rectArray":' +
        '[{"left":10,"top":20,"right":80,"bottom":40}]},' +
        '{"pageIndex":3,"isRotated":0,"rectArray":' +
        '[{"left":10,"top":20,"right":80,"bottom":40}]}]';
      expect(new BackupValidator().validateJson(JSON.stringify(selectedPageOutOfRange)).valid).assertFalse();
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
      documents[1].source = 'https://';
      const invalidWebCard = createWebEvidence();
      invalidWebCard.kind = 'UNDERLINE';
      invalidWebCard.rectsJson = createEvidence().rectsJson;
      const evidenceCards: EvidenceCard[] = [
        createEvidence(),
        createEvidence('missing-document'),
        invalidWebCard
      ];
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
      expect(codes.includes('INVALID_EVIDENCE_SOURCE')).assertTrue();
    });

    it('serializes diagnostics without document content or source URLs', 0, (): void => {
      const report: DataHealthReport = {
        checkedAt: 5000,
        issues: [],
        issueCount: 0,
        missingPdfCount: 0,
        orphanFileCount: 0,
        invalidEvidenceSourceCount: 0,
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

    it('preserves both operation and rollback failures', 0, (): void => {
      const rollbackFailure = transactionFailure(
        '批量标签更新失败',
        new Error('写入失败'),
        new Error('回滚失败')
      );
      expect(rollbackFailure.message).assertEqual('批量标签更新失败: 写入失败; rollback failed: 回滚失败');

      const operationFailure = transactionFailure(
        '备份恢复失败',
        '数据库不可用'
      );
      expect(operationFailure.message).assertEqual('备份恢复失败: 数据库不可用');
      expect(rollbackFailure instanceof TransactionFailureError).assertTrue();
      expect(rollbackFailure.rollbackFailed).assertTrue();
      expect(operationFailure.rollbackFailed).assertFalse();
    });

    it('recognizes only YueJi managed interrupted-write files', 0, (): void => {
      expect(isManagedTemporaryPath('doc/source.pdf.import.tmp')).assertTrue();
      expect(isManagedTemporaryPath('doc/source.pdf.restore.tmp')).assertTrue();
      expect(isManagedTemporaryPath('doc/source.pdf.import-1787040000000.tmp')).assertTrue();
      expect(isManagedTemporaryPath('pre-restore-20260818-1787040000000.json.tmp')).assertTrue();
      expect(isManagedTemporaryPath('doc/source.pdf')).assertFalse();
      expect(isManagedTemporaryPath('notes.tmp')).assertFalse();
      expect(isManagedTemporaryPath('pre-restore-20260818.json')).assertFalse();
    });
  });
}
