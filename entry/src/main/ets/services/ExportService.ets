import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import { DocumentRecord, EvidenceCard, tagList } from '../model/Models';

export interface MarkdownExportResult {
  uri: string;
  fileName: string;
}

export class ExportService {
  private cleanText(value: string): string {
    return value.replace(/\r/g, '').trim();
  }

  private escapeHeading(value: string): string {
    return this.cleanText(value).replace(/([\\`*_{}\[\]()#+.!|>])/g, '\\$1');
  }

  private blockquote(value: string): string {
    const text = this.cleanText(value);
    if (text.length === 0) {
      return '> ';
    }
    return text.split('\n').map((line: string): string => `> ${line}`).join('\n');
  }

  private suggestedFileName(title: string): string {
    const stem = this.cleanText(title)
      .replace(/\.(pdf|md)$/i, '')
      .replace(/[\\/:*?"<>|]/g, '-')
      .replace(/\s+/g, ' ')
      .slice(0, 72)
      .trim();
    return `${stem.length > 0 ? stem : '阅迹学习笔记'}.md`;
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

  buildMarkdown(documents: DocumentRecord[], cards: EvidenceCard[], title: string = '阅迹学习笔记'): string {
    const lines: string[] = [
      `# ${this.escapeHeading(title)}`,
      '',
      `导出时间：${new Date().toLocaleString()}`,
      '',
      '> 本笔记由阅迹导出。每条摘录都保留资料名与页码/网址，便于核对原始来源。',
      ''
    ];
    documents.forEach((document: DocumentRecord): void => {
      const documentCards = cards
        .filter((card: EvidenceCard): boolean => card.documentId === document.id)
        .sort((left: EvidenceCard, right: EvidenceCard): number => left.pageIndex - right.pageIndex);
      if (documentCards.length === 0 && document.kind === 'PDF') {
        return;
      }
      lines.push(`## ${this.escapeHeading(document.title)}`);
      lines.push('');
      if (document.kind === 'WEB') {
        lines.push(`来源：${document.source}`);
        lines.push('');
        if (documentCards.length === 0) {
          if (document.excerpt.length > 0) {
            lines.push(this.blockquote(document.excerpt));
            lines.push('');
          }
          if (document.note.length > 0) {
            lines.push(this.cleanText(document.note));
            lines.push('');
          }
        }
        if (document.tags.length > 0) {
          lines.push(`标签：${tagList(document.tags).map((tag: string): string => `#${tag}`).join(' ')}`);
          lines.push('');
        }
      }
      documentCards.forEach((card: EvidenceCard, index: number): void => {
        lines.push(`### 证据 ${index + 1}`);
        lines.push('');
        lines.push(this.blockquote(card.quote));
        lines.push('');
        lines.push(document.kind === 'WEB' ?
          `来源：${this.cleanText(document.title)}，网页摘录` :
          `来源：${this.cleanText(document.title)}，第 ${card.pageIndex + 1} 页`);
        lines.push('');
        if (card.note.length > 0) {
          lines.push(this.cleanText(card.note));
          lines.push('');
        }
        const status = card.reviewStatus === 'MASTERED' ? '已掌握' : '待复习';
        const tags = tagList(card.tags).map((tag: string): string => `#${tag}`).join(' ');
        lines.push(`状态：${status}${tags.length > 0 ? ` · ${tags}` : ''}`);
        lines.push('');
      });
    });
    return `${lines.join('\n')}\n`;
  }

  async exportMarkdown(
    context: Context,
    content: string,
    title: string
  ): Promise<MarkdownExportResult | undefined> {
    const suggestedName = this.suggestedFileName(title);
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.save({
      newFileNames: [suggestedName],
      fileSuffixChoices: ['Markdown|.md']
    });
    if (uris.length === 0) {
      return undefined;
    }
    const file = await fs.open(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    let writeFailure: Error | undefined = undefined;
    try {
      await fs.write(file.fd, content);
    } catch (error) {
      writeFailure = error instanceof Error ? error : new Error('Markdown 导出失败');
    } finally {
      try {
        await fs.close(file);
      } catch (error) {
        if (writeFailure === undefined) {
          writeFailure = error instanceof Error ? error : new Error('Markdown 导出文件关闭失败');
        }
      }
    }
    if (writeFailure !== undefined) {
      throw writeFailure;
    }
    return {
      uri: uris[0],
      fileName: this.fileNameFromUri(uris[0], suggestedName)
    };
  }
}
