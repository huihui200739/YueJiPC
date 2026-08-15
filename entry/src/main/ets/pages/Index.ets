import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import { common } from '@kit.AbilityKit';
import { unifiedDataChannel, uniformDataStruct } from '@kit.ArkData';
import { KeyCode } from '@kit.InputKit';
import { PdfView, pdfService, pdfViewManager } from '@kit.PDFKit';
import { EvidenceRepository } from '../data/EvidenceRepository';
import { LibraryRepository } from '../data/LibraryRepository';
import { YueJiDatabase } from '../data/YueJiDatabase';
import {
  AppSettings,
  createId,
  DocumentRecord,
  EvidenceCard,
  EvidenceKind,
  MainView,
  normalizeTags,
  ReviewStatus,
  StoredPdfRect,
  StoredSelection,
  tagList
} from '../model/Models';
import { ExportService } from '../services/ExportService';
import { ImportService, ImportedPdf } from '../services/ImportService';
import { LinkService, WebDraft } from '../services/LinkService';
import { SettingsService } from '../services/SettingsService';

type LibraryScope = 'ALL' | 'RECENT' | 'FAVORITE';
type ReviewFilter = 'ALL' | 'TO_REVIEW' | 'MASTERED';
type DeleteTargetKind = 'NONE' | 'DOCUMENT' | 'EVIDENCE';
type EditorDraftKind = 'NONE' | 'WEB' | 'PDF' | 'EVIDENCE';
type EditorDraftAction =
  'NONE' |
  'CLOSE' |
  'EDIT_EVIDENCE' |
  'DELETE_EVIDENCE' |
  'OPEN_DOCUMENT' |
  'IMPORT_PDF' |
  'IMPORT_DROPPED_PDF' |
  'DELETE_DOCUMENT' |
  'RETURN_TO_EVIDENCE' |
  'START_REVIEW_SESSION';
type EvidenceDraftAction =
  'NONE' |
  'OPEN_DOCUMENT' |
  'IMPORT_PDF' |
  'IMPORT_DROPPED_PDF' |
  'DELETE_DOCUMENT' |
  'RETURN_TO_EVIDENCE' |
  'START_REVIEW_SESSION' |
  'SHOW_LIBRARY' |
  'SHOW_REVIEW' |
  'ADD_WEB';

interface ThumbnailRecord {
  pageIndex: number;
  pixelMap?: image.PixelMap;
}

@Entry
@Component
struct Index {
  @State private isReady: boolean = false;
  @State private isLoading: boolean = false;
  @State private mainView: MainView = 'LIBRARY';
  @State private libraryScope: LibraryScope = 'ALL';
  @State private reviewFilter: ReviewFilter = 'ALL';
  @State private documents: DocumentRecord[] = [];
  @State private evidenceCards: EvidenceCard[] = [];
  @State private activeDocumentId: string = '';
  @State private documentPath: string = '';
  @State private pageCount: number = 0;
  @State private currentPage: number = 1;
  @State private pageInput: string = '1';
  @State private zoomPercent: number = 100;
  @State private selectedText: string = '';
  @State private evidenceNote: string = '';
  @State private evidenceTags: string = '';
  @State private evidenceKind: EvidenceKind = 'HIGHLIGHT';
  @State private evidenceColor: number = 0xFFFFD95A;
  @State private editingEvidenceId: string = '';
  @State private editingEvidenceNote: string = '';
  @State private editingEvidenceTags: string = '';
  @State private searchText: string = '';
  @State private searchedText: string = '';
  @State private searchCount: number = 0;
  @State private searchIndex: number = 0;
  @State private librarySearch: string = '';
  @State private selectedTag: string = '';
  @State private reviewSearch: string = '';
  @State private reviewSelectedTag: string = '';
  @State private statusMessage: string = '正在准备本地资料库…';
  @State private darkMode: boolean = false;
  @State private focusMode: boolean = false;
  @State private leftSidebarOpen: boolean = true;
  @State private rightSidebarOpen: boolean = true;
  @State private windowWidth: number = 1440;
  @State private windowHeight: number = 900;
  @State private showWebEditor: boolean = false;
  @State private editingWebId: string = '';
  @State private webTitle: string = '';
  @State private webUrl: string = '';
  @State private webExcerpt: string = '';
  @State private webNote: string = '';
  @State private webTags: string = '';
  @State private showPdfEditor: boolean = false;
  @State private editingPdfId: string = '';
  @State private pdfTitle: string = '';
  @State private pdfTags: string = '';
  @State private thumbnails: ThumbnailRecord[] = [];
  @State private thumbnailLoadCount: number = 0;
  @State private isDragOver: boolean = false;
  @State private deleteTargetKind: DeleteTargetKind = 'NONE';
  @State private deleteTargetId: string = '';
  @State private isDeleting: boolean = false;
  @State private isSavingEvidence: boolean = false;
  @State private isSavingEditor: boolean = false;
  @State private editorDraftKind: EditorDraftKind = 'NONE';
  @State private editorDraftAction: EditorDraftAction = 'NONE';
  @State private editorDraftTargetId: string = '';
  @State private editorDraftUri: string = '';
  @State private evidenceDraftAction: EvidenceDraftAction = 'NONE';
  @State private evidenceDraftTargetId: string = '';
  @State private evidenceDraftUri: string = '';
  @State private reviewSessionIds: string[] = [];
  @State private reviewSessionIndex: number = 0;
  @State private reviewSessionReviewedCount: number = 0;
  @State private reviewSessionMasteredCount: number = 0;
  @State private isReviewSessionUpdating: boolean = false;
  @State private reviewSessionSourceOpen: boolean = false;

  private pdfController: pdfViewManager.PdfController = new pdfViewManager.PdfController();
  private selectedRects: Array<pdfViewManager.SelectedRects> = [];
  private searchGeneration: number = 0;
  private thumbnailGeneration: number = 0;
  private reviewSessionSourceRightSidebarOpen: boolean = true;
  private database: YueJiDatabase = new YueJiDatabase();
  private libraryRepository: LibraryRepository = new LibraryRepository(this.database);
  private evidenceRepository: EvidenceRepository = new EvidenceRepository(this.database);
  private importService: ImportService = new ImportService();
  private linkService: LinkService = new LinkService();
  private exportService: ExportService = new ExportService();
  private settingsService: SettingsService = new SettingsService();

  aboutToAppear(): void {
    this.pdfController.registerPageChangedListener((pageIndex: number): void => {
      this.currentPage = pageIndex + 1;
      this.pageInput = `${this.currentPage}`;
      if (this.activeDocumentId.length > 0) {
        this.persistReadPosition(pageIndex);
      }
    });
    this.pdfController.registerScaleChangedListener((scale: number): void => {
      this.zoomPercent = Math.round(scale * 100);
    });
    this.pdfController.registerTextSelectedListener((selection: pdfViewManager.TextSelectedParam): void => {
      this.handleTextSelection(selection);
    });
    this.initializeApp();
  }

  aboutToDisappear(): void {
    if (this.documentPath.length > 0) {
      this.pdfController.releaseDocument();
    }
    this.releaseThumbnails();
  }

  private hostContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private handleTextSelection(selection: pdfViewManager.TextSelectedParam): void {
    const selectedText = selection.text.trim();
    if (this.isSavingEvidence || selectedText.length === 0 || selection.pdfRect.length === 0) {
      return;
    }
    const sourceChanged = this.selectedText.trim().length > 0 && this.selectedText.trim() !== selectedText;
    const hasDraftContent = this.evidenceNote.trim().length > 0 || this.evidenceTags.trim().length > 0;
    const layoutChanged = !this.rightSidebarOpen || this.leftSidebarOpen || this.focusMode;
    this.selectedText = selection.text;
    this.selectedRects = selection.pdfRect;
    this.rightSidebarOpen = true;
    this.focusMode = false;
    if (this.windowWidth < 1100) {
      this.leftSidebarOpen = false;
    }
    if (layoutChanged) {
      this.saveSettings();
    }
    if (sourceChanged && hasDraftContent) {
      this.statusMessage = `选区已更新为第 ${selection.pdfRect[0].pageIndex + 1} 页，笔记和标签草稿已保留`;
      return;
    }
    this.statusMessage = `已选择第 ${selection.pdfRect[0].pageIndex + 1} 页文字，可创建证据卡`;
  }

  private resetEvidenceDraft(): void {
    this.selectedText = '';
    this.selectedRects = [];
    this.evidenceNote = '';
    this.evidenceTags = '';
  }

  private hasEvidenceDraft(): boolean {
    return this.selectedText.trim().length > 0 && this.selectedRects.length > 0;
  }

  private cancelEvidenceDraft(): void {
    if (this.isSavingEvidence) {
      return;
    }
    this.resetEvidenceDraft();
    this.statusMessage = '已取消本次证据卡';
  }

  private requestEvidenceDraftDiscard(
    action: EvidenceDraftAction,
    targetId: string = '',
    uri: string = ''
  ): boolean {
    if (!this.hasEvidenceDraft() || this.isSavingEvidence) {
      return false;
    }
    this.evidenceDraftAction = action;
    this.evidenceDraftTargetId = targetId;
    this.evidenceDraftUri = uri;
    this.statusMessage = '当前证据卡草稿尚未保存';
    return true;
  }

  private evidenceDraftDestinationLabel(): string {
    if (this.evidenceDraftAction === 'OPEN_DOCUMENT') {
      const document = this.documentById(this.evidenceDraftTargetId);
      return document === undefined ? '打开其他资料' : `打开“${document.title}”`;
    }
    if (this.evidenceDraftAction === 'IMPORT_PDF' ||
      this.evidenceDraftAction === 'IMPORT_DROPPED_PDF') {
      return '导入新的 PDF';
    }
    if (this.evidenceDraftAction === 'DELETE_DOCUMENT') {
      return '删除当前资料';
    }
    if (this.evidenceDraftAction === 'RETURN_TO_EVIDENCE') {
      return '返回另一条证据的来源';
    }
    if (this.evidenceDraftAction === 'START_REVIEW_SESSION') {
      return '开始专注复习';
    }
    if (this.evidenceDraftAction === 'SHOW_LIBRARY') {
      return this.evidenceDraftTargetId === 'RECENT' ? '前往最近阅读' :
        this.evidenceDraftTargetId === 'FAVORITE' ? '前往收藏' : '前往资料库';
    }
    if (this.evidenceDraftAction === 'SHOW_REVIEW') {
      return '前往复习中心';
    }
    if (this.evidenceDraftAction === 'ADD_WEB') {
      return '添加网页资料';
    }
    return '继续当前操作';
  }

  private cancelEvidenceDraftDiscard(): void {
    this.evidenceDraftAction = 'NONE';
    this.evidenceDraftTargetId = '';
    this.evidenceDraftUri = '';
    if (this.hasEvidenceDraft() && this.activeDocumentId.length > 0 && this.documentPath.length > 0) {
      const layoutChanged = !this.rightSidebarOpen ||
        this.focusMode ||
        (this.windowWidth < 1100 && this.leftSidebarOpen);
      this.mainView = 'READER';
      this.rightSidebarOpen = true;
      this.focusMode = false;
      if (this.windowWidth < 1100) {
        this.leftSidebarOpen = false;
      }
      if (layoutChanged) {
        this.saveSettings();
      }
      this.statusMessage = `已返回证据卡草稿：${this.selectedSourceLabel()}`;
      return;
    }
    this.statusMessage = '已保留当前证据卡草稿';
  }

  private async discardEvidenceDraftAndContinue(): Promise<void> {
    const action = this.evidenceDraftAction;
    const targetId = this.evidenceDraftTargetId;
    const uri = this.evidenceDraftUri;
    this.evidenceDraftAction = 'NONE';
    this.evidenceDraftTargetId = '';
    this.evidenceDraftUri = '';
    this.resetEvidenceDraft();
    this.statusMessage = '已放弃未保存的证据卡草稿';
    if (action === 'OPEN_DOCUMENT') {
      const document = this.documentById(targetId);
      if (document !== undefined) {
        await this.openDocument(document);
        return;
      }
    } else if (action === 'IMPORT_PDF') {
      await this.importPdf();
      return;
    } else if (action === 'IMPORT_DROPPED_PDF') {
      await this.importPdfFromUri(uri);
      return;
    } else if (action === 'DELETE_DOCUMENT') {
      const document = this.documentById(targetId);
      if (document !== undefined) {
        this.requestDeleteDocument(document);
        return;
      }
    } else if (action === 'RETURN_TO_EVIDENCE') {
      const card = this.evidenceCards.find((item: EvidenceCard): boolean => item.id === targetId);
      if (card !== undefined) {
        await this.returnToEvidence(card);
        return;
      }
    } else if (action === 'START_REVIEW_SESSION') {
      this.startReviewSession();
      return;
    } else if (action === 'SHOW_LIBRARY') {
      const scope: LibraryScope = targetId === 'RECENT' ? 'RECENT' :
        targetId === 'FAVORITE' ? 'FAVORITE' : 'ALL';
      this.showLibrary(scope);
      return;
    } else if (action === 'SHOW_REVIEW') {
      this.showReview();
      return;
    } else if (action === 'ADD_WEB') {
      this.startAddWeb();
      return;
    }
    this.statusMessage = '目标内容已不存在，证据卡草稿已放弃';
  }

  private hasWebEditorDraft(): boolean {
    if (!this.showWebEditor) {
      return false;
    }
    if (this.editingWebId.length === 0) {
      return this.webTitle.length > 0 ||
        this.webUrl.length > 0 ||
        this.webExcerpt.length > 0 ||
        this.webNote.length > 0 ||
        this.webTags.length > 0;
    }
    const document = this.documentById(this.editingWebId);
    if (document === undefined) {
      return true;
    }
    return this.webTitle !== document.title ||
      this.webUrl !== document.source ||
      this.webExcerpt !== document.excerpt ||
      this.webNote !== document.note ||
      this.webTags !== document.tags;
  }

  private hasPdfEditorDraft(): boolean {
    if (!this.showPdfEditor) {
      return false;
    }
    const document = this.documentById(this.editingPdfId);
    if (document === undefined) {
      return true;
    }
    return this.pdfTitle !== document.title || this.pdfTags !== document.tags;
  }

  private hasEvidenceEditorDraft(): boolean {
    if (this.editingEvidenceId.length === 0) {
      return false;
    }
    const card = this.evidenceCards.find((item: EvidenceCard): boolean => item.id === this.editingEvidenceId);
    if (card === undefined) {
      return true;
    }
    return this.editingEvidenceNote !== card.note || this.editingEvidenceTags !== card.tags;
  }

  private hasEditorDraft(kind: EditorDraftKind): boolean {
    if (kind === 'WEB') {
      return this.hasWebEditorDraft();
    }
    if (kind === 'PDF') {
      return this.hasPdfEditorDraft();
    }
    if (kind === 'EVIDENCE') {
      return this.hasEvidenceEditorDraft();
    }
    return false;
  }

  private closeEditor(kind: EditorDraftKind): void {
    if (kind === 'WEB') {
      this.showWebEditor = false;
      this.editingWebId = '';
      this.webTitle = '';
      this.webUrl = '';
      this.webExcerpt = '';
      this.webNote = '';
      this.webTags = '';
    } else if (kind === 'PDF') {
      this.showPdfEditor = false;
      this.editingPdfId = '';
      this.pdfTitle = '';
      this.pdfTags = '';
    } else if (kind === 'EVIDENCE') {
      this.editingEvidenceId = '';
      this.editingEvidenceNote = '';
      this.editingEvidenceTags = '';
    }
  }

  private requestEditorDraftDiscard(
    kind: EditorDraftKind,
    action: EditorDraftAction = 'CLOSE',
    targetId: string = '',
    uri: string = ''
  ): boolean {
    if (this.isSavingEditor) {
      return true;
    }
    if (!this.hasEditorDraft(kind)) {
      return false;
    }
    this.editorDraftKind = kind;
    this.editorDraftAction = action;
    this.editorDraftTargetId = targetId;
    this.editorDraftUri = uri;
    this.statusMessage = '当前编辑内容尚未保存';
    return true;
  }

