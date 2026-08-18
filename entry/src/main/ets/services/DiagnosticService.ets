import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import {
  APP_VERSION,
  CollectionItem,
  CollectionRecord,
  DocumentRecord,
  EvidenceCard
} from '../model/Models';
import { DataHealthReport } from './DataHealthService';

export interface DiagnosticSnapshot {
  appVersion: string;
  targetApi: number;
  deviceType: string;
  databaseSchemaVersion: number;
  generatedAt: number;
  documentCount: number;
  evidenceCardCount: number;
  collectionCount: number;
  collectionItemCount: number;
  healthIssueCount: number;
  missingPdfCount: number;
  orphanFileCount: number;
  invalidSelectionCount: number;
  orphanRelationCount: number;
}

export interface DiagnosticFileResult {
  uri: string;
  fileName: string;
}

export class DiagnosticService {
  buildSnapshot(
    schemaVersion: number,
    documents: DocumentRecord[],
    evidenceCards: EvidenceCard[],
    collections: CollectionRecord[],
    collectionItems: CollectionItem[],
    report: DataHealthReport
  ): DiagnosticSnapshot {
    return {
      appVersion: APP_VERSION,
      targetApi: 24,
      deviceType: '2in1',
      databaseSchemaVersion: schemaVersion,
      generatedAt: Date.now(),
      documentCount: documents.length,
      evidenceCardCount: evidenceCards.length,
      collectionCount: collections.length,
      collectionItemCount: collectionItems.length,
      healthIssueCount: report.issueCount,
      missingPdfCount: report.missingPdfCount,
      orphanFileCount: report.orphanFileCount,
      invalidSelectionCount: report.invalidSelectionCount,
      orphanRelationCount: report.orphanRelationCount
    };
  }

  serialize(snapshot: DiagnosticSnapshot): string {
    return `${JSON.stringify(snapshot, null, 2)}\n`;
  }

  async save(context: Context, snapshot: DiagnosticSnapshot): Promise<DiagnosticFileResult | undefined> {
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.save({
      newFileNames: [`阅迹诊断-${this.dateStamp()}.json`],
      fileSuffixChoices: ['JSON|.json']
    });
    if (uris.length === 0) {
      return undefined;
    }
    const file = await fs.open(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      await fs.write(file.fd, this.serialize(snapshot));
    } finally {
      await fs.close(file);
    }
    return {
      uri: uris[0],
      fileName: this.fileNameFromUri(uris[0])
    };
  }

  private dateStamp(): string {
    const value = new Date();
    const month = `${value.getMonth() + 1}`.padStart(2, '0');
    const day = `${value.getDate()}`.padStart(2, '0');
    return `${value.getFullYear()}${month}${day}`;
  }

  private fileNameFromUri(uri: string): string {
    const cleanUri = uri.split('?')[0].split('#')[0];
    const value = cleanUri.substring(cleanUri.lastIndexOf('/') + 1);
    if (value.length === 0) {
      return '阅迹诊断.json';
    }
    try {
      return decodeURIComponent(value);
    } catch (error) {
      return value;
    }
  }
}
