import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import { createId, DocumentRecord } from '../model/Models';

export interface ImportedPdf {
  record: DocumentRecord;
  originalUri: string;
}

export class ImportService {
  private fileNameFromUri(uri: string): string {
    const cleanUri = uri.split('?')[0];
    const parts = cleanUri.split('/');
    const value = parts[parts.length - 1];
    if (value.length === 0) {
      return '未命名资料.pdf';
    }
    try {
      return decodeURIComponent(value);
    } catch (error) {
      return value;
    }
  }

  async chooseAndCopyPdf(context: Context): Promise<ImportedPdf | undefined> {
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.select({
      fileSuffixFilters: ['PDF|.pdf'],
      maxSelectNumber: 1
    });
    if (uris.length === 0) {
      return undefined;
    }
    return this.copyPdfFromUri(context, uris[0]);
  }

  async copyPdfFromUri(context: Context, uri: string): Promise<ImportedPdf> {
    const documentId = createId('doc');
    const libraryDirectory = `${context.filesDir}/library/${documentId}`;
    await fs.mkdir(libraryDirectory, true);
    const targetPath = `${libraryDirectory}/source.pdf`;
    try {
      const source = await fs.open(uri, fs.OpenMode.READ_ONLY);
      try {
        await fs.copyFile(source.fd, targetPath);
      } finally {
        await fs.close(source);
      }
    } catch (error) {
      await this.removeImportedPdf(targetPath);
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('PDF 文件复制失败');
    }
    const now = Date.now();
    return {
      originalUri: uri,
      record: {
        id: documentId,
        kind: 'PDF',
        title: this.fileNameFromUri(uri),
        source: targetPath,
        pageCount: 0,
        currentPage: 0,
        tags: '',
        favorite: false,
        excerpt: '',
        note: '',
        createdAt: now,
        lastReadAt: now
      }
    };
  }

  async removeImportedPdf(path: string): Promise<void> {
    try {
      if (this.fileExists(path)) {
        await fs.unlink(path);
      }
      const lastSlash = path.lastIndexOf('/');
      if (lastSlash > 0) {
        await fs.rmdir(path.substring(0, lastSlash));
      }
    } catch (error) {
    }
  }

  fileExists(path: string): boolean {
    try {
      return fs.statSync(path).isFile();
    } catch (error) {
      return false;
    }
  }
}
