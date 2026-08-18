import preferences from '@ohos.data.preferences';
import { AppSettings } from '../model/Models';

const DEFAULT_SETTINGS: AppSettings = {
  darkMode: false,
  focusMode: false,
  leftSidebarOpen: true,
  rightSidebarOpen: true,
  defaultHighlightColor: 0xFFFFD95A
};

function isBooleanValue(value: Object): boolean {
  return typeof value === 'boolean';
}

function isColorValue(value: Object): boolean {
  return typeof value === 'number' &&
    Number.isInteger(value) &&
    value >= 0 &&
    value <= 0xFFFFFFFF;
}

export class SettingsService {
  private store: preferences.Preferences | undefined;

  async initialize(context: Context): Promise<void> {
    this.store = await preferences.getPreferences(context, 'yueji-settings');
  }

  async load(): Promise<AppSettings> {
    if (this.store === undefined) {
      return {
        darkMode: DEFAULT_SETTINGS.darkMode,
        focusMode: DEFAULT_SETTINGS.focusMode,
        leftSidebarOpen: DEFAULT_SETTINGS.leftSidebarOpen,
        rightSidebarOpen: DEFAULT_SETTINGS.rightSidebarOpen,
        defaultHighlightColor: DEFAULT_SETTINGS.defaultHighlightColor
      };
    }
    const darkMode = await this.store.get('darkMode', DEFAULT_SETTINGS.darkMode);
    const focusMode = await this.store.get('focusMode', DEFAULT_SETTINGS.focusMode);
    const leftSidebarOpen = await this.store.get('leftSidebarOpen', DEFAULT_SETTINGS.leftSidebarOpen);
    const rightSidebarOpen = await this.store.get('rightSidebarOpen', DEFAULT_SETTINGS.rightSidebarOpen);
    const defaultHighlightColor =
      await this.store.get('defaultHighlightColor', DEFAULT_SETTINGS.defaultHighlightColor);
    return {
      darkMode: isBooleanValue(darkMode) ? darkMode as boolean : DEFAULT_SETTINGS.darkMode,
      focusMode: isBooleanValue(focusMode) ? focusMode as boolean : DEFAULT_SETTINGS.focusMode,
      leftSidebarOpen: isBooleanValue(leftSidebarOpen) ?
        leftSidebarOpen as boolean : DEFAULT_SETTINGS.leftSidebarOpen,
      rightSidebarOpen: isBooleanValue(rightSidebarOpen) ?
        rightSidebarOpen as boolean : DEFAULT_SETTINGS.rightSidebarOpen,
      defaultHighlightColor: isColorValue(defaultHighlightColor) ?
        defaultHighlightColor as number : DEFAULT_SETTINGS.defaultHighlightColor
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