  private requestCloseEditor(kind: EditorDraftKind): void {
    if (this.isSavingEditor || this.requestEditorDraftDiscard(kind)) {
      return;
    }
    this.closeEditor(kind);
  }

  private cancelEditorDraftDiscard(): void {
    this.editorDraftKind = 'NONE';
    this.editorDraftAction = 'NONE';
    this.editorDraftTargetId = '';
    this.editorDraftUri = '';
    this.statusMessage = '已保留当前编辑内容';
  }

  private async discardEditorDraftAndContinue(): Promise<void> {
    const kind = this.editorDraftKind;
    const action = this.editorDraftAction;
    const targetId = this.editorDraftTargetId;
    const uri = this.editorDraftUri;
    this.editorDraftKind = 'NONE';
    this.editorDraftAction = 'NONE';
    this.editorDraftTargetId = '';
    this.editorDraftUri = '';
    this.closeEditor(kind);
    if (action === 'EDIT_EVIDENCE') {
      const card = this.evidenceCards.find((item: EvidenceCard): boolean => item.id === targetId);
      if (card !== undefined) {
        this.startEditEvidence(card);
        return;
      }
    } else if (action === 'DELETE_EVIDENCE') {
      const card = this.evidenceCards.find((item: EvidenceCard): boolean => item.id === targetId);
      if (card !== undefined) {
        this.requestDeleteEvidence(card);
        return;
      }
    } else if (action === 'OPEN_DOCUMENT') {
      const document = this.documentById(targetId);
      if (document !== undefined) {
        await this.openDocument(document);
        return;
      }
    } else if (action === 'IMPORT_PDF') {
      await this.importPdf();
      return;
    } else if (action === 'IMPORT_DROPPED_PDF') {
      await this.importPdfFromUri(uri);
      return;
    } else if (action === 'DELETE_DOCUMENT') {
      const document = this.documentById(targetId);
      if (document !== undefined) {
        this.requestDeleteDocument(document);
        return;
      }
    } else if (action === 'RETURN_TO_EVIDENCE') {
      const card = this.evidenceCards.find((item: EvidenceCard): boolean => item.id === targetId);
      if (card !== undefined) {
        await this.returnToEvidence(card);
        return;
      }
    } else if (action === 'START_REVIEW_SESSION') {
      this.requestStartReviewSession();
      return;
    } else if (action === 'CLOSE') {
      this.statusMessage = '已放弃未保存的修改';
      return;
    }
    this.statusMessage = '目标内容已不存在，未保存的修改已放弃';
  }

  private editorDraftTitle(): string {
    if (this.editorDraftKind === 'WEB') {
      return this.editingWebId.length === 0 ? '放弃新网页资料？' : '放弃网页资料修改？';
    }
    if (this.editorDraftKind === 'PDF') {
      return '放弃 PDF 资料修改？';
    }
    return '放弃证据卡修改？';
  }

  private editorDraftTarget(): string {
    if (this.editorDraftKind === 'WEB') {
      return this.webTitle.trim().length > 0 ? this.webTitle.trim() :
        (this.webUrl.trim().length > 0 ? this.webUrl.trim() : '尚未命名的网页资料');
    }
    if (this.editorDraftKind === 'PDF') {
      return this.pdfTitle.trim().length > 0 ? this.pdfTitle.trim() : '未命名 PDF';
    }
    const card = this.evidenceCards.find((item: EvidenceCard): boolean => item.id === this.editingEvidenceId);
    return card === undefined ? '目标证据卡已不存在' : card.quote;
  }

  private editorDraftMessage(): string {
    if (this.editorDraftKind === 'WEB') {
      return '标题、网址、摘录、笔记或标签中的修改尚未保存。';
    }
    if (this.editorDraftKind === 'PDF') {
      return '资料标题或标签中的修改尚未保存。';
    }
    return '证据卡的笔记或标签修改尚未保存。';
  }

  private selectedSourceLabel(): string {
    if (this.selectedRects.length === 0) {
      return '';
    }
    const firstPage = this.selectedRects[0].pageIndex + 1;
    const lastPage = this.selectedRects[this.selectedRects.length - 1].pageIndex + 1;
    const pageLabel = firstPage === lastPage ? `第 ${firstPage} 页` : `第 ${firstPage}-${lastPage} 页`;
    return `${pageLabel} · 已选 ${this.selectedText.trim().length} 字`;
  }

