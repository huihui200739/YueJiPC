import fs from '@ohos.file.fs';
import {
  CollectionItem,
  CollectionRecord,
  DocumentRecord,
  EvidenceCard,
  canonicalPdfPath,
  isCollectionItemKind,
  validateEvidenceSource
} from '../model/Models';

export type DataHealthIssueCode =
  'MISSING_PDF' |
  'INVALID_PDF_PATH' |
  'ORPHAN_FILE' |
  'ORPHAN_EVIDENCE' |
  'INVALID_EVIDENCE_SOURCE' |
  'INVALID_SELECTION' |
  'PAGE_OUT_OF_RANGE' |
  'ORPHAN_COLLECTION_ITEM' |
  'INVALID_WEB_SOURCE';

export interface DataHealthIssue {
  code: DataHealthIssueCode;
  documentId: string;
  detail: string;
}

export interface DataHealthReport {
  checkedAt: number;
  issues: DataHealthIssue[];
  issueCount: number;
  missingPdfCount: number;
  orphanFileCount: number;
  invalidEvidenceSourceCount: number;
  invalidSelectionCount: number;
  orphanRelationCount: number;
}

export class DataHealthService {
  inspect(
    context: Context,
    documents: DocumentRecord[],
    evidenceCards: EvidenceCard[],
    collections: CollectionRecord[],
    collectionItems: CollectionItem[]
  ): DataHealthReport {
    const issues = this.inspectRecords(documents, evidenceCards, collections, collectionItems);
    this.inspectLibraryFiles(context.filesDir, documents, issues);
    return this.toReport(issues);
  }

  inspectRecords(
    documents: DocumentRecord[],
    evidenceCards: EvidenceCard[],
    collections: CollectionRecord[],
    collectionItems: CollectionItem[]
  ): DataHealthIssue[] {
    const issues: DataHealthIssue[] = [];
    const documentIds = documents.map((document: DocumentRecord): string => document.id);
    const evidenceIds = evidenceCards.map((card: EvidenceCard): string => card.id);
    const collectionIds = collections.map((collection: CollectionRecord): string => collection.id);

    documents.forEach((document: DocumentRecord): void => {
      if (document.kind === 'WEB' &&
        !/^https?:\/\//i.test(document.source.trim())) {
        issues.push({
          code: 'INVALID_WEB_SOURCE',
          documentId: document.id,
          detail: '网页资料来源不是有效的 http 或 https 地址'
        });
      }
    });

    evidenceCards.forEach((card: EvidenceCard): void => {
      const document = documents.find((item: DocumentRecord): boolean => item.id === card.documentId);
      if (document === undefined) {
        issues.push({
          code: 'ORPHAN_EVIDENCE',
          documentId: card.documentId,
          detail: '证据卡关联的资料不存在'
        });
        return;
      }
      const sourceValidation = validateEvidenceSource(
        document.kind,
        document.pageCount,
        card.kind,
        card.pageIndex,
        card.rectsJson
      );
      if (!sourceValidation.sourceCompatible) {
        issues.push({
          code: 'INVALID_EVIDENCE_SOURCE',
          documentId: document.id,
          detail: document.kind === 'PDF' ?
            'PDF 证据卡必须使用高亮或下划线并保留原始选区' :
            '网页证据卡必须是不包含 PDF 页码和选区的摘录卡'
        });
      }
      if (document.kind === 'PDF' && !sourceValidation.pageInRange) {
        issues.push({
          code: 'PAGE_OUT_OF_RANGE',
          documentId: document.id,
          detail: '证据卡页码或选区页超出资料页数'
        });
      }
      if (document.kind === 'PDF' &&
        sourceValidation.sourceCompatible &&
        !sourceValidation.selectionValid) {
        issues.push({
          code: 'INVALID_SELECTION',
          documentId: document.id,
          detail: '证据卡选区数据无法恢复，或首个选区页与回跳页不一致'
        });
      }
    });

    collectionItems.forEach((item: CollectionItem): void => {
      const targetExists = item.itemKind === 'DOCUMENT' ?
        documentIds.includes(item.itemId) :
        evidenceIds.includes(item.itemId);
      if (!collectionIds.includes(item.collectionId) ||
        !isCollectionItemKind(item.itemKind) ||
        !targetExists) {
        issues.push({
          code: 'ORPHAN_COLLECTION_ITEM',
          documentId: item.itemId,
          detail: '主题集合关联的资料、证据卡或集合不存在'
        });
      }
    });
    return issues;
  }

  private inspectLibraryFiles(
    filesDir: string,
    documents: DocumentRecord[],
    issues: DataHealthIssue[]
  ): void {
    const referencedPaths: string[] = [];
    documents.forEach((document: DocumentRecord): void => {
      if (document.kind !== 'PDF') {
        return;
      }
      const expectedPath = canonicalPdfPath(filesDir, document.id);
      referencedPaths.push(expectedPath);
      if (document.source !== expectedPath) {
        issues.push({
          code: 'INVALID_PDF_PATH',
          documentId: document.id,
          detail: 'PDF 来源路径不是当前应用沙箱中的标准路径'
        });
      }
      if (!this.fileExists(document.source)) {
        issues.push({
          code: 'MISSING_PDF',
          documentId: document.id,
          detail: 'PDF 沙箱副本不存在，需要重新导入'
        });
      }
    });

    const libraryRoot = `${filesDir}/library`;
    let files: string[] = [];
    try {
      files = fs.listFileSync(libraryRoot, { recursion: true });
    } catch (error) {
      return;
    }
    files.forEach((relativePath: string): void => {
      const normalized = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
      if (!normalized.toLowerCase().endsWith('/source.pdf')) {
        return;
      }
      const absolutePath = `${libraryRoot}/${normalized}`;
      if (!referencedPaths.includes(absolutePath)) {
        issues.push({
          code: 'ORPHAN_FILE',
          documentId: '',
          detail: '资料库中存在未被资料记录引用的 PDF 文件'
        });
      }
    });
  }

  private fileExists(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      return fs.statSync(path).isFile();
    } catch (error) {
      return false;
    }
  }

  private toReport(issues: DataHealthIssue[]): DataHealthReport {
    return {
      checkedAt: Date.now(),
      issues: issues.slice(0, 100),
      issueCount: issues.length,
      missingPdfCount: issues.filter((issue: DataHealthIssue): boolean =>
        issue.code === 'MISSING_PDF').length,
      orphanFileCount: issues.filter((issue: DataHealthIssue): boolean =>
        issue.code === 'ORPHAN_FILE').length,
      invalidEvidenceSourceCount: issues.filter((issue: DataHealthIssue): boolean =>
        issue.code === 'INVALID_EVIDENCE_SOURCE').length,
      invalidSelectionCount: issues.filter((issue: DataHealthIssue): boolean =>
        issue.code === 'INVALID_SELECTION').length,
      orphanRelationCount: issues.filter((issue: DataHealthIssue): boolean =>
        issue.code === 'ORPHAN_EVIDENCE' || issue.code === 'ORPHAN_COLLECTION_ITEM').length
    };
  }
}
