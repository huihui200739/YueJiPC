import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import { DocumentRecord, EvidenceCard, tagList } from '../model/Models';

export class ExportService {
  private escapeMarkdown(value: string): string {
    return value.replace(/\r/g, '').trim();
  }

  buildMarkdown(documents: DocumentRecord[], cards: EvidenceCard[], title: string = '阅迹学习笔记'): string {
    const lines: string[] = [
      `# ${title}`,
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
      lines.push(`## ${this.escapeMarkdown(document.title)}`);
      lines.push('');
      if (document.kind === 'WEB') {
        lines.push(`来源：${document.source}`);
        lines.push('');
        if (document.excerpt.length > 0) {
          lines.push(`> ${this.escapeMarkdown(document.excerpt).replace(/\n/g, '\n> ')}`);
          lines.push('');
        }
        if (document.note.length > 0) {
          lines.push(this.escapeMarkdown(document.note));
          lines.push('');
        }
        if (document.tags.length > 0) {
          lines.push(`标签：${tagList(document.tags).map((tag: string): string => `#${tag}`).join(' ')}`);
          lines.push('');
        }
      }
      documentCards.forEach((card: EvidenceCard, index: number): void => {
        lines.push(`### 证据 ${index + 1}`);
        lines.push('');
        lines.push(`> ${this.escapeMarkdown(card.quote).replace(/\n/g, '\n> ')}`);
        lines.push('');
        lines.push(`来源：${document.title}，第 ${card.pageIndex + 1} 页`);
        lines.push('');
        if (card.note.length > 0) {
          lines.push(this.escapeMarkdown(card.note));
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

  async exportMarkdown(context: Context, content: string): Promise<boolean> {
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.save({
      newFileNames: ['阅迹学习笔记.md'],
      fileSuffixChoices: ['Markdown|.md']
    });
    if (uris.length === 0) {
      return false;
    }
    const file = await fs.open(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      await fs.write(file.fd, content);
    } finally {
      await fs.close(file);
    }
    return true;
  }
}