  private async initializeApp(): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) {
      this.statusMessage = '无法取得应用上下文，请重新打开应用';
      return;
    }
    try {
      await this.database.initialize(context);
      await this.settingsService.initialize(context);
      const settings = await this.settingsService.load();
      this.darkMode = settings.darkMode;
      this.focusMode = settings.focusMode;
      this.leftSidebarOpen = settings.leftSidebarOpen;
      this.rightSidebarOpen = settings.rightSidebarOpen;
      this.evidenceColor = settings.defaultHighlightColor;
      await this.reloadData();
      this.isReady = true;
      this.statusMessage = this.documents.length > 0 ?
        `已恢复 ${this.documents.length} 份资料与 ${this.evidenceCards.length} 张证据卡` :
        '资料库已就绪，导入一份 PDF 或添加网页资料';
    } catch (error) {
      this.statusMessage = '本地资料库初始化失败，请检查存储空间后重试';
    }
  }

  private async reloadData(): Promise<void> {
    this.documents = await this.libraryRepository.listAll();
    this.evidenceCards = await this.evidenceRepository.listAll();
  }

  private activeDocument(): DocumentRecord | undefined {
    return this.documents.find((document: DocumentRecord): boolean => document.id === this.activeDocumentId);
  }

  private documentById(id: string): DocumentRecord | undefined {
    return this.documents.find((document: DocumentRecord): boolean => document.id === id);
  }

  private documentTitle(id: string): string {
    const document = this.documentById(id);
    return document === undefined ? '已删除资料' : document.title;
  }

  private updateLocalDocument(id: string, currentPage: number, pageCount?: number): void {
    const records = this.documents.slice();
    const index = records.findIndex((document: DocumentRecord): boolean => document.id === id);
    if (index < 0) {
      return;
    }
    records[index].currentPage = currentPage;
    records[index].lastReadAt = Date.now();
    if (pageCount !== undefined) {
      records[index].pageCount = pageCount;
    }
    this.documents = records;
  }

  private async persistReadPosition(pageIndex: number): Promise<void> {
    if (!this.isReady || this.activeDocumentId.length === 0) {
      return;
    }
    try {
      await this.libraryRepository.updateReadPosition(this.activeDocumentId, pageIndex);
      this.updateLocalDocument(this.activeDocumentId, pageIndex);
    } catch (error) {
      this.statusMessage = '阅读位置暂时无法保存，请检查存储空间';
    }
  }

  private parseErrorMessage(result: pdfService.ParseResult): string {
    if (result === pdfService.ParseResult.PARSE_ERROR_PASSWORD) {
      return '该 PDF 已加密，阅迹 1.0 暂不支持密码文件';
    }
    if (result === pdfService.ParseResult.PARSE_ERROR_FORMAT) {
      return 'PDF 格式损坏或不受支持';
    }
    if (result === pdfService.ParseResult.PARSE_ERROR_FILE) {
      return 'PDF 文件无法读取，沙箱副本可能已丢失';
    }
    if (result === pdfService.ParseResult.PARSE_ERROR_CERT) {
      return 'PDF 证书校验失败';
    }
    return 'PDF 加载失败，请换一份文件重试';
  }

  private async importPdf(): Promise<void> {
    if (this.editingEvidenceId.length > 0) {
      if (this.requestEditorDraftDiscard('EVIDENCE', 'IMPORT_PDF')) {
        return;
      }
      this.closeEditor('EVIDENCE');
    }
    if (this.requestEvidenceDraftDiscard('IMPORT_PDF')) {
      return;
    }
    const context = this.hostContext();
    if (context === undefined || this.isLoading || !this.isReady) {
      return;
    }
    this.isLoading = true;
    this.statusMessage = '正在复制 PDF 到阅迹本地资料库…';
    try {
      const imported = await this.importService.chooseAndCopyPdf(context);
      if (imported === undefined) {
        this.statusMessage = '已取消导入';
        return;
      }
      await this.finishPdfImport(imported);
    } catch (error) {
      this.statusMessage = '导入失败，请确认文件可访问且存储空间充足';
    } finally {
      this.isLoading = false;
    }
  }

  private async importPdfFromUri(uri: string): Promise<void> {
    if (this.editingEvidenceId.length > 0) {
      if (this.requestEditorDraftDiscard('EVIDENCE', 'IMPORT_DROPPED_PDF', '', uri)) {
        return;
      }
      this.closeEditor('EVIDENCE');
    }
    if (this.requestEvidenceDraftDiscard('IMPORT_DROPPED_PDF', '', uri)) {
      return;
    }
    const context = this.hostContext();
    if (context === undefined || this.isLoading || !this.isReady) {
      return;
    }
    this.isLoading = true;
    this.statusMessage = '正在复制拖入的 PDF 到本地资料库…';
    try {
      const imported = await this.importService.copyPdfFromUri(context, uri);
      await this.finishPdfImport(imported);
    } catch (error) {
      this.statusMessage = '拖放导入失败，请确认拖入的是可读取 PDF';
    } finally {
      this.isLoading = false;
    }
  }

  private async finishPdfImport(imported: ImportedPdf): Promise<void> {
    if (this.documentPath.length > 0) {
      this.pdfController.releaseDocument();
    }
    let result: pdfService.ParseResult;
    try {
      result = await this.pdfController.loadDocument(imported.record.source);
    } catch (error) {
      await this.importService.removeImportedPdf(imported.record.source);
      throw new Error('PDF parse failed');
    }
    if (result !== pdfService.ParseResult.PARSE_SUCCESS) {
      this.documentPath = '';
      this.statusMessage = this.parseErrorMessage(result);
      await this.importService.removeImportedPdf(imported.record.source);
      return;
    }
    imported.record.pageCount = this.pdfController.getPageCount();
    imported.record.currentPage = 0;
    try {
      await this.libraryRepository.insert(imported.record);
    } catch (error) {
      this.pdfController.releaseDocument();
      await this.importService.removeImportedPdf(imported.record.source);
      throw new Error('PDF metadata persistence failed');
    }
    await this.reloadData();
    this.activateLoadedPdf(imported.record);
    this.statusMessage = `已导入 ${imported.record.title}，共 ${imported.record.pageCount} 页`;
  }

  private activateLoadedPdf(record: DocumentRecord): void {
    this.activeDocumentId = record.id;
    this.documentPath = record.source;
    this.pageCount = record.pageCount;
    this.currentPage = record.currentPage + 1;
    this.pageInput = `${this.currentPage}`;
    this.searchText = '';
    this.searchedText = '';
    this.searchCount = 0;
    this.searchIndex = 0;
    this.searchGeneration++;
    this.resetEvidenceDraft();
    this.editingEvidenceId = '';
    this.mainView = 'READER';
    this.pdfController.setMaxZoom(4);
    this.pdfController.setMinZoom(0.5);
    this.pdfController.setPageFit(pdfService.PageFit.FIT_WIDTH);
    this.restoreDocumentAnnotations(record.id);
    this.prepareThumbnails(record.id, record.pageCount);
  }

  private async openDocument(record: DocumentRecord): Promise<void> {
    if (this.editingEvidenceId.length > 0) {
      if (this.requestEditorDraftDiscard('EVIDENCE', 'OPEN_DOCUMENT', record.id)) {
        return;
      }
      this.closeEditor('EVIDENCE');
    }
    if (record.kind === 'PDF') {
      if (this.isLoading) {
        return;
      }
      if (!this.importService.fileExists(record.source)) {
        this.statusMessage = `找不到“${record.title}”的本地 PDF 副本`;
        return;
      }
    }
    if (this.requestEvidenceDraftDiscard('OPEN_DOCUMENT', record.id)) {
      return;
    }
    if (record.kind === 'WEB') {
      await this.openWebSource(record);
      return;
    }
    this.isLoading = true;
    this.statusMessage = `正在打开 ${record.title}…`;
    try {
      if (this.documentPath.length > 0) {
        this.pdfController.releaseDocument();
      }
      const result = await this.pdfController.loadDocument(record.source, undefined, record.currentPage);
      if (result !== pdfService.ParseResult.PARSE_SUCCESS) {
        this.documentPath = '';
        this.statusMessage = this.parseErrorMessage(result);
        return;
      }
      const actualPageCount = this.pdfController.getPageCount();
      await this.libraryRepository.updatePdfMetadata(record.id, actualPageCount, record.currentPage);
      this.updateLocalDocument(record.id, record.currentPage, actualPageCount);
      record.pageCount = actualPageCount;
      this.activateLoadedPdf(record);
      this.statusMessage = `已打开 ${record.title}`;
    } catch (error) {
      this.documentPath = '';
      this.statusMessage = 'PDF 打开失败，请重新导入该资料';
    } finally {
      this.isLoading = false;
    }
  }

  private serializeSelection(rects: Array<pdfViewManager.SelectedRects>): string {
    const stored: StoredSelection[] = [];
    rects.forEach((selected: pdfViewManager.SelectedRects): void => {
      const rectArray: StoredPdfRect[] = [];
      selected.rectArray.forEach((rect: pdfService.PdfRect): void => {
        rectArray.push({
          left: rect.left,
          top: rect.top,
          right: rect.right,
          bottom: rect.bottom
        });
      });
      stored.push({
        pageIndex: selected.pageIndex,
        isRotated: selected.isRotated,
        rectArray: rectArray
      });
    });
    return JSON.stringify(stored);
  }

  private deserializeSelection(value: string): StoredSelection[] {
    if (value.length === 0) {
      return [];
    }
    try {
      return JSON.parse(value) as StoredSelection[];
    } catch (error) {
      return [];
    }
  }

  private storedPdfRects(rects: StoredPdfRect[]): Array<pdfService.PdfRect> {
    const result: Array<pdfService.PdfRect> = [];
    rects.forEach((stored: StoredPdfRect): void => {
      const rect = new pdfService.PdfRect();
      rect.left = stored.left;
      rect.top = stored.top;
      rect.right = stored.right;
      rect.bottom = stored.bottom;
      result.push(rect);
    });
    return result;
  }

  private selectedRectsFromCard(card: EvidenceCard): Array<pdfViewManager.SelectedRects> {
    const result: Array<pdfViewManager.SelectedRects> = [];
    this.deserializeSelection(card.rectsJson).forEach((stored: StoredSelection): void => {
      result.push(new pdfViewManager.SelectedRects(
        stored.pageIndex,
        this.storedPdfRects(stored.rectArray),
        stored.isRotated
      ));
    });
    return result;
  }

  private pageRectsFromCard(card: EvidenceCard): Array<pdfViewManager.PageRects> {
    const result: Array<pdfViewManager.PageRects> = [];
    this.deserializeSelection(card.rectsJson).forEach((stored: StoredSelection): void => {
      result.push(new pdfViewManager.PageRects(stored.pageIndex, this.storedPdfRects(stored.rectArray)));
    });
    return result;
  }

  private restoreDocumentAnnotations(documentId: string): void {
    this.evidenceCards
      .filter((card: EvidenceCard): boolean => card.documentId === documentId && card.rectsJson.length > 2)
      .forEach((card: EvidenceCard): void => {
        const rects = this.selectedRectsFromCard(card);
        if (rects.length === 0) {
          return;
        }
        const type = card.kind === 'UNDERLINE' ?
          pdfViewManager.SupportedAnnotationType.UNDERLINE :
          pdfViewManager.SupportedAnnotationType.HIGHLIGHT;
        this.pdfController.addMarkupAnnotation(type, rects, card.color);
      });
  }

  private async createEvidenceCard(): Promise<void> {
    if (this.isSavingEvidence) {
      return;
    }
    if (this.activeDocumentId.length === 0 || this.selectedText.trim().length === 0 || this.selectedRects.length === 0) {
      this.statusMessage = '请先在 PDF 中选择一段文字';
      return;
    }
    const documentId = this.activeDocumentId;
    const selectedText = this.selectedText.trim();
    const selectedRects = this.selectedRects;
    const note = this.evidenceNote.trim();
    const tags = normalizeTags(this.evidenceTags);
    const now = Date.now();
    const card: EvidenceCard = {
      id: createId('evidence'),
      documentId: documentId,
      quote: selectedText,
      pageIndex: selectedRects[0].pageIndex,
      rectsJson: this.serializeSelection(selectedRects),
      note: note,
      kind: this.evidenceKind,
      color: this.evidenceColor,
      tags: tags,
      reviewStatus: 'TO_REVIEW',
      createdAt: now,
      updatedAt: now
    };
    let databaseInserted = false;
    this.isSavingEvidence = true;
    this.statusMessage = '正在保存证据卡…';
    try {
      await this.evidenceRepository.insert(card);
      databaseInserted = true;
      const type = card.kind === 'UNDERLINE' ?
        pdfViewManager.SupportedAnnotationType.UNDERLINE :
        pdfViewManager.SupportedAnnotationType.HIGHLIGHT;
      this.pdfController.addMarkupAnnotation(type, selectedRects, card.color);
      this.evidenceCards = await this.evidenceRepository.listAll();
      this.resetEvidenceDraft();
      this.statusMessage = `证据卡已保存：${this.documentTitle(card.documentId)}，第 ${card.pageIndex + 1} 页`;
    } catch (error) {
      if (databaseInserted) {
        try {
          await this.evidenceRepository.delete(card.id);
          this.evidenceCards = await this.evidenceRepository.listAll();
        } catch (cleanupError) {
          this.statusMessage = '证据卡标注失败，且本地记录清理失败，请重启应用后删除异常卡片';
          return;
        }
      }
      this.statusMessage = '证据卡保存失败，请检查本地存储空间';
    } finally {
      this.isSavingEvidence = false;
    }
  }

  private startEditEvidence(card: EvidenceCard): void {
    if (this.editingEvidenceId === card.id) {
      return;
    }
    if (this.editingEvidenceId.length > 0) {
      if (this.requestEditorDraftDiscard('EVIDENCE', 'EDIT_EVIDENCE', card.id)) {
        return;
      }
      this.closeEditor('EVIDENCE');
    }
    this.editingEvidenceId = card.id;
    this.editingEvidenceNote = card.note;
    this.editingEvidenceTags = card.tags;
  }

  private async saveEvidenceEdit(card: EvidenceCard): Promise<void> {
    if (this.isSavingEditor) {
      return;
    }
    const note = this.editingEvidenceNote.trim();
    const tags = normalizeTags(this.editingEvidenceTags);
    this.isSavingEditor = true;
    this.statusMessage = '正在保存证据卡修改…';
    try {
      await this.evidenceRepository.updateCard(
        card.id,
        note,
        tags,
        card.reviewStatus
      );
      this.evidenceCards = await this.evidenceRepository.listAll();
      this.closeEditor('EVIDENCE');
      this.statusMessage = '证据卡修改已保存';
    } catch (error) {
      this.statusMessage = '证据卡修改保存失败';
    } finally {
      this.isSavingEditor = false;
    }
  }

  private async toggleEvidenceStatus(card: EvidenceCard): Promise<void> {
    const next: ReviewStatus = card.reviewStatus === 'MASTERED' ? 'TO_REVIEW' : 'MASTERED';
    try {
      await this.evidenceRepository.setReviewStatus(card.id, next);
      this.evidenceCards = await this.evidenceRepository.listAll();
      this.statusMessage = next === 'MASTERED' ? '已标记为掌握' : '已加入待复习';
    } catch (error) {
      this.statusMessage = '复习状态保存失败';
    }
  }

  private async deleteEvidence(card: EvidenceCard): Promise<void> {
    try {
      await this.evidenceRepository.delete(card.id);
      this.evidenceCards = await this.evidenceRepository.listAll();
      if (card.documentId === this.activeDocumentId) {
        const document = this.activeDocument();
        if (document !== undefined) {
          await this.reloadActivePdf(document);
        }
      }
      this.statusMessage = '证据卡与对应阅迹标注已删除';
    } catch (error) {
      this.statusMessage = '证据卡删除失败';
    }
  }

  private async reloadActivePdf(document: DocumentRecord): Promise<void> {
    const pageIndex = Math.max(0, this.currentPage - 1);
    this.pdfController.releaseDocument();
    const result = await this.pdfController.loadDocument(document.source, undefined, pageIndex);
    if (result === pdfService.ParseResult.PARSE_SUCCESS) {
      this.pdfController.setPageFit(pdfService.PageFit.FIT_WIDTH);
      this.restoreDocumentAnnotations(document.id);
    }
  }

  private async returnToEvidence(card: EvidenceCard): Promise<void> {
    const document = this.documentById(card.documentId);
    if (document === undefined) {
      this.statusMessage = '原始资料已删除，证据内容仍保留';
      return;
    }
    if (this.editingEvidenceId.length > 0) {
      if (this.requestEditorDraftDiscard('EVIDENCE', 'RETURN_TO_EVIDENCE', card.id)) {
        return;
      }
      this.closeEditor('EVIDENCE');
    }
    if (this.requestEvidenceDraftDiscard('RETURN_TO_EVIDENCE', card.id)) {
      return;
    }
    if (document.kind === 'WEB') {
      await this.openWebSource(document);
      return;
    }
    if (this.activeDocumentId !== document.id || this.documentPath.length === 0) {
      await this.openDocument(document);
    }
    if (this.activeDocumentId !== document.id || this.documentPath.length === 0) {
      return;
    }
    this.pdfController.goToPage(card.pageIndex);
    const pageRects = this.pageRectsFromCard(card);
    if (pageRects.length > 0) {
      this.pdfController.setHighlightRects(pageRects, 0x66FF725E);
    }
    this.mainView = 'READER';
    this.rightSidebarOpen = true;
    this.statusMessage = `已返回 ${document.title} 第 ${card.pageIndex + 1} 页`;
  }

  private changeZoom(delta: number): void {
    if (this.documentPath.length === 0) {
      return;
    }
    const nextZoom = Math.max(50, Math.min(400, this.zoomPercent + delta));
    this.pdfController.setPageZoom(nextZoom / 100);
    this.zoomPercent = nextZoom;
  }

  private goToPage(value: string): void {
    if (this.pageCount === 0) {
      return;
    }
    const page = Number(value);
    if (!Number.isInteger(page) || page < 1 || page > this.pageCount) {
      this.pageInput = `${this.currentPage}`;
      this.statusMessage = `请输入 1-${this.pageCount} 的页码`;
      return;
    }
    this.pdfController.goToPage(page - 1);
  }

  private clearPdfSearch(message: string = ''): void {
    this.searchGeneration++;
    this.searchedText = '';
    this.searchCount = 0;
    this.searchIndex = 0;
    if (this.documentPath.length > 0) {
      this.pdfController.clearSearch();
    }
    if (message.length > 0) {
      this.statusMessage = message;
    }
  }

  private runSearch(): void {
    const keyword = this.searchText.trim();
    if (this.documentPath.length === 0) {
      return;
    }
    if (keyword.length === 0) {
      this.clearPdfSearch('请输入要搜索的内容');
      return;
    }
    const generation = ++this.searchGeneration;
    this.searchedText = keyword;
    this.pdfController.searchKey(keyword, (count: number): void => {
      if (generation !== this.searchGeneration || this.searchText.trim() !== keyword) {
        return;
      }
      this.searchCount = count;
      this.searchIndex = count > 0 ? 1 : 0;
      this.statusMessage = count > 0 ? `找到 ${count} 处“${keyword}”` : `没有找到“${keyword}”`;
    });
  }

  private moveSearch(delta: number): void {
    if (this.searchCount === 0) {
      return;
    }
    const next = (this.searchIndex - 1 + delta + this.searchCount) % this.searchCount;
    this.pdfController.setSearchIndex(next);
    this.searchIndex = next + 1;
  }

  private activeEvidenceCards(): EvidenceCard[] {
    return this.evidenceCards
      .filter((card: EvidenceCard): boolean => card.documentId === this.activeDocumentId)
      .sort((left: EvidenceCard, right: EvidenceCard): number => left.pageIndex - right.pageIndex);
  }

  private evidenceCountForDocument(documentId: string): number {
    return this.evidenceCards.filter((card: EvidenceCard): boolean => card.documentId === documentId).length;
  }

  private pendingCountForDocument(documentId: string): number {
    return this.evidenceCards.filter((card: EvidenceCard): boolean =>
      card.documentId === documentId && card.reviewStatus === 'TO_REVIEW').length;
  }

  private documentProgress(document: DocumentRecord): number {
    if (document.kind !== 'PDF' || document.pageCount <= 0) {
      return 0;
    }
    return Math.min(100, Math.max(1, Math.round((document.currentPage + 1) * 100 / document.pageCount)));
  }

  private documentRenderKey(document: DocumentRecord): string {
    return `${document.id}:${document.lastReadAt}:${document.currentPage}:${document.favorite ? 1 : 0}:` +
      `${document.pageCount}:${document.title}:${document.tags}:${this.evidenceCountForDocument(document.id)}:` +
      `${this.pendingCountForDocument(document.id)}`;
  }

  private evidenceRenderKey(card: EvidenceCard): string {
    return `${card.id}:${card.updatedAt}:${card.reviewStatus}:${card.kind}:${card.color}:${card.pageIndex}:` +
      `${card.quote}:${card.note}:${card.tags}`;
  }

  private recentPdfDocument(): DocumentRecord | undefined {
    return this.documents
      .filter((document: DocumentRecord): boolean => document.kind === 'PDF')
      .sort((left: DocumentRecord, right: DocumentRecord): number => right.lastReadAt - left.lastReadAt)[0];
  }

  private reviewCount(filter: ReviewFilter): number {
    return this.evidenceCards.filter((card: EvidenceCard): boolean =>
      filter === 'ALL' || card.reviewStatus === filter).length;
  }

  private evidenceKindLabel(kind: EvidenceKind): string {
    if (kind === 'UNDERLINE') {
      return '下划线';
    }
    if (kind === 'QUOTE') {
      return '摘录';
    }
    return '高亮';
  }

  private evidenceSourceLabel(card: EvidenceCard): string {
    const document = this.documentById(card.documentId);
    if (document === undefined) {
      return '已删除资料';
    }
    return document.kind === 'WEB' ? `${document.title} · 网页摘录` :
      `${document.title} · 第 ${card.pageIndex + 1} 页`;
  }

  private filteredDocuments(): DocumentRecord[] {
    const keyword = this.librarySearch.trim().toLowerCase();
    const recentLimit = Date.now() - 1000 * 60 * 60 * 24 * 30;
    return this.documents.filter((document: DocumentRecord): boolean => {
      if (this.libraryScope === 'FAVORITE' && !document.favorite) {
        return false;
      }
      if (this.libraryScope === 'RECENT' && document.lastReadAt < recentLimit) {
        return false;
      }
      if (this.selectedTag.length > 0 && !tagList(document.tags).includes(this.selectedTag)) {
        const hasEvidenceTag = this.evidenceCards.some((card: EvidenceCard): boolean =>
          card.documentId === document.id && tagList(card.tags).includes(this.selectedTag));
        if (!hasEvidenceTag) {
          return false;
        }
      }
      if (keyword.length === 0) {
        return true;
      }
      return document.title.toLowerCase().includes(keyword) ||
        document.tags.toLowerCase().includes(keyword) ||
        document.source.toLowerCase().includes(keyword);
    });
  }

  private matchesReviewQuery(card: EvidenceCard): boolean {
    const keyword = this.reviewSearch.trim().toLowerCase();
    if (this.reviewSelectedTag.length > 0 && !tagList(card.tags).includes(this.reviewSelectedTag)) {
      return false;
    }
    if (keyword.length === 0) {
      return true;
    }
    return card.quote.toLowerCase().includes(keyword) ||
      card.note.toLowerCase().includes(keyword) ||
      card.tags.toLowerCase().includes(keyword) ||
      this.documentTitle(card.documentId).toLowerCase().includes(keyword);
  }

  private filteredReviewCards(): EvidenceCard[] {
    return this.evidenceCards.filter((card: EvidenceCard): boolean => {
      if (this.reviewFilter !== 'ALL' && card.reviewStatus !== this.reviewFilter) {
        return false;
      }
      return this.matchesReviewQuery(card);
    });
  }

  private reviewQueueCards(): EvidenceCard[] {
    return this.evidenceCards
      .filter((card: EvidenceCard): boolean =>
        card.reviewStatus === 'TO_REVIEW' && this.matchesReviewQuery(card))
      .sort((left: EvidenceCard, right: EvidenceCard): number => {
        const updatedDifference = left.updatedAt - right.updatedAt;
        return updatedDifference !== 0 ? updatedDifference : left.createdAt - right.createdAt;
      });
  }

  private reviewSessionCard(): EvidenceCard | undefined {
    if (this.reviewSessionIndex < 0 || this.reviewSessionIndex >= this.reviewSessionIds.length) {
      return undefined;
    }
    const id = this.reviewSessionIds[this.reviewSessionIndex];
    return this.evidenceCards.find((card: EvidenceCard): boolean => card.id === id);
  }

  private startReviewSession(): void {
    const cards = this.reviewQueueCards();
    if (cards.length === 0) {
      this.statusMessage = '当前搜索和标签范围内没有待复习证据';
      return;
    }
    this.reviewSessionIds = cards.map((card: EvidenceCard): string => card.id);
    this.reviewSessionIndex = 0;
    this.reviewSessionReviewedCount = 0;
    this.reviewSessionMasteredCount = 0;
    this.isReviewSessionUpdating = false;
    this.reviewSessionSourceOpen = false;
    this.statusMessage = `已开始专注复习，共 ${cards.length} 张证据卡`;
  }

  private requestStartReviewSession(): void {
    if (this.editingEvidenceId.length > 0) {
      if (this.requestEditorDraftDiscard('EVIDENCE', 'START_REVIEW_SESSION')) {
        return;
      }
      this.closeEditor('EVIDENCE');
    }
    if (this.requestEvidenceDraftDiscard('START_REVIEW_SESSION')) {
      return;
    }
    this.startReviewSession();
  }

  private resetReviewSession(): void {
    if (this.reviewSessionSourceOpen) {
      this.rightSidebarOpen = this.reviewSessionSourceRightSidebarOpen;
    }
    this.reviewSessionIds = [];
    this.reviewSessionIndex = 0;
    this.reviewSessionReviewedCount = 0;
    this.reviewSessionMasteredCount = 0;
    this.isReviewSessionUpdating = false;
    this.reviewSessionSourceOpen = false;
  }

  private finishReviewSession(message: string): void {
    const reviewedCount = this.reviewSessionReviewedCount;
    const masteredCount = this.reviewSessionMasteredCount;
    this.resetReviewSession();
    this.statusMessage = `${message}：处理 ${reviewedCount} 张，掌握 ${masteredCount} 张`;
  }

  private closeReviewSession(): void {
    if (this.isReviewSessionUpdating) {
      return;
    }
    this.finishReviewSession('已结束专注复习');
  }

  private advanceReviewSession(): void {
    if (this.reviewSessionIndex + 1 >= this.reviewSessionIds.length) {
      this.finishReviewSession('本轮复习完成');
      return;
    }
    this.reviewSessionIndex += 1;
    this.statusMessage =
      `专注复习 ${this.reviewSessionIndex + 1}/${this.reviewSessionIds.length}`;
  }

  private skipReviewSessionCard(): void {
    if (this.isReviewSessionUpdating) {
      return;
    }
    this.advanceReviewSession();
  }

  private async setReviewSessionStatus(status: ReviewStatus): Promise<void> {
    if (this.isReviewSessionUpdating) {
      return;
    }
    const card = this.reviewSessionCard();
    if (card === undefined) {
      this.finishReviewSession('复习队列已结束');
      return;
    }
    this.isReviewSessionUpdating = true;
    this.statusMessage = status === 'MASTERED' ? '正在标记掌握…' : '正在保留待复习状态…';
    try {
      await this.evidenceRepository.setReviewStatus(card.id, status);
      this.evidenceCards = await this.evidenceRepository.listAll();
      this.reviewSessionReviewedCount += 1;
      if (status === 'MASTERED') {
        this.reviewSessionMasteredCount += 1;
      }
      this.advanceReviewSession();
    } catch (error) {
      this.statusMessage = '复习状态保存失败，当前卡片仍保留';
    } finally {
      this.isReviewSessionUpdating = false;
    }
  }

  private async returnToReviewSessionSource(): Promise<void> {
    if (this.isReviewSessionUpdating) {
      return;
    }
    const card = this.reviewSessionCard();
    if (card === undefined) {
      this.finishReviewSession('复习队列已结束');
      return;
    }
    const document = this.documentById(card.documentId);
    if (document === undefined || document.kind !== 'PDF') {
      this.statusMessage = '当前证据的 PDF 来源已不可用';
      return;
    }
    const previousRightSidebarOpen = this.rightSidebarOpen;
    await this.returnToEvidence(card);
    if (this.mainView !== 'READER' ||
      this.activeDocumentId !== document.id ||
      this.documentPath.length === 0) {
      return;
    }
    this.reviewSessionSourceRightSidebarOpen = previousRightSidebarOpen;
    this.rightSidebarOpen = false;
    this.reviewSessionSourceOpen = true;
    this.statusMessage =
      `正在核对第 ${this.reviewSessionIndex + 1}/${this.reviewSessionIds.length} 张证据的原文`;
  }

  private resumeReviewSession(): void {
    if (this.isReviewSessionUpdating) {
      return;
    }
    const card = this.reviewSessionCard();
    if (card === undefined) {
      this.finishReviewSession('复习队列已结束');
      return;
    }
    this.reviewSessionSourceOpen = false;
    this.rightSidebarOpen = this.reviewSessionSourceRightSidebarOpen;
    this.mainView = 'REVIEW';
    this.statusMessage =
      `已返回专注复习，第 ${this.reviewSessionIndex + 1}/${this.reviewSessionIds.length} 张`;
  }

  private showLibrary(scope: LibraryScope): void {
    if (this.requestEvidenceDraftDiscard('SHOW_LIBRARY', scope)) {
      return;
    }
    this.mainView = 'LIBRARY';
    this.libraryScope = scope;
    this.closeCompactNavigation();
  }

  private showReview(): void {
    if (this.requestEvidenceDraftDiscard('SHOW_REVIEW')) {
      return;
    }
    this.mainView = 'REVIEW';
    this.closeCompactNavigation();
  }

  private hasLibraryFilters(): boolean {
    return this.librarySearch.trim().length > 0 || this.selectedTag.length > 0;
  }

  private clearLibraryFilters(): void {
    this.librarySearch = '';
    this.selectedTag = '';
    this.statusMessage = '已清除资料筛选';
  }

  private hasReviewFilters(): boolean {
    return this.reviewSearch.trim().length > 0 ||
      this.reviewSelectedTag.length > 0 ||
      this.reviewFilter !== 'ALL';
  }

  private clearReviewFilters(): void {
    this.reviewSearch = '';
    this.reviewSelectedTag = '';
    this.reviewFilter = 'ALL';
    this.statusMessage = '已清除复习筛选';
  }

  private allTags(): string[] {
    const values: string[] = [];
    this.documents.forEach((document: DocumentRecord): void => {
      tagList(document.tags).forEach((tag: string): void => {
        if (!values.includes(tag)) {
          values.push(tag);
        }
      });
    });
    this.evidenceCards.forEach((card: EvidenceCard): void => {
      tagList(card.tags).forEach((tag: string): void => {
        if (!values.includes(tag)) {
          values.push(tag);
        }
      });
    });
    return values.sort();
  }

  private async toggleFavorite(document: DocumentRecord): Promise<void> {
    try {
      await this.libraryRepository.setFavorite(document.id, !document.favorite);
      await this.reloadData();
      this.statusMessage = document.favorite ? '已取消收藏' : '已加入收藏';
    } catch (error) {
      this.statusMessage = '收藏状态保存失败';
    }
  }

  private async deleteDocument(document: DocumentRecord): Promise<void> {
    try {
      if (document.id === this.activeDocumentId && this.documentPath.length > 0) {
        this.pdfController.releaseDocument();
        this.documentPath = '';
        this.activeDocumentId = '';
        this.mainView = 'LIBRARY';
      }
      await this.evidenceRepository.deleteByDocument(document.id);
      await this.libraryRepository.delete(document.id);
      if (document.kind === 'PDF' && this.importService.fileExists(document.source)) {
        await fs.unlink(document.source);
        const lastSlash = document.source.lastIndexOf('/');
        if (lastSlash > 0) {
          await fs.rmdir(document.source.substring(0, lastSlash));
        }
      }
      await this.reloadData();
      this.statusMessage = `已从本地资料库删除 ${document.title}`;
    } catch (error) {
      this.statusMessage = '资料已从列表移除，但部分本地文件可能需要稍后清理';
      await this.reloadData();
    }
  }

  private requestDeleteDocument(document: DocumentRecord): void {
    if (this.editingEvidenceId.length > 0) {
      if (this.requestEditorDraftDiscard('EVIDENCE', 'DELETE_DOCUMENT', document.id)) {
        return;
      }
      this.closeEditor('EVIDENCE');
    }
    if (document.id === this.activeDocumentId &&
      this.requestEvidenceDraftDiscard('DELETE_DOCUMENT', document.id)) {
      return;
    }
    this.showWebEditor = false;
    this.showPdfEditor = false;
    this.deleteTargetKind = 'DOCUMENT';
    this.deleteTargetId = document.id;
  }

  private requestDeleteEvidence(card: EvidenceCard): void {
    if (this.editingEvidenceId.length > 0) {
      if (this.requestEditorDraftDiscard('EVIDENCE', 'DELETE_EVIDENCE', card.id)) {
        return;
      }
      this.closeEditor('EVIDENCE');
    }
    this.deleteTargetKind = 'EVIDENCE';
    this.deleteTargetId = card.id;
  }

  private cancelDelete(): void {
    if (this.isDeleting) {
      return;
    }
    this.deleteTargetKind = 'NONE';
    this.deleteTargetId = '';
  }

  private pendingDeleteDocument(): DocumentRecord | undefined {
    if (this.deleteTargetKind !== 'DOCUMENT') {
      return undefined;
    }
    return this.documentById(this.deleteTargetId);
  }

  private pendingDeleteEvidence(): EvidenceCard | undefined {
    if (this.deleteTargetKind !== 'EVIDENCE') {
      return undefined;
    }
    return this.evidenceCards.find((card: EvidenceCard): boolean => card.id === this.deleteTargetId);
  }

  private deleteDialogTitle(): string {
    return this.deleteTargetKind === 'DOCUMENT' ? '删除这份资料？' : '删除这张证据卡？';
  }

  private deleteDialogTarget(): string {
    const document = this.pendingDeleteDocument();
    if (document !== undefined) {
      return document.title;
    }
    const card = this.pendingDeleteEvidence();
    return card === undefined ? '目标内容已不存在' : card.quote;
  }

  private deleteDialogMessage(): string {
    const document = this.pendingDeleteDocument();
    if (document !== undefined) {
      const evidenceCount = this.evidenceCountForDocument(document.id);
      const sourceMessage = document.kind === 'PDF' ?
        '应用沙箱中的 PDF 副本也会被移除。' :
        '保存的网址、摘录和笔记也会被移除。';
      return `将同时删除 ${evidenceCount} 张关联证据卡。${sourceMessage}此操作无法撤销。`;
    }
    return 'PDF 上对应的阅迹标注也会被移除，原始 PDF 文件不受影响。此操作无法撤销。';
  }

  private async confirmDelete(): Promise<void> {
    if (this.isDeleting) {
      return;
    }
    const document = this.pendingDeleteDocument();
    const card = this.pendingDeleteEvidence();
    if (document === undefined && card === undefined) {
      this.cancelDelete();
      this.statusMessage = '删除目标已不存在';
      return;
    }
    this.isDeleting = true;
    try {
      if (document !== undefined) {
        await this.deleteDocument(document);
      } else if (card !== undefined) {
        await this.deleteEvidence(card);
      }
    } finally {
      this.isDeleting = false;
      this.cancelDelete();
    }
  }

  private startAddWeb(): void {
    if (this.requestEvidenceDraftDiscard('ADD_WEB')) {
      return;
    }
    this.showPdfEditor = false;
    this.editingWebId = '';
    this.webTitle = '';
    this.webUrl = '';
    this.webExcerpt = '';
    this.webNote = '';
    this.webTags = '';
    this.showWebEditor = true;
  }

  private startEditWeb(document: DocumentRecord): void {
    this.showPdfEditor = false;
    this.editingWebId = document.id;
    this.webTitle = document.title;
    this.webUrl = document.source;
    this.webExcerpt = document.excerpt;
    this.webNote = document.note;
    this.webTags = document.tags;
    this.showWebEditor = true;
  }

  private startEditPdf(document: DocumentRecord): void {
    this.showWebEditor = false;
    this.editingPdfId = document.id;
    this.pdfTitle = document.title;
    this.pdfTags = document.tags;
    this.showPdfEditor = true;
  }

  private async savePdfDocument(): Promise<void> {
    if (this.isSavingEditor) {
      return;
    }
    const title = this.pdfTitle.trim();
    if (title.length === 0) {
      this.statusMessage = '资料标题不能为空';
      return;
    }
    const tags = normalizeTags(this.pdfTags);
    this.isSavingEditor = true;
    this.statusMessage = '正在保存 PDF 资料信息…';
    try {
      await this.libraryRepository.updatePdfDetails(
        this.editingPdfId,
        title,
        tags
      );
      await this.reloadData();
      this.closeEditor('PDF');
      this.statusMessage = 'PDF 资料信息已更新';
    } catch (error) {
      this.statusMessage = 'PDF 资料信息保存失败';
    } finally {
      this.isSavingEditor = false;
    }
  }

  private async saveWebDocument(): Promise<void> {
    if (this.isSavingEditor) {
      return;
    }
    if (!this.linkService.isValidUrl(this.webUrl)) {
      this.statusMessage = '网址无效，请输入完整域名，例如 https://example.com';
      return;
    }
    const draft: WebDraft = {
      title: this.webTitle,
      url: this.webUrl,
      excerpt: this.webExcerpt,
      note: this.webNote,
      tags: this.webTags
    };
    const isNewDocument = this.editingWebId.length === 0;
    const editingWebId = this.editingWebId;
    this.isSavingEditor = true;
    this.statusMessage = '正在保存网页资料卡…';
    try {
      if (isNewDocument) {
        await this.libraryRepository.insert(this.linkService.createDocument(draft));
      } else {
        await this.libraryRepository.updateWebDetails(
          editingWebId,
          draft.title.trim().length > 0 ? draft.title.trim() : this.linkService.normalizeUrl(draft.url),
          this.linkService.normalizeUrl(draft.url),
          draft.excerpt.trim(),
          draft.note.trim(),
          normalizeTags(draft.tags)
        );
      }
      await this.reloadData();
      this.closeEditor('WEB');
      this.statusMessage = isNewDocument ? '网页资料卡已保存' : '网页资料卡已更新';
    } catch (error) {
      this.statusMessage = '网页资料卡保存失败';
    } finally {
      this.isSavingEditor = false;
    }
  }

  private async openWebSource(document: DocumentRecord): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) {
      return;
    }
    try {
      await this.linkService.open(context, document.source);
      try {
        await this.libraryRepository.updateLastReadAt(document.id);
        await this.reloadData();
      } catch (storageError) {
        this.statusMessage = `已打开 ${document.title}，但最近阅读时间未能保存`;
        return;
      }
      this.statusMessage = `已通过系统浏览器打开 ${document.title}`;
    } catch (error) {
      this.statusMessage = '无法打开网址，请检查网址或默认浏览器设置';
    }
  }

  private async exportDocuments(documents: DocumentRecord[], cards: EvidenceCard[], title: string): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) {
      return;
    }
    if (documents.length === 0) {
      this.statusMessage = '当前范围没有可导出的资料';
      return;
    }
    try {
      const content = this.exportService.buildMarkdown(documents, cards, title);
      const saved = await this.exportService.exportMarkdown(context, content);
      this.statusMessage = saved ? 'Markdown 学习笔记已导出' : '已取消导出';
    } catch (error) {
      this.statusMessage = '导出失败，请检查目标位置是否可写';
    }
  }

  private exportCurrentView(): void {
    if (this.mainView === 'READER') {
      const document = this.activeDocument();
      if (document !== undefined) {
        this.exportDocuments([document], this.activeEvidenceCards(), `${document.title} - 阅迹学习笔记`);
      }
      return;
    }
    if (this.mainView === 'REVIEW') {
      const cards = this.filteredReviewCards();
      const ids: string[] = [];
      cards.forEach((card: EvidenceCard): void => {
        if (!ids.includes(card.documentId)) {
          ids.push(card.documentId);
        }
      });
      const documents = this.documents.filter((document: DocumentRecord): boolean => ids.includes(document.id));
      this.exportDocuments(documents, cards, '阅迹复习笔记');
      return;
    }
    const documents = this.filteredDocuments();
    let cards = this.evidenceCards;
    let title = '阅迹学习笔记';
    if (this.selectedTag.length > 0) {
      const documentIds = documents.map((document: DocumentRecord): string => document.id);
      cards = cards.filter((card: EvidenceCard): boolean =>
        documentIds.includes(card.documentId) && tagList(card.tags).includes(this.selectedTag));
      title = `阅迹学习笔记 - #${this.selectedTag}`;
    }
    this.exportDocuments(documents, cards, title);
  }

  private saveSettings(): void {
    const settings: AppSettings = {
      darkMode: this.darkMode,
      focusMode: this.focusMode,
      leftSidebarOpen: this.leftSidebarOpen,
      rightSidebarOpen: this.rightSidebarOpen,
      defaultHighlightColor: this.evidenceColor
    };
    this.settingsService.save(settings).catch((): void => {
      this.statusMessage = '界面设置暂时无法保存，请检查本地存储空间';
    });
  }

  private toggleDarkMode(): void {
    this.darkMode = !this.darkMode;
    this.saveSettings();
  }

  private toggleFocusMode(): void {
    this.focusMode = !this.focusMode;
    this.saveSettings();
  }

  private prepareThumbnails(documentId: string, count: number): void {
    const generation = ++this.thumbnailGeneration;
    const oldItems = this.thumbnails;
    const items: ThumbnailRecord[] = [];
    for (let index = 0; index < count; index++) {
      items.push({ pageIndex: index });
    }
    this.thumbnails = items;
    this.thumbnailLoadCount = 0;
    this.releaseThumbnailItems(oldItems);
    this.loadThumbnails(documentId, Math.min(count, 18), generation);
  }

  private async loadThumbnails(documentId: string, count: number, generation: number): Promise<void> {
    for (let index = 0; index < count; index++) {
      if (generation !== this.thumbnailGeneration ||
        documentId !== this.activeDocumentId ||
        this.documentPath.length === 0) {
        return;
      }
      try {
        const pixelMap = await this.pdfController.getPagePixelMap(index);
        if (generation !== this.thumbnailGeneration ||
          documentId !== this.activeDocumentId ||
          index >= this.thumbnails.length) {
          await pixelMap.release();
          return;
        }
        const items = this.thumbnails.slice();
        items[index] = { pageIndex: index, pixelMap: pixelMap };
        this.thumbnails = items;
        this.thumbnailLoadCount = index + 1;
      } catch (error) {
        return;
      }
    }
  }

  private async releaseThumbnails(): Promise<void> {
    this.thumbnailGeneration++;
    const oldItems = this.thumbnails;
    this.thumbnails = [];
    await this.releaseThumbnailItems(oldItems);
  }

  private async releaseThumbnailItems(items: ThumbnailRecord[]): Promise<void> {
    for (let index = 0; index < items.length; index++) {
      const pixelMap = items[index].pixelMap;
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (error) {
        }
      }
    }
  }

  private uriFromDragValue(value: unifiedDataChannel.ValueType): string {
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'object' && value !== null) {
      const fileUri = value as uniformDataStruct.FileUri;
      if (typeof fileUri.oriUri === 'string') {
        return fileUri.oriUri;
      }
    }
    return '';
  }

  private handleDrop(event: DragEvent): void {
    this.isDragOver = false;
    try {
      const records = event.getData().getRecords();
      for (let index = 0; index < records.length; index++) {
        const record = records[index];
        let value = record.getValue();
        if (record.getType() !== 'general.file-uri') {
          value = record.getEntry('general.file-uri');
        }
        const uri = this.uriFromDragValue(value);
        if (uri.length > 0) {
          event.setResult(DragResult.DRAG_SUCCESSFUL);
          this.importPdfFromUri(uri);
          return;
        }
      }
      event.setResult(DragResult.DRAG_FAILED);
      this.statusMessage = '未识别到可读取的 PDF 文件';
    } catch (error) {
      event.setResult(DragResult.DRAG_FAILED);
      this.statusMessage = '拖放数据读取失败，请使用“导入 PDF”选择文件';
    }
  }

  private formatDate(value: number): string {
    const date = new Date(value);
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    return `${month}-${day}`;
  }

  private pageBackground(): string {
    return this.darkMode ? '#171C1A' : '#F4F6F5';
  }

  private panelBackground(): string {
    return this.darkMode ? '#202624' : '#FAFBFA';
  }

  private raisedBackground(): string {
    return this.darkMode ? '#29302D' : '#FFFFFF';
  }

  private readerBackground(): string {
    return this.darkMode ? '#111513' : '#E9ECEA';
  }

  private primaryText(): string {
    return this.darkMode ? '#EDF2F0' : '#202724';
  }

  private secondaryText(): string {
    return this.darkMode ? '#AFBAB6' : '#6D7773';
  }

  private mutedText(): string {
    return this.darkMode ? '#82908B' : '#89928F';
  }

  private dividerColor(): string {
    return this.darkMode ? '#39423E' : '#DDE2DF';
  }

  private accentColor(): string {
    return this.darkMode ? '#54B9AD' : '#147D73';
  }

  private accentSoft(): string {
    return this.darkMode ? '#24443F' : '#DDEDEA';
  }

  private coralSoft(): string {
    return this.darkMode ? '#49322E' : '#FBE4DF';
  }

  private coralColor(): string {
    return this.darkMode ? '#FF8D7D' : '#D95F4E';
  }

  private highlightPreviewBackground(): string {
    return this.darkMode ? '#4B4320' : '#FFF4BE';
  }

  private highlightPreviewText(): string {
    return this.darkMode ? '#F7EFCB' : '#34413D';
  }

  private highlightActiveBackground(): string {
    return this.darkMode ? '#625621' : '#FFE47A';
  }

  private highlightActiveBorder(): string {
    return this.darkMode ? '#BDA94D' : '#E3C343';
  }

  private scrimColor(): string {
    return this.darkMode ? '#88000000' : '#66000000';
  }

  private compactEditorWidth(preferredWidth: number): number {
    return Math.min(preferredWidth, Math.max(320, this.windowWidth - 32));
  }

  private compactEditorHeight(preferredHeight: number): number {
    return Math.min(preferredHeight, Math.max(320, this.windowHeight - 32));
  }

  private compactReaderToolbar(): boolean {
    return this.windowWidth < 900 && this.rightSidebarOpen && !this.focusMode;
  }

  private closeCompactNavigation(): void {
    if (this.windowWidth < 1100) {
      this.leftSidebarOpen = false;
      this.saveSettings();
    }
  }

  private saveActiveEditingContext(): boolean {
    if (this.showWebEditor) {
      if (!this.isSavingEditor) {
        this.saveWebDocument();
      }
      return true;
    }
    if (this.showPdfEditor) {
      if (!this.isSavingEditor) {
        this.savePdfDocument();
      }
      return true;
    }
    if (this.editingEvidenceId.length > 0) {
      if (this.isSavingEditor) {
        return true;
      }
      const card = this.evidenceCards.find(
        (item: EvidenceCard): boolean => item.id === this.editingEvidenceId
      );
      if (card === undefined) {
        this.statusMessage = '当前证据卡已不存在，无法保存修改';
        return true;
      }
      this.saveEvidenceEdit(card);
      return true;
    }
    if (this.hasEvidenceDraft()) {
      if (!this.isSavingEvidence) {
        this.createEvidenceCard();
      }
      return true;
    }
    return false;
  }

  private shortcutModifierPressed(event: KeyEvent): boolean {
    let controlPressed = false;
    if (event.getModifierKeyState !== undefined) {
      try {
        controlPressed = event.getModifierKeyState(['ctrl']);
      } catch (error) {
      }
    }
    return controlPressed || event.metaKey === 1;
  }

  private handleEditingShortcut(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down || !this.shortcutModifierPressed(event)) {
      return false;
    }
    const submitShortcut = event.keyCode === KeyCode.KEYCODE_S ||
      event.keyCode === KeyCode.KEYCODE_ENTER ||
      event.keyCode === KeyCode.KEYCODE_NUMPAD_ENTER;
    if (!submitShortcut) {
      return false;
    }
    if (this.reviewSessionIds.length > 0 ||
      this.editorDraftAction !== 'NONE' ||
      this.evidenceDraftAction !== 'NONE' ||
      this.deleteTargetKind !== 'NONE') {
      return true;
    }
    return this.saveActiveEditingContext();
  }

  private handleShortcut(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down) {
      return false;
    }
    const modifier = this.shortcutModifierPressed(event);
    if (!modifier) {
      if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
        if (this.reviewSessionIds.length > 0) {
          if (this.reviewSessionSourceOpen) {
            this.resumeReviewSession();
          } else {
            this.closeReviewSession();
          }
          return true;
        }
        if (this.editorDraftAction !== 'NONE') {
          this.cancelEditorDraftDiscard();
          return true;
        }
        if (this.evidenceDraftAction !== 'NONE') {
          this.cancelEvidenceDraftDiscard();
          return true;
        }
        if (this.deleteTargetKind !== 'NONE') {
          this.cancelDelete();
          return true;
        }
        if (this.showWebEditor) {
          this.requestCloseEditor('WEB');
          return true;
        }
        if (this.showPdfEditor) {
          this.requestCloseEditor('PDF');
          return true;
        }
        if (this.editingEvidenceId.length > 0) {
          this.requestCloseEditor('EVIDENCE');
          return true;
        }
        if (this.selectedText.trim().length > 0 && !this.isSavingEvidence) {
          this.cancelEvidenceDraft();
          return true;
        }
      }
      return false;
    }
    if (this.reviewSessionIds.length > 0) {
      if (this.reviewSessionSourceOpen &&
        this.mainView === 'READER' &&
        event.keyCode === KeyCode.KEYCODE_F) {
        focusControl.requestFocus('pdfSearch');
      }
      return true;
    }
    if (this.editorDraftAction !== 'NONE' ||
      this.evidenceDraftAction !== 'NONE' ||
      this.deleteTargetKind !== 'NONE') {
      return true;
    }
    if (this.handleEditingShortcut(event)) {
      return true;
    }
    if (this.showWebEditor ||
      this.showPdfEditor ||
      this.editingEvidenceId.length > 0) {
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_O) {
      this.importPdf();
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_S) {
      this.exportCurrentView();
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_F) {
      if (this.mainView === 'READER') {
        focusControl.requestFocus('pdfSearch');
      } else if (this.mainView === 'REVIEW') {
        focusControl.requestFocus('reviewSearch');
      } else {
        focusControl.requestFocus('librarySearch');
      }
      return true;
    }
    return false;
  }

  @Builder
  private ToolButton(label: () => string, action: () => void, enabled: () => boolean = (): boolean => true): void {
    Button(label())
      .height(34)
      .fontSize(13)
      .fontColor(enabled() ? this.primaryText() : this.mutedText())
      .backgroundColor(enabled() ? this.raisedBackground() : this.pageBackground())
      .border({ width: 1, color: this.dividerColor() })
      .borderRadius(6)
      .padding({ left: 11, right: 11 })
      .enabled(enabled())
      .bindTips(label(), { appearingTime: 500 })
      .onClick(action);
  }

  @Builder
  private IconToolButton(symbol: Resource, label: () => string, action: () => void,
    enabled: () => boolean = (): boolean => true): void {
    Button() {
      SymbolGlyph(symbol)
        .fontSize(18)
        .fontColor([enabled() ? this.primaryText() : this.mutedText()]);
    }
      .width(34)
      .height(34)
      .backgroundColor(enabled() ? this.raisedBackground() : this.pageBackground())
      .border({ width: 1, color: this.dividerColor() })
      .borderRadius(6)
      .enabled(enabled())
      .bindTips(label(), { appearingTime: 500 })
      .onClick(action);
  }

  @Builder
  private AccentButton(label: () => string, action: () => void,
    enabled: () => boolean = (): boolean => true): void {
    Button(label())
      .height(36)
      .fontSize(13)
      .fontColor('#FFFFFF')
      .backgroundColor(enabled() ? this.accentColor() : this.mutedText())
      .borderRadius(6)
      .padding({ left: 14, right: 14 })
      .enabled(enabled())
      .onClick(action);
  }

  @Builder
  private DangerButton(label: () => string, action: () => void): void {
    Button(label())
      .height(34)
      .fontSize(12)
      .fontColor(this.coralColor())
      .backgroundColor(Color.Transparent)
      .borderRadius(6)
      .padding({ left: 9, right: 9 })
      .onClick(action);
  }

  @Builder
  private DangerFilledButton(label: () => string, action: () => void,
    enabled: () => boolean = (): boolean => true): void {
    Button(label())
      .height(36)
      .fontSize(13)
      .fontColor('#FFFFFF')
      .backgroundColor(enabled() ? this.coralColor() : this.mutedText())
      .borderRadius(6)
      .padding({ left: 14, right: 14 })
      .enabled(enabled())
      .onClick(action);
  }

  @Builder
  private NavButton(label: string, selected: () => boolean, action: () => void,
    enabled: () => boolean = (): boolean => true): void {
    Button() {
      Text(label)
        .width('100%')
        .fontSize(14)
        .fontWeight(selected() ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(enabled() ? (selected() ? this.accentColor() : this.secondaryText()) : this.mutedText())
        .textAlign(TextAlign.Start);
    }
      .width('100%')
      .height(38)
      .backgroundColor(enabled() && selected() ? this.accentSoft() : Color.Transparent)
      .borderRadius(6)
      .padding({ left: 12 })
      .enabled(enabled())
      .onClick(action);
  }

  @Builder
  private TagButton(tag: string): void {
    Button(tag.length === 0 ? '全部标签' : `#${tag}`)
      .height(30)
      .fontSize(12)
      .fontColor(this.selectedTag === tag ? '#FFFFFF' : this.secondaryText())
      .backgroundColor(this.selectedTag === tag ? this.accentColor() : this.raisedBackground())
      .border({ width: 1, color: this.selectedTag === tag ? this.accentColor() : this.dividerColor() })
      .borderRadius(6)
      .padding({ left: 10, right: 10 })
      .onClick((): void => {
        this.selectedTag = tag;
      });
  }

  @Builder
  private ReviewTagButton(tag: string): void {
    Button(tag.length === 0 ? '全部标签' : `#${tag}`)
      .height(30)
      .fontSize(12)
      .fontColor(this.reviewSelectedTag === tag ? '#FFFFFF' : this.secondaryText())
      .backgroundColor(this.reviewSelectedTag === tag ? this.accentColor() : this.raisedBackground())
      .border({
        width: 1,
        color: this.reviewSelectedTag === tag ? this.accentColor() : this.dividerColor()
      })
      .borderRadius(6)
      .padding({ left: 10, right: 10 })
      .onClick((): void => {
        this.reviewSelectedTag = tag;
      });
  }

  @Builder
  private ReviewFilterButton(label: string, filter: ReviewFilter): void {
    Button(`${label} ${this.reviewCount(filter)}`)
      .height(32)
      .fontSize(12)
      .fontWeight(this.reviewFilter === filter ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.reviewFilter === filter ? '#FFFFFF' : this.secondaryText())
      .backgroundColor(this.reviewFilter === filter ? this.accentColor() : this.raisedBackground())
      .border({
        width: 1,
        color: this.reviewFilter === filter ? this.accentColor() : this.dividerColor()
      })
      .borderRadius(6)
      .padding({ left: 11, right: 11 })
      .onClick((): void => {
        this.reviewFilter = filter;
      });
  }

  @Builder
  private AppHeader(): void {
    Row({ space: 10 }) {
      this.ToolButton(
        (): string => this.windowWidth < 760 ?
          (this.leftSidebarOpen && !this.focusMode ? '收起' : '导航') :
          (this.leftSidebarOpen && !this.focusMode ? '收起导航' : '导航'),
        (): void => {
          const nextOpen = this.focusMode ? true : !this.leftSidebarOpen;
          this.leftSidebarOpen = nextOpen;
          if (this.windowWidth < 1100 && nextOpen) {
            this.rightSidebarOpen = false;
          }
          this.focusMode = false;
          this.saveSettings();
        },
        (): boolean => !this.reviewSessionSourceOpen
      );
      Text('阅迹')
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryText());
      if (this.windowWidth >= 760) {
        Text(this.mainView === 'READER' && this.activeDocument() !== undefined ?
          this.activeDocument()!.title :
          this.mainView === 'REVIEW' ? '复习中心' : '本地资料库')
          .fontSize(13)
          .fontColor(this.secondaryText())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
      } else {
        Blank();
      }
      this.ToolButton((): string => this.windowWidth < 1100 ?
        (this.darkMode ? '亮' : '暗') :
        (this.darkMode ? '亮色' : '暗色'), (): void => {
        this.toggleDarkMode();
      });
      if (this.mainView === 'READER') {
        if (this.windowWidth >= 1100) {
          this.ToolButton((): string => this.focusMode ? '退出专注' : '专注', (): void => {
            this.toggleFocusMode();
          }, (): boolean => this.documentPath.length > 0 && !this.reviewSessionSourceOpen);
        }
        this.ToolButton((): string => this.windowWidth < 760 ?
          (this.rightSidebarOpen && !this.focusMode ? '收起' : '证据') :
          (this.rightSidebarOpen && !this.focusMode ? '收起证据' : '证据'), (): void => {
          const nextOpen = !this.rightSidebarOpen;
          this.rightSidebarOpen = nextOpen;
          if (this.windowWidth < 1100 && nextOpen) {
            this.leftSidebarOpen = false;
          }
          this.focusMode = false;
          this.saveSettings();
        }, (): boolean => this.documentPath.length > 0 && !this.reviewSessionSourceOpen);
      }
      if (this.windowWidth >= 900) {
        this.ToolButton((): string => '导出', (): void => {
          this.exportCurrentView();
        }, (): boolean => this.documents.length > 0 && !this.reviewSessionSourceOpen);
      }
      if (this.windowWidth >= 760) {
        this.ToolButton((): string => this.windowWidth < 1100 ? '网页' : '网页资料', (): void => {
          this.startAddWeb();
        }, (): boolean => this.isReady && !this.reviewSessionSourceOpen);
      }
      this.AccentButton(
        (): string => this.isLoading ? '处理中…' : (this.windowWidth < 1100 ? '导入' : '导入 PDF'),
        (): void => {
        this.importPdf();
        },
        (): boolean => this.isReady && !this.isLoading && !this.reviewSessionSourceOpen
      );
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.panelBackground())
    .border({ width: { bottom: 1 }, color: this.dividerColor() });
  }

  @Builder
  private ReviewSourceBar(card: EvidenceCard): void {
    if (this.windowWidth < 760) {
      Column({ space: 7 }) {
        Row({ space: 8 }) {
          Text('正在核对来源')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentColor());
          Text(`第 ${this.reviewSessionIndex + 1}/${this.reviewSessionIds.length} 张 · ${
            this.evidenceSourceLabel(card)
          }`)
            .fontSize(11)
            .fontColor(this.secondaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
        }
        .width('100%');
        Row({ space: 8 }) {
          this.ToolButton((): string => '结束本轮', (): void => {
            this.closeReviewSession();
          });
          Blank();
          this.AccentButton((): string => '返回复习', (): void => {
            this.resumeReviewSession();
          });
        }
        .width('100%');
      }
      .width('100%')
      .height(88)
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.accentSoft())
      .border({ width: { bottom: 1 }, color: this.accentColor() });
    } else {
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text('正在核对来源')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentColor())
            .width('100%');
          Text(`第 ${this.reviewSessionIndex + 1}/${this.reviewSessionIds.length} 张 · ${
            this.evidenceSourceLabel(card)
          }`)
            .fontSize(11)
            .fontColor(this.secondaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }
        .layoutWeight(1);
        this.ToolButton((): string => '结束本轮', (): void => {
          this.closeReviewSession();
        });
        this.AccentButton((): string => '返回复习', (): void => {
          this.resumeReviewSession();
        });
      }
      .width('100%')
      .height(54)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.accentSoft())
      .border({ width: { bottom: 1 }, color: this.accentColor() });
    }
  }

  @Builder
  private StatusBar(): void {
    Row({ space: 12 }) {
      Text(this.statusMessage)
        .fontSize(11)
        .fontColor(this.secondaryText())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1);
      if (this.windowWidth >= 760 && this.mainView === 'READER' && this.documentPath.length > 0) {
        Text(`第 ${this.currentPage}/${this.pageCount} 页 · ${this.zoomPercent}%`)
          .fontSize(11)
          .fontColor(this.mutedText());
      }
      if (this.windowWidth >= 1100) {
        Text('本地模式')
          .fontSize(11)
          .fontColor(this.accentColor());
      }
    }
    .width('100%')
    .height(28)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.panelBackground())
    .border({ width: { top: 1 }, color: this.dividerColor() });
  }

  @Builder
  private ThumbnailItem(thumbnail: ThumbnailRecord): void {
    Column({ space: 5 }) {
      if (thumbnail.pixelMap !== undefined) {
        Image(thumbnail.pixelMap)
          .width(118)
          .height(150)
          .objectFit(ImageFit.Contain)
          .backgroundColor('#FFFFFF');
      } else {
        Column() {
          Text(`${thumbnail.pageIndex + 1}`)
            .fontSize(18)
            .fontColor(this.mutedText());
        }
        .width(118)
        .height(150)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.raisedBackground());
      }
      Text(`第 ${thumbnail.pageIndex + 1} 页`)
        .fontSize(11)
        .fontColor(thumbnail.pageIndex + 1 === this.currentPage ? this.accentColor() : this.mutedText());
    }
    .width('100%')
    .padding({ top: 6, bottom: 8 })
    .borderRadius(6)
    .backgroundColor(thumbnail.pageIndex + 1 === this.currentPage ? this.accentSoft() : Color.Transparent)
    .onClick((): void => {
      this.pdfController.goToPage(thumbnail.pageIndex);
    });
  }

  @Builder
  private LeftSidebar(): void {
    Column({ space: 8 }) {
      Text('工作区')
        .fontSize(11)
        .fontColor(this.mutedText())
        .width('100%');
      this.NavButton('资料库', (): boolean =>
        this.mainView === 'LIBRARY' && this.libraryScope === 'ALL', (): void => {
        this.showLibrary('ALL');
      }, (): boolean => !this.reviewSessionSourceOpen);
      this.NavButton('最近阅读', (): boolean =>
        this.mainView === 'LIBRARY' && this.libraryScope === 'RECENT', (): void => {
        this.showLibrary('RECENT');
      }, (): boolean => !this.reviewSessionSourceOpen);
      this.NavButton('收藏', (): boolean =>
        this.mainView === 'LIBRARY' && this.libraryScope === 'FAVORITE', (): void => {
        this.showLibrary('FAVORITE');
      }, (): boolean => !this.reviewSessionSourceOpen);
      this.NavButton('复习中心', (): boolean => this.mainView === 'REVIEW', (): void => {
        this.showReview();
      }, (): boolean => !this.reviewSessionSourceOpen);
      if (this.windowWidth < 900) {
        Divider().color(this.dividerColor()).margin({ top: 5, bottom: 5 });
        Text('快捷操作')
          .fontSize(11)
          .fontColor(this.mutedText())
          .width('100%');
        if (this.windowWidth < 760) {
          this.NavButton('添加网页资料', (): boolean => false, (): void => {
            this.closeCompactNavigation();
            this.startAddWeb();
          }, (): boolean => this.isReady && !this.reviewSessionSourceOpen);
        }
        this.NavButton('导出学习笔记', (): boolean => false, (): void => {
          this.closeCompactNavigation();
          this.exportCurrentView();
        }, (): boolean => this.documents.length > 0 && !this.reviewSessionSourceOpen);
      }
      Divider().color(this.dividerColor()).margin({ top: 5, bottom: 5 });
      if (this.mainView === 'READER' && this.documentPath.length > 0) {
        Row() {
          Text('页面')
            .fontSize(11)
            .fontColor(this.mutedText());
          Blank();
          Text(`${this.thumbnailLoadCount}/${Math.min(this.pageCount, 18)} 预览`)
            .fontSize(10)
            .fontColor(this.mutedText());
        }
        .width('100%');
        List({ space: 4 }) {
          ForEach(this.thumbnails, (thumbnail: ThumbnailRecord): void => {
            ListItem() {
              this.ThumbnailItem(thumbnail);
            }
          }, (thumbnail: ThumbnailRecord): string => `${thumbnail.pageIndex}`);
        }
        .width('100%')
        .layoutWeight(1);
      } else {
        Text('最近资料')
          .fontSize(11)
          .fontColor(this.mutedText())
          .width('100%');
        List({ space: 4 }) {
          ForEach(this.documents.slice(0, 8), (document: DocumentRecord): void => {
            ListItem() {
              Button() {
                Text(document.title)
                  .width('100%')
                  .fontSize(12)
                  .fontColor(this.secondaryText())
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Start);
              }
                .width('100%')
                .height(38)
                .backgroundColor(Color.Transparent)
                .borderRadius(6)
                .padding({ left: 8, right: 8 })
                .onClick((): void => {
                  this.closeCompactNavigation();
                  this.openDocument(document);
                });
            }
          }, (document: DocumentRecord): string => this.documentRenderKey(document));
        }
        .width('100%')
        .layoutWeight(1);
      }
    }
    .width(220)
    .height('100%')
    .padding(14)
    .backgroundColor(this.panelBackground())
    .border({ width: { right: 1 }, color: this.dividerColor() });
  }

  @Builder
  private EmptyLibrary(): void {
    Column({ space: 14 }) {
      Text(this.hasLibraryFilters() ? '筛选' :
        this.libraryScope === 'FAVORITE' ? '收藏' :
        this.libraryScope === 'RECENT' ? '最近' : 'PDF')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accentColor())
        .width(68)
        .height(68)
        .textAlign(TextAlign.Center)
        .padding({ top: 21 })
        .borderRadius(8)
        .backgroundColor(this.accentSoft());
      Text(this.hasLibraryFilters() ? '没有匹配的资料' :
        this.libraryScope === 'FAVORITE' ? '还没有收藏资料' :
        this.libraryScope === 'RECENT' ? '最近 30 天没有阅读记录' : '建立第一条可追溯阅读证据')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryText());
      Text(this.hasLibraryFilters() ? '试试清除搜索词和标签筛选。' :
        this.libraryScope === 'FAVORITE' ? '收藏常用资料后，可以从这里快速返回。' :
        this.libraryScope === 'RECENT' ? '打开一份资料后，阅读记录会出现在这里。' :
        'PDF 保存在应用本地；网页资料只保存链接、摘录和你的笔记。')
        .fontSize(13)
        .fontColor(this.secondaryText());
      if (this.hasLibraryFilters()) {
        this.AccentButton((): string => '清除筛选', (): void => {
          this.clearLibraryFilters();
        });
      } else if (this.libraryScope === 'FAVORITE' || this.libraryScope === 'RECENT') {
        this.AccentButton((): string => '查看全部资料', (): void => {
          this.libraryScope = 'ALL';
        });
      } else {
        Row({ space: 10 }) {
          this.AccentButton((): string => '导入 PDF', (): void => {
            this.importPdf();
          }, (): boolean => this.isReady && !this.isLoading);
          this.ToolButton((): string => '添加网页资料', (): void => {
            this.startAddWeb();
          }, (): boolean => this.isReady);
        }
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private DocumentItem(document: DocumentRecord): void {
    Column({ space: 12 }) {
      Row({ space: 14 }) {
        Column() {
          Text(document.kind === 'PDF' ? 'PDF' : 'WEB')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(document.kind === 'PDF' ? this.accentColor() : this.coralColor());
        }
        .width(48)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .borderRadius(6)
        .backgroundColor(document.kind === 'PDF' ? this.accentSoft() : this.coralSoft());
        Column({ space: 5 }) {
          Text(document.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
          Text(document.kind === 'PDF' ?
            `${document.pageCount} 页 · 上次读到第 ${document.currentPage + 1} 页 · ${this.formatDate(document.lastReadAt)}` :
            `${document.source} · ${this.formatDate(document.lastReadAt)}`)
            .fontSize(11)
            .fontColor(this.secondaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
          if (document.tags.length > 0) {
            Text(tagList(document.tags).map((tag: string): string => `#${tag}`).join('  '))
              .fontSize(11)
              .fontColor(this.accentColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%');
          }
        }
        .layoutWeight(1);
        Column({ space: 4 }) {
          Text(`${this.evidenceCountForDocument(document.id)} 张证据`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText());
          Text(`${this.pendingCountForDocument(document.id)} 张待复习`)
            .fontSize(11)
            .fontColor(this.pendingCountForDocument(document.id) > 0 ? this.coralColor() : this.secondaryText());
        }
        .alignItems(HorizontalAlign.End);
      }
      .width('100%');
      if (document.kind === 'PDF') {
        Row({ space: 10 }) {
          Progress({ value: this.documentProgress(document), total: 100, type: ProgressType.Linear })
            .height(4)
            .color(this.accentColor())
            .backgroundColor(this.dividerColor())
            .borderRadius(2)
            .layoutWeight(1);
          Text(`已读 ${this.documentProgress(document)}%`)
            .fontSize(10)
            .fontColor(this.secondaryText());
        }
        .width('100%');
      }
      Row({ space: 7 }) {
        this.ToolButton((): string => document.favorite ? '已收藏' : '收藏', (): void => {
          this.toggleFavorite(document);
        });
        this.ToolButton((): string => '编辑', (): void => {
          if (document.kind === 'WEB') {
            this.startEditWeb(document);
          } else {
            this.startEditPdf(document);
          }
        });
        this.DangerButton((): string => '删除', (): void => {
          this.requestDeleteDocument(document);
        });
        Blank();
        this.AccentButton(
          (): string => document.kind === 'PDF' ?
            (document.currentPage > 0 ? '继续阅读' : '开始阅读') : '打开来源',
          (): void => {
            this.openDocument(document);
          }
        );
      }
      .width('100%');
    }
    .width('100%')
    .constraintSize({ minHeight: 118 })
    .padding(14)
    .borderRadius(8)
    .backgroundColor(this.raisedBackground())
    .border({ width: 1, color: this.dividerColor() });
  }

  @Builder
  private ContinueReadingBar(document: DocumentRecord): void {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text('继续上次阅读')
          .fontSize(11)
          .fontColor(this.accentColor());
        Text(document.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text(`第 ${document.currentPage + 1}/${document.pageCount} 页 · ${this.documentProgress(document)}%`)
        .fontSize(11)
        .fontColor(this.secondaryText());
      this.AccentButton((): string => '继续阅读', (): void => {
        this.openDocument(document);
      });
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 10, bottom: 10 })
    .backgroundColor(this.accentSoft())
    .border({ width: { bottom: 1 }, color: this.dividerColor() });
  }

  @Builder
  private LibraryView(): void {
    Column() {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Text(this.libraryScope === 'FAVORITE' ? '收藏资料' :
              this.libraryScope === 'RECENT' ? '最近阅读' : '资料库')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryText())
              .width('100%');
            Text(`${this.filteredDocuments().length} 份资料 · ${this.evidenceCards.length} 张证据卡`)
              .fontSize(12)
              .fontColor(this.secondaryText())
              .width('100%');
          }
          .layoutWeight(1);
          TextInput({ placeholder: '搜索标题、网址或标签', text: this.librarySearch })
            .id('librarySearch')
            .width(this.windowWidth < 900 ? 210 : 280)
            .height(36)
            .fontSize(13)
            .fontColor(this.primaryText())
            .placeholderColor(this.mutedText())
            .backgroundColor(this.raisedBackground())
            .border({ width: 1, color: this.dividerColor() })
            .borderRadius(6)
            .onChange((value: string): void => {
              this.librarySearch = value;
            });
        }
        .width('100%');
        Scroll() {
          Row({ space: 8 }) {
            this.TagButton('');
            ForEach(this.allTags(), (tag: string): void => {
              this.TagButton(tag);
            }, (tag: string): string => tag);
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off);
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 18, bottom: 14 })
      .backgroundColor(this.panelBackground())
      .border({ width: { bottom: 1 }, color: this.dividerColor() });

      if (this.libraryScope === 'ALL' &&
        this.librarySearch.trim().length === 0 &&
        this.selectedTag.length === 0 &&
        this.recentPdfDocument() !== undefined) {
        this.ContinueReadingBar(this.recentPdfDocument()!);
      }

      if (this.filteredDocuments().length === 0) {
        this.EmptyLibrary();
      } else {
        List({ space: 10 }) {
          ForEach(this.filteredDocuments(), (document: DocumentRecord): void => {
            ListItem() {
              this.DocumentItem(document);
            }
          }, (document: DocumentRecord): string => this.documentRenderKey(document));
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 22, right: 22, top: 16, bottom: 22 });
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(this.pageBackground());
  }

  @Builder
  private ReaderToolbar(): void {
    Row({ space: 7 }) {
      this.IconToolButton($r('sys.symbol.minus'), (): string => '缩小', (): void => {
        this.changeZoom(-10);
      }, (): boolean => this.documentPath.length > 0);
      Text(`${this.zoomPercent}%`)
        .fontSize(12)
        .fontColor(this.secondaryText())
        .width(48)
        .textAlign(TextAlign.Center);
      this.IconToolButton($r('sys.symbol.plus'), (): string => '放大', (): void => {
        this.changeZoom(10);
      }, (): boolean => this.documentPath.length > 0);
      this.IconToolButton($r('sys.symbol.adapt_window_width'), (): string => '适应宽度', (): void => {
        this.pdfController.setPageFit(pdfService.PageFit.FIT_WIDTH);
      }, (): boolean => this.documentPath.length > 0);
      Divider().vertical(true).height(22).color(this.dividerColor());
      if (this.compactReaderToolbar()) {
        Text(`第 ${this.currentPage}/${this.pageCount} 页`)
          .fontSize(12)
          .fontColor(this.secondaryText())
          .maxLines(1);
      } else {
        TextInput({ placeholder: '页码', text: this.pageInput })
          .width(56)
          .height(34)
          .fontSize(12)
          .fontColor(this.primaryText())
          .textAlign(TextAlign.Center)
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() })
          .borderRadius(6)
          .onChange((value: string): void => {
            this.pageInput = value;
          })
          .onSubmit((): void => {
            this.goToPage(this.pageInput);
          });
        Text(`/ ${this.pageCount}`)
          .fontSize(12)
          .fontColor(this.secondaryText());
        this.IconToolButton($r('sys.symbol.arrow_right_circle'), (): string => '跳转页码', (): void => {
          this.goToPage(this.pageInput);
        });
        TextInput({ placeholder: '全文搜索', text: this.searchText })
          .id('pdfSearch')
          .width(this.windowWidth < 1200 ? 150 : 210)
          .height(34)
          .fontSize(12)
          .fontColor(this.primaryText())
          .placeholderColor(this.mutedText())
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() })
          .borderRadius(6)
          .onChange((value: string): void => {
            this.searchText = value;
            if (this.searchedText.length > 0 && value.trim() !== this.searchedText) {
              this.clearPdfSearch('全文搜索已清除');
            }
          })
          .onSubmit((): void => {
            this.runSearch();
          });
        this.IconToolButton($r('sys.symbol.search_things'), (): string => '查找', (): void => {
          this.runSearch();
        }, (): boolean => this.documentPath.length > 0);
        if (this.searchCount > 0) {
          Text(`${this.searchIndex}/${this.searchCount}`)
            .fontSize(11)
            .fontColor(this.secondaryText());
          this.IconToolButton($r('sys.symbol.chevron_left'), (): string => '上一个结果', (): void => {
            this.moveSearch(-1);
          });
          this.IconToolButton($r('sys.symbol.chevron_right'), (): string => '下一个结果', (): void => {
            this.moveSearch(1);
          });
        }
      }
    }
    .width('100%')
    .height(50)
    .padding({ left: 10, right: 10 })
    .backgroundColor(this.panelBackground())
    .border({ width: { bottom: 1 }, color: this.dividerColor() });
  }

  @Builder
  private EmptyReader(): void {
    Column({ space: 14 }) {
      Text('没有打开的 PDF')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryText());
      Text('从资料库选择 PDF，或使用 Ctrl/Cmd+O 导入。')
        .fontSize(13)
        .fontColor(this.secondaryText());
      this.AccentButton((): string => '返回资料库', (): void => {
        this.showLibrary('ALL');
      });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.readerBackground());
  }

  @Builder
  private ReaderView(): void {
    Column() {
      this.ReaderToolbar();
      Stack() {
        PdfView({
          controller: this.pdfController,
          pageLayout: pdfService.PageLayout.LAYOUT_SINGLE,
          isContinuous: true,
          showScroll: true,
          pageFit: pdfService.PageFit.FIT_WIDTH
        })
          .width('100%')
          .height('100%')
          .backgroundColor(this.readerBackground())
          .visibility(this.documentPath.length > 0 ? Visibility.Visible : Visibility.Hidden);
        if (this.documentPath.length === 0) {
          this.EmptyReader();
        }
      }
      .width('100%')
      .layoutWeight(1);
    }
    .layoutWeight(1)
    .height('100%');
  }

  @Builder
  private EvidenceComposer(): void {
    if (this.selectedText.trim().length > 0) {
      Column({ space: 9 }) {
        Row({ space: 8 }) {
          Text('新证据')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText());
          Blank();
          Text(this.selectedSourceLabel())
            .fontSize(10)
            .fontColor(this.mutedText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%');
        Text(this.selectedText)
          .fontSize(13)
          .fontColor(this.highlightPreviewText())
          .lineHeight(20)
          .maxLines(6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding(10)
          .borderRadius(6)
          .backgroundColor(this.highlightPreviewBackground());
        Row({ space: 7 }) {
          Button('高亮')
            .height(32)
            .fontSize(12)
            .fontColor(this.evidenceKind === 'HIGHLIGHT' ? this.highlightPreviewText() : this.secondaryText())
            .backgroundColor(this.evidenceKind === 'HIGHLIGHT' ?
              this.highlightActiveBackground() : this.raisedBackground())
            .border({
              width: 1,
              color: this.evidenceKind === 'HIGHLIGHT' ? this.highlightActiveBorder() : this.dividerColor()
            })
            .borderRadius(6)
            .layoutWeight(1)
            .onClick((): void => {
              this.evidenceKind = 'HIGHLIGHT';
            });
          Button('下划线')
            .height(32)
            .fontSize(12)
            .fontColor(this.evidenceKind === 'UNDERLINE' ? this.accentColor() : this.secondaryText())
            .backgroundColor(this.evidenceKind === 'UNDERLINE' ? this.accentSoft() : this.raisedBackground())
            .border({ width: 1, color: this.evidenceKind === 'UNDERLINE' ? this.accentColor() : this.dividerColor() })
            .borderRadius(6)
            .layoutWeight(1)
            .onClick((): void => {
              this.evidenceKind = 'UNDERLINE';
            });
        }
        Row({ space: 8 }) {
          ForEach([0xFFFFD95A, 0xFFA8E6CF, 0xFFFFB3A7, 0xFFBFD7FF], (color: number): void => {
            Button()
              .width(26)
              .height(26)
              .backgroundColor(color)
              .border({
                width: this.evidenceColor === color ? 2 : 1,
                color: this.evidenceColor === color ? this.primaryText() : this.dividerColor()
              })
              .borderRadius(6)
              .onClick((): void => {
                this.evidenceColor = color;
                this.saveSettings();
              });
          }, (color: number): string => `${color}`);
        }
        .width('100%');
        TextArea({ placeholder: '写下这段原文为什么重要…', text: this.evidenceNote })
          .width('100%')
          .height(78)
          .fontSize(12)
          .fontColor(this.primaryText())
          .placeholderColor(this.mutedText())
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() })
          .borderRadius(6)
          .onChange((value: string): void => {
            this.evidenceNote = value;
          })
          .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
        TextInput({ placeholder: '标签，使用逗号分隔', text: this.evidenceTags })
          .width('100%')
          .height(34)
          .fontSize(12)
          .fontColor(this.primaryText())
          .placeholderColor(this.mutedText())
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() })
          .borderRadius(6)
          .onChange((value: string): void => {
            this.evidenceTags = value;
          })
          .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
        Row({ space: 8 }) {
          this.ToolButton((): string => '取消选区', (): void => {
            this.cancelEvidenceDraft();
          }, (): boolean => !this.isSavingEvidence);
          Blank();
          this.AccentButton((): string => this.isSavingEvidence ? '正在保存…' : '创建证据卡', (): void => {
            this.createEvidenceCard();
          }, (): boolean => !this.isSavingEvidence);
        }
        .width('100%');
      }
      .width('100%')
      .padding({ bottom: 12 })
      .border({ width: { bottom: 1 }, color: this.dividerColor() });
    } else {
      Column({ space: 6 }) {
        Text('选择 PDF 原文')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText());
        Text('选区会保存页码和坐标，之后可准确返回来源。')
          .fontSize(11)
          .fontColor(this.secondaryText())
          .lineHeight(17)
          .textAlign(TextAlign.Center);
      }
      .width('100%')
      .padding({ top: 18, bottom: 18 })
      .border({ width: { bottom: 1 }, color: this.dividerColor() });
    }
  }

  @Builder
  private EvidenceItem(card: EvidenceCard, compact: boolean = false): void {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(this.evidenceKindLabel(card.kind))
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor())
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .backgroundColor(this.accentSoft());
        Text(this.evidenceSourceLabel(card))
          .fontSize(10)
          .fontColor(this.mutedText())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
        Text(card.reviewStatus === 'MASTERED' ? '已掌握' : '待复习')
          .fontSize(10)
          .fontColor(card.reviewStatus === 'MASTERED' ? this.accentColor() : this.coralColor())
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .backgroundColor(card.reviewStatus === 'MASTERED' ? this.accentSoft() : this.coralSoft());
      }
      .width('100%');
      Text(card.quote)
        .fontSize(compact ? 12 : 13)
        .fontColor(this.primaryText())
        .lineHeight(compact ? 18 : 20)
        .maxLines(compact ? 4 : 7)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 9 })
        .border({ width: { left: 3 }, color: card.color });
      if (this.editingEvidenceId === card.id) {
        TextArea({ placeholder: '个人笔记', text: this.editingEvidenceNote })
          .width('100%')
          .height(72)
          .fontSize(12)
          .fontColor(this.primaryText())
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() })
          .borderRadius(6)
          .enabled(!this.isSavingEditor)
          .onChange((value: string): void => {
            this.editingEvidenceNote = value;
          })
          .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
        TextInput({ placeholder: '标签，使用逗号分隔', text: this.editingEvidenceTags })
          .width('100%')
          .height(32)
          .fontSize(12)
          .fontColor(this.primaryText())
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() })
          .borderRadius(6)
          .enabled(!this.isSavingEditor)
          .onChange((value: string): void => {
            this.editingEvidenceTags = value;
          })
          .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
        Row({ space: 7 }) {
          this.AccentButton(
            (): string => this.isSavingEditor ? '正在保存…' : '保存',
            (): void => {
              this.saveEvidenceEdit(card);
            },
            (): boolean => !this.isSavingEditor
          );
          this.ToolButton((): string => '取消', (): void => {
            this.requestCloseEditor('EVIDENCE');
          }, (): boolean => !this.isSavingEditor);
        }
      } else {
        if (card.note.length > 0) {
          Text(card.note)
            .fontSize(11)
            .fontColor(this.secondaryText())
            .lineHeight(17)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }
        if (card.tags.length > 0) {
          Text(tagList(card.tags).map((tag: string): string => `#${tag}`).join('  '))
            .fontSize(10)
            .fontColor(this.accentColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }
        if (compact) {
          Column({ space: 6 }) {
            Row({ space: 6 }) {
              this.AccentButton((): string => '回到原文', (): void => {
                this.returnToEvidence(card);
              });
              this.ToolButton(
                (): string => card.reviewStatus === 'MASTERED' ? '改为待复习' : '标记掌握',
                (): void => {
                  this.toggleEvidenceStatus(card);
                }
              );
            }
            .width('100%');
            Row({ space: 4 }) {
              Blank();
              this.ToolButton((): string => '编辑', (): void => {
                this.startEditEvidence(card);
              });
              this.DangerButton((): string => '删除', (): void => {
                this.requestDeleteEvidence(card);
              });
            }
            .width('100%');
          }
          .width('100%');
        } else {
          Row({ space: 6 }) {
            this.AccentButton((): string => '回到原文', (): void => {
              this.returnToEvidence(card);
            });
            this.ToolButton(
              (): string => card.reviewStatus === 'MASTERED' ? '改为待复习' : '标记掌握',
              (): void => {
                this.toggleEvidenceStatus(card);
              }
            );
            Blank();
            this.ToolButton((): string => '编辑', (): void => {
              this.startEditEvidence(card);
            });
            this.DangerButton((): string => '删除', (): void => {
              this.requestDeleteEvidence(card);
            });
          }
          .width('100%');
        }
      }
    }
    .width('100%')
    .padding(11)
    .borderRadius(8)
    .backgroundColor(this.raisedBackground())
    .border({ width: 1, color: this.dividerColor() });
  }

  @Builder
  private EvidenceSidebar(): void {
    Column({ space: 10 }) {
      Row() {
        Text('证据卡')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText());
        Blank();
        Text(`${this.activeEvidenceCards().length} 张 · ${
          this.activeEvidenceCards().filter((card: EvidenceCard): boolean =>
            card.reviewStatus === 'TO_REVIEW').length
        } 待复习`)
          .fontSize(11)
          .fontColor(this.accentColor())
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(8)
          .backgroundColor(this.accentSoft());
      }
      .width('100%');
      this.EvidenceComposer();
      List({ space: 8 }) {
        ForEach(this.activeEvidenceCards(), (card: EvidenceCard): void => {
          ListItem() {
            this.EvidenceItem(card, true);
          }
        }, (card: EvidenceCard): string => this.evidenceRenderKey(card));
      }
      .width('100%')
      .layoutWeight(1);
    }
    .width(340)
    .height('100%')
    .padding(14)
    .backgroundColor(this.panelBackground())
    .border({ width: { left: 1 }, color: this.dividerColor() });
  }

  @Builder
  private ReviewView(): void {
    Column() {
      Column({ space: 12 }) {
        Row({ space: 9 }) {
          Column({ space: 3 }) {
            Text('复习中心')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryText())
              .width('100%');
            Text(`${this.filteredReviewCards().length} 张证据卡`)
              .fontSize(12)
              .fontColor(this.secondaryText())
              .width('100%');
          }
          .layoutWeight(1);
          TextInput({ placeholder: '搜索原文、笔记或来源', text: this.reviewSearch })
            .id('reviewSearch')
            .width(this.windowWidth < 1000 ? 210 : 260)
            .height(36)
            .fontSize(13)
            .fontColor(this.primaryText())
            .placeholderColor(this.mutedText())
            .backgroundColor(this.raisedBackground())
            .border({ width: 1, color: this.dividerColor() })
            .borderRadius(6)
            .onChange((value: string): void => {
              this.reviewSearch = value;
            });
        }
        .width('100%');
        Row({ space: 7 }) {
          this.ReviewFilterButton('全部', 'ALL');
          this.ReviewFilterButton('待复习', 'TO_REVIEW');
          this.ReviewFilterButton('已掌握', 'MASTERED');
          Blank();
          this.AccentButton(
            (): string => this.windowWidth < 900 ?
              `复习 ${this.reviewQueueCards().length}` :
              `开始复习 ${this.reviewQueueCards().length} 张`,
            (): void => {
              this.requestStartReviewSession();
            },
            (): boolean => this.reviewQueueCards().length > 0
          );
        }
        .width('100%');
        Scroll() {
          Row({ space: 8 }) {
            this.ReviewTagButton('');
            ForEach(this.allTags(), (tag: string): void => {
              this.ReviewTagButton(tag);
            }, (tag: string): string => tag);
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off);
      }
      .padding({ left: 22, right: 22, top: 18, bottom: 14 })
      .backgroundColor(this.panelBackground())
      .border({ width: { bottom: 1 }, color: this.dividerColor() });
      if (this.filteredReviewCards().length === 0) {
        Column({ space: 10 }) {
          Text(this.hasReviewFilters() ? '没有匹配的证据卡' : '当前没有证据卡')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText());
          Text(this.hasReviewFilters() ?
            '试试清除搜索、标签和复习状态筛选。' :
            '阅读 PDF 并选择原文后，可创建待复习证据。')
            .fontSize(13)
            .fontColor(this.secondaryText());
          if (this.hasReviewFilters()) {
            this.AccentButton((): string => '清除筛选', (): void => {
              this.clearReviewFilters();
            });
          } else {
            this.AccentButton((): string => '返回资料库', (): void => {
              this.showLibrary('ALL');
            });
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center);
      } else {
        List({ space: 10 }) {
          ForEach(this.filteredReviewCards(), (card: EvidenceCard): void => {
            ListItem() {
              this.EvidenceItem(card);
            }
          }, (card: EvidenceCard): string => this.evidenceRenderKey(card));
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 22, right: 22, top: 16, bottom: 22 });
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(this.pageBackground());
  }

  @Builder
  private ReviewSessionCard(card: EvidenceCard): void {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('专注复习')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
            .width('100%');
          Text(`第 ${this.reviewSessionIndex + 1}/${this.reviewSessionIds.length} 张 · ${
            this.reviewSessionReviewedCount
          } 张已处理`)
            .fontSize(11)
            .fontColor(this.secondaryText())
            .width('100%');
        }
        .layoutWeight(1);
        this.ToolButton((): string => '结束复习', (): void => {
          this.closeReviewSession();
        }, (): boolean => !this.isReviewSessionUpdating);
      }
      .width('100%');
      Progress({
        value: this.reviewSessionIndex + 1,
        total: this.reviewSessionIds.length,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(5)
        .color(this.accentColor())
        .backgroundColor(this.dividerColor())
        .borderRadius(3);
      Row({ space: 7 }) {
        Text(this.evidenceKindLabel(card.kind))
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor())
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .borderRadius(4)
          .backgroundColor(this.accentSoft());
        Text(this.evidenceSourceLabel(card))
          .fontSize(11)
          .fontColor(this.mutedText())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
      }
      .width('100%');
      Scroll() {
        Column({ space: 14 }) {
          Text(card.quote)
            .fontSize(18)
            .fontColor(this.primaryText())
            .lineHeight(29)
            .width('100%')
            .padding({ left: 14 })
            .border({ width: { left: 4 }, color: card.color });
          Column({ space: 6 }) {
            Text('我的笔记')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.mutedText())
              .width('100%');
            Text(card.note.length > 0 ? card.note : '这张证据还没有补充个人笔记。')
              .fontSize(13)
              .fontColor(card.note.length > 0 ? this.secondaryText() : this.mutedText())
              .lineHeight(21)
              .width('100%');
          }
          .width('100%')
          .padding(12)
          .borderRadius(6)
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() });
          if (card.tags.length > 0) {
            Text(tagList(card.tags).map((tag: string): string => `#${tag}`).join('  '))
              .fontSize(11)
              .fontColor(this.accentColor())
              .width('100%');
          }
        }
        .width('100%');
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto);
      Row({ space: 8 }) {
        this.ToolButton((): string => '回到原文', (): void => {
          this.returnToReviewSessionSource();
        }, (): boolean => !this.isReviewSessionUpdating &&
          this.documentById(card.documentId) !== undefined);
        this.ToolButton((): string => '跳过', (): void => {
          this.skipReviewSessionCard();
        }, (): boolean => !this.isReviewSessionUpdating);
        Blank();
        this.ToolButton(
          (): string => this.isReviewSessionUpdating ? '正在保存…' : '仍需复习',
          (): void => {
            this.setReviewSessionStatus('TO_REVIEW');
          },
          (): boolean => !this.isReviewSessionUpdating
        );
        this.AccentButton(
          (): string => this.isReviewSessionUpdating ? '正在保存…' : '已掌握',
          (): void => {
            this.setReviewSessionStatus('MASTERED');
          },
          (): boolean => !this.isReviewSessionUpdating
        );
      }
      .width('100%');
    }
    .width(this.compactEditorWidth(720))
    .height(this.compactEditorHeight(620))
    .padding(22)
    .borderRadius(8)
    .backgroundColor(this.panelBackground())
    .border({ width: 1, color: this.dividerColor() });
  }

  @Builder
  private ReviewSessionOverlay(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.scrimColor());
      if (this.reviewSessionCard() !== undefined) {
        this.ReviewSessionCard(this.reviewSessionCard()!);
      }
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private WebEditorOverlay(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.scrimColor())
        .onClick((): void => {
          this.requestCloseEditor('WEB');
        });
      Column({ space: 12 }) {
        Row() {
          Text(this.editingWebId.length === 0 ? '添加网页资料' : '编辑网页资料')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText());
          Blank();
          this.ToolButton((): string => '关闭', (): void => {
            this.requestCloseEditor('WEB');
          }, (): boolean => !this.isSavingEditor);
        }
        .width('100%');
        Scroll() {
          Column({ space: 12 }) {
            TextInput({ placeholder: '标题（可选）', text: this.webTitle })
              .width('100%')
              .height(38)
              .fontColor(this.primaryText())
              .placeholderColor(this.mutedText())
              .backgroundColor(this.raisedBackground())
              .border({ width: 1, color: this.dividerColor() })
              .borderRadius(6)
              .enabled(!this.isSavingEditor)
              .onChange((value: string): void => {
                this.webTitle = value;
              })
              .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
            TextInput({ placeholder: 'https://example.com/article', text: this.webUrl })
              .width('100%')
              .height(38)
              .fontColor(this.primaryText())
              .placeholderColor(this.mutedText())
              .backgroundColor(this.raisedBackground())
              .border({ width: 1, color: this.dividerColor() })
              .borderRadius(6)
              .enabled(!this.isSavingEditor)
              .onChange((value: string): void => {
                this.webUrl = value;
              })
              .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
            TextArea({ placeholder: '粘贴需要保留的原文摘录', text: this.webExcerpt })
              .width('100%')
              .height(120)
              .fontColor(this.primaryText())
              .placeholderColor(this.mutedText())
              .backgroundColor(this.raisedBackground())
              .border({ width: 1, color: this.dividerColor() })
              .borderRadius(6)
              .enabled(!this.isSavingEditor)
              .onChange((value: string): void => {
                this.webExcerpt = value;
              })
              .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
            TextArea({ placeholder: '个人笔记', text: this.webNote })
              .width('100%')
              .height(90)
              .fontColor(this.primaryText())
              .placeholderColor(this.mutedText())
              .backgroundColor(this.raisedBackground())
              .border({ width: 1, color: this.dividerColor() })
              .borderRadius(6)
              .enabled(!this.isSavingEditor)
              .onChange((value: string): void => {
                this.webNote = value;
              })
              .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
            TextInput({ placeholder: '标签，使用逗号分隔', text: this.webTags })
              .width('100%')
              .height(38)
              .fontColor(this.primaryText())
              .placeholderColor(this.mutedText())
              .backgroundColor(this.raisedBackground())
              .border({ width: 1, color: this.dividerColor() })
              .borderRadius(6)
              .enabled(!this.isSavingEditor)
              .onChange((value: string): void => {
                this.webTags = value;
              })
              .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
          }
          .width('100%');
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto);
        Row({ space: 9 }) {
          if (this.editingWebId.length > 0) {
            this.ToolButton((): string => '打开来源', (): void => {
              const document = this.documentById(this.editingWebId);
              if (document !== undefined) {
                this.openWebSource(document);
              }
            }, (): boolean => !this.isSavingEditor);
          }
          Blank();
          this.ToolButton((): string => '取消', (): void => {
            this.requestCloseEditor('WEB');
          }, (): boolean => !this.isSavingEditor);
          this.AccentButton(
            (): string => this.isSavingEditor ? '正在保存…' : '保存资料卡',
            (): void => {
              this.saveWebDocument();
            },
            (): boolean => !this.isSavingEditor
          );
        }
        .width('100%');
      }
      .width(this.compactEditorWidth(560))
      .height(this.compactEditorHeight(560))
      .padding(20)
      .borderRadius(8)
      .backgroundColor(this.panelBackground())
      .border({ width: 1, color: this.dividerColor() });
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private PdfEditorOverlay(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.scrimColor())
        .onClick((): void => {
          this.requestCloseEditor('PDF');
        });
      Column({ space: 12 }) {
        Row() {
          Text('编辑 PDF 资料')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText());
          Blank();
          this.ToolButton((): string => '关闭', (): void => {
            this.requestCloseEditor('PDF');
          }, (): boolean => !this.isSavingEditor);
        }
        .width('100%');
        TextInput({ placeholder: '资料标题', text: this.pdfTitle })
          .width('100%')
          .height(38)
          .fontColor(this.primaryText())
          .placeholderColor(this.mutedText())
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() })
          .borderRadius(6)
          .enabled(!this.isSavingEditor)
          .onChange((value: string): void => {
            this.pdfTitle = value;
          })
          .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
        TextInput({ placeholder: '标签，使用逗号分隔', text: this.pdfTags })
          .width('100%')
          .height(38)
          .fontColor(this.primaryText())
          .placeholderColor(this.mutedText())
          .backgroundColor(this.raisedBackground())
          .border({ width: 1, color: this.dividerColor() })
          .borderRadius(6)
          .enabled(!this.isSavingEditor)
          .onChange((value: string): void => {
            this.pdfTags = value;
          })
          .onKeyEvent((event: KeyEvent): boolean => this.handleEditingShortcut(event));
        Row({ space: 9 }) {
          Blank();
          this.ToolButton((): string => '取消', (): void => {
            this.requestCloseEditor('PDF');
          }, (): boolean => !this.isSavingEditor);
          this.AccentButton(
            (): string => this.isSavingEditor ? '正在保存…' : '保存资料',
            (): void => {
              this.savePdfDocument();
            },
            (): boolean => !this.isSavingEditor
          );
        }
        .width('100%');
      }
      .width(this.compactEditorWidth(480))
      .padding(20)
      .borderRadius(8)
      .backgroundColor(this.panelBackground())
      .border({ width: 1, color: this.dividerColor() });
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private EditorDraftDiscardOverlay(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.scrimColor())
        .onClick((): void => {
          this.cancelEditorDraftDiscard();
        });
      Column({ space: 14 }) {
        Text(this.editorDraftTitle())
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .width('100%');
        Text(this.editorDraftTarget())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
          .lineHeight(20)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 10 })
          .border({ width: { left: 3 }, color: this.coralColor() });
        Text(this.editorDraftMessage())
          .fontSize(12)
          .fontColor(this.secondaryText())
          .lineHeight(19)
          .width('100%');
        Row({ space: 9 }) {
          Blank();
          this.ToolButton((): string => '继续编辑', (): void => {
            this.cancelEditorDraftDiscard();
          });
          this.DangerFilledButton(
            (): string => '放弃并继续',
            (): void => {
              this.discardEditorDraftAndContinue();
            }
          );
        }
        .width('100%');
      }
      .width(this.compactEditorWidth(480))
      .padding(20)
      .borderRadius(8)
      .backgroundColor(this.panelBackground())
      .border({ width: 1, color: this.dividerColor() });
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private DeleteConfirmOverlay(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.scrimColor())
        .onClick((): void => {
          this.cancelDelete();
        });
      Column({ space: 14 }) {
        Text(this.deleteDialogTitle())
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .width('100%');
        Text(this.deleteDialogTarget())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
          .lineHeight(20)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 10 })
          .border({ width: { left: 3 }, color: this.coralColor() });
        Text(this.deleteDialogMessage())
          .fontSize(12)
          .fontColor(this.secondaryText())
          .lineHeight(19)
          .width('100%');
        Row({ space: 9 }) {
          Blank();
          this.ToolButton((): string => '取消', (): void => {
            this.cancelDelete();
          }, (): boolean => !this.isDeleting);
          this.DangerFilledButton(
            (): string => this.isDeleting ? '正在删除…' : '确认删除',
            (): void => {
              this.confirmDelete();
            },
            (): boolean => !this.isDeleting
          );
        }
        .width('100%');
      }
      .width(this.compactEditorWidth(460))
      .padding(20)
      .borderRadius(8)
      .backgroundColor(this.panelBackground())
      .border({ width: 1, color: this.dividerColor() });
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private EvidenceDraftDiscardOverlay(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.scrimColor())
        .onClick((): void => {
          this.cancelEvidenceDraftDiscard();
        });
      Column({ space: 14 }) {
        Text('放弃未保存的证据卡？')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .width('100%');
        Row() {
          Text(this.selectedSourceLabel())
            .fontSize(11)
            .fontColor(this.mutedText());
          Blank();
          Text(this.evidenceNote.trim().length > 0 || this.evidenceTags.trim().length > 0 ? '含笔记或标签' : '仅原文选区')
            .fontSize(11)
            .fontColor(this.coralColor());
        }
        .width('100%');
        Text(this.selectedText)
          .fontSize(13)
          .fontColor(this.highlightPreviewText())
          .lineHeight(20)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding(10)
          .borderRadius(6)
          .backgroundColor(this.highlightPreviewBackground());
        Text(`${this.evidenceDraftDestinationLabel()}会丢弃这段原文的选区、笔记和标签。`)
          .fontSize(12)
          .fontColor(this.secondaryText())
          .lineHeight(19)
          .width('100%');
        Row({ space: 9 }) {
          Blank();
          this.ToolButton((): string => '继续编辑', (): void => {
            this.cancelEvidenceDraftDiscard();
          });
          this.DangerFilledButton(
            (): string => '放弃并继续',
            (): void => {
              this.discardEvidenceDraftAndContinue();
            }
          );
        }
        .width('100%');
      }
      .width(this.compactEditorWidth(480))
      .padding(20)
      .borderRadius(8)
      .backgroundColor(this.panelBackground())
      .border({ width: 1, color: this.dividerColor() });
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private DropOverlay(): void {
    Column({ space: 10 }) {
      Text('释放以导入 PDF')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accentColor());
      Text('文件会复制到阅迹本地资料库')
        .fontSize(13)
        .fontColor(this.secondaryText());
    }
    .width(360)
    .height(160)
    .justifyContent(FlexAlign.Center)
    .borderRadius(8)
    .backgroundColor(this.panelBackground())
    .border({ width: 2, color: this.accentColor(), style: BorderStyle.Dashed });
  }

  build() {
    Stack() {
      Column() {
        this.AppHeader();
        if (this.reviewSessionSourceOpen && this.reviewSessionCard() !== undefined) {
          this.ReviewSourceBar(this.reviewSessionCard()!);
        }
        Stack({ alignContent: Alignment.TopStart }) {
          Row() {
            if (this.windowWidth >= 1100 && !this.focusMode && this.leftSidebarOpen) {
              this.LeftSidebar();
            }
            if (this.mainView === 'LIBRARY') {
              this.LibraryView();
            } else if (this.mainView === 'REVIEW') {
              this.ReviewView();
            } else {
              this.ReaderView();
            }
            if (this.windowWidth >= 1100 &&
              this.mainView === 'READER' &&
              !this.focusMode &&
              this.rightSidebarOpen) {
              this.EvidenceSidebar();
            }
          }
          .width('100%')
          .height('100%');
          if (this.windowWidth < 1100 && !this.focusMode && this.leftSidebarOpen) {
            Row() {
              this.LeftSidebar();
              Column()
                .layoutWeight(1)
                .height('100%')
                .backgroundColor('#33000000')
                .onClick((): void => {
                  this.leftSidebarOpen = false;
                  this.saveSettings();
                });
            }
            .width('100%')
            .height('100%');
          }
          if (this.windowWidth < 1100 &&
            this.mainView === 'READER' &&
            !this.focusMode &&
            this.rightSidebarOpen &&
            !this.leftSidebarOpen) {
            Row() {
              Column()
                .layoutWeight(1)
                .height('100%')
                .backgroundColor('#33000000')
                .onClick((): void => {
                  this.rightSidebarOpen = false;
                  this.saveSettings();
                });
              this.EvidenceSidebar();
            }
            .width('100%')
            .height('100%');
          }
        }
        .width('100%')
        .layoutWeight(1);
        this.StatusBar();
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackground())
      .allowDrop(['general.file-uri', 'com.adobe.pdf'])
      .onDragEnter((): void => {
        if (this.isReady && !this.isLoading) {
          this.isDragOver = true;
          this.statusMessage = '释放鼠标即可导入 PDF';
        }
      })
      .onDragLeave((): void => {
        this.isDragOver = false;
      })
      .onDrop((event: DragEvent): void => {
        this.handleDrop(event);
      })
      .onAreaChange((oldValue: Area, newValue: Area): void => {
        this.windowWidth = Number(newValue.width);
        this.windowHeight = Number(newValue.height);
        const oldWidth = Number(oldValue.width);
        if (this.windowWidth < 1100 && oldWidth >= 1100 && !this.focusMode) {
          this.leftSidebarOpen = false;
          this.rightSidebarOpen = false;
        }
      });
      if (this.isDragOver) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#55000000');
          this.DropOverlay();
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None);
      }
      if (this.showWebEditor) {
        this.WebEditorOverlay();
      }
      if (this.showPdfEditor) {
        this.PdfEditorOverlay();
      }
      if (this.reviewSessionIds.length > 0 && !this.reviewSessionSourceOpen) {
        this.ReviewSessionOverlay();
      }
      if (this.editorDraftAction !== 'NONE') {
        this.EditorDraftDiscardOverlay();
      }
      if (this.evidenceDraftAction !== 'NONE') {
        this.EvidenceDraftDiscardOverlay();
      }
      if (this.deleteTargetKind !== 'NONE') {
        this.DeleteConfirmOverlay();
      }
    }
    .width('100%')
    .height('100%')
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent): boolean => this.handleShortcut(event));
  }
}
