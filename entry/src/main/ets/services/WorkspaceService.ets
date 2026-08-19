import preferences from '@ohos.data.preferences';
import {
  LibraryScope,
  MainView,
  normalizeZoomPercent,
  ReviewFilter,
  WorkspaceState
} from '../model/Models';

const DEFAULT_WORKSPACE: WorkspaceState = {
  mainView: 'LIBRARY',
  libraryScope: 'ALL',
  reviewFilter: 'ALL',
  activeDocumentId: '',
  selectedCollectionId: '',
  zoomPercent: 100,
  librarySearch: '',
  selectedTag: '',
  reviewSearch: '',
  reviewSelectedTag: '',
  searchText: '',
  savedAt: 0
};

export class WorkspaceService {
  private store: preferences.Preferences | undefined;

  async initialize(context: Context): Promise<void> {
    this.store = await preferences.getPreferences(context, 'yueji-workspace');
  }

  async load(): Promise<WorkspaceState> {
    if (this.store === undefined) {
      return this.copy(DEFAULT_WORKSPACE);
    }
    const value = await this.store.get('workspace', '');
    if (typeof value !== 'string' || value.length === 0) {
      return this.copy(DEFAULT_WORKSPACE);
    }
    try {
      const parsed = JSON.parse(value) as WorkspaceState;
      return this.normalize(parsed);
    } catch (error) {
      return this.copy(DEFAULT_WORKSPACE);
    }
  }

  async save(state: WorkspaceState): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    await this.store.put('workspace', JSON.stringify(this.normalize(state)));
    await this.store.flush();
  }

  private normalize(value: WorkspaceState): WorkspaceState {
    const mainView: MainView =
      value.mainView === 'READER' || value.mainView === 'REVIEW' ? value.mainView : 'LIBRARY';
    const libraryScope: LibraryScope =
      value.libraryScope === 'RECENT' || value.libraryScope === 'FAVORITE' ?
        value.libraryScope : 'ALL';
    const reviewFilter: ReviewFilter =
      value.reviewFilter === 'TO_REVIEW' || value.reviewFilter === 'MASTERED' ?
        value.reviewFilter : 'ALL';
    const zoomPercent = normalizeZoomPercent(value.zoomPercent, DEFAULT_WORKSPACE.zoomPercent);
    return {
      mainView: mainView,
      libraryScope: libraryScope,
      reviewFilter: reviewFilter,
      activeDocumentId: this.safeString(value.activeDocumentId),
      selectedCollectionId: this.safeString(value.selectedCollectionId),
      zoomPercent: zoomPercent,
      librarySearch: this.safeString(value.librarySearch),
      selectedTag: this.safeString(value.selectedTag),
      reviewSearch: this.safeString(value.reviewSearch),
      reviewSelectedTag: this.safeString(value.reviewSelectedTag),
      searchText: this.safeString(value.searchText),
      savedAt: Number.isFinite(value.savedAt) ? value.savedAt : 0
    };
  }

  private safeString(value: Object): string {
    return typeof value === 'string' ? value.slice(0, 200) : '';
  }

  private copy(value: WorkspaceState): WorkspaceState {
    return {
      mainView: value.mainView,
      libraryScope: value.libraryScope,
      reviewFilter: value.reviewFilter,
      activeDocumentId: value.activeDocumentId,
      selectedCollectionId: value.selectedCollectionId,
      zoomPercent: value.zoomPercent,
      librarySearch: value.librarySearch,
      selectedTag: value.selectedTag,
      reviewSearch: value.reviewSearch,
      reviewSelectedTag: value.reviewSelectedTag,
      searchText: value.searchText,
      savedAt: value.savedAt
    };
  }
}
