import preferences from '@ohos.data.preferences';
import { AppSettings } from '../model/Models';

const DEFAULT_SETTINGS: AppSettings = {
  darkMode: false,
  focusMode: false,
  leftSidebarOpen: true,
  rightSidebarOpen: true,
  defaultHighlightColor: 0xFFFFD95A
};

export class SettingsService {
  private store: preferences.Preferences | undefined;

  async initialize(context: Context): Promise<void> {
    this.store = await preferences.getPreferences(context, 'yueji-settings');
  }

  async load(): Promise<AppSettings> {
    if (this.store === undefined) {
      return DEFAULT_SETTINGS;
    }
    return {
      darkMode: await this.store.get('darkMode', DEFAULT_SETTINGS.darkMode) as boolean,
      focusMode: await this.store.get('focusMode', DEFAULT_SETTINGS.focusMode) as boolean,
      leftSidebarOpen: await this.store.get('leftSidebarOpen', DEFAULT_SETTINGS.leftSidebarOpen) as boolean,
      rightSidebarOpen: await this.store.get('rightSidebarOpen', DEFAULT_SETTINGS.rightSidebarOpen) as boolean,
      defaultHighlightColor:
        await this.store.get('defaultHighlightColor', DEFAULT_SETTINGS.defaultHighlightColor) as number
    };
  }

  async save(settings: AppSettings): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    await this.store.put('darkMode', settings.darkMode);
    await this.store.put('focusMode', settings.focusMode);
    await this.store.put('leftSidebarOpen', settings.leftSidebarOpen);
    await this.store.put('rightSidebarOpen', settings.rightSidebarOpen);
    await this.store.put('defaultHighlightColor', settings.defaultHighlightColor);
    await this.store.flush();
  }
}
