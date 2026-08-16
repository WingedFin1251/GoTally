// entry/src/main/ets/data/SettingsStore.ets
import { preferences } from '@kit.ArkData';
import { AppContext } from '../common/AppContext';
import { Constants } from '../common/constants/Constants';

/** 设置项键名。 */
export class SettingsKeys {
  static readonly SYNC_INTERVAL_SEC: string = 'sync_interval_sec';
  static readonly WINDOW_DAYS: string = 'window_days';
  static readonly AUTO_SYNC: string = 'auto_sync';
  static readonly THEME: string = 'theme';
  static readonly CURRENCY: string = 'currency';
  static readonly LANGUAGE: string = 'language';
}

export interface AppSettings {
  syncIntervalSec: number;
  windowDays: number | null;
  autoSync: boolean;
  theme: string;
  currency: string;
  language: string;
}

const DEFAULT_SETTINGS: AppSettings = {
  syncIntervalSec: 300,
  windowDays: 60,
  autoSync: true,
  theme: 'light',
  currency: 'CNY',
  language: 'zh',
};

/** Preferences 设置存储（同步间隔/范围/开关/主题/货币/语言）。 */
export class SettingsStore {
  private static pref: preferences.Preferences | null = null;

  static async getPref(): Promise<preferences.Preferences> {
    if (SettingsStore.pref !== null) {
      return SettingsStore.pref;
    }
    const ctx = AppContext.get();
    const pref = await preferences.getPreferences(ctx, Constants.PREF_NAME);
    SettingsStore.pref = pref;
    return pref;
  }

  static async getAll(): Promise<AppSettings> {
    const pref = await SettingsStore.getPref();
    const interval = await pref.get(SettingsKeys.SYNC_INTERVAL_SEC, DEFAULT_SETTINGS.syncIntervalSec) as number;
    const windowRaw = await pref.get(SettingsKeys.WINDOW_DAYS, 60) as number;
    const autoSync = await pref.get(SettingsKeys.AUTO_SYNC, DEFAULT_SETTINGS.autoSync) as boolean;
    const theme = await pref.get(SettingsKeys.THEME, DEFAULT_SETTINGS.theme) as string;
    const currency = await pref.get(SettingsKeys.CURRENCY, DEFAULT_SETTINGS.currency) as string;
    const language = await pref.get(SettingsKeys.LANGUAGE, DEFAULT_SETTINGS.language) as string;
    return {
      syncIntervalSec: interval,
      windowDays: windowRaw > 0 ? windowRaw : null,
      autoSync: autoSync,
      theme: theme,
      currency: currency,
      language: language,
    };
  }

  static async getWindowDays(): Promise<number | null> {
    return (await SettingsStore.getAll()).windowDays;
  }

  static async getSyncIntervalSec(): Promise<number> {
    return (await SettingsStore.getAll()).syncIntervalSec;
  }

  static async getAutoSync(): Promise<boolean> {
    return (await SettingsStore.getAll()).autoSync;
  }

  static async getCurrency(): Promise<string> {
    return (await SettingsStore.getAll()).currency;
  }

  static async getLanguage(): Promise<string> {
    return (await SettingsStore.getAll()).language;
  }

  static async put(key: string, value: preferences.ValueType): Promise<void> {
    const pref = await SettingsStore.getPref();
    await pref.put(key, value);
    await pref.flush();
  }

  static async save(payload: AppSettings): Promise<void> {
    const pref = await SettingsStore.getPref();
    await pref.put(SettingsKeys.SYNC_INTERVAL_SEC, payload.syncIntervalSec);
    await pref.put(SettingsKeys.WINDOW_DAYS, payload.windowDays !== null ? payload.windowDays : 0);
    await pref.put(SettingsKeys.AUTO_SYNC, payload.autoSync);
    await pref.put(SettingsKeys.THEME, payload.theme);
    await pref.put(SettingsKeys.CURRENCY, payload.currency);
    await pref.put(SettingsKeys.LANGUAGE, payload.language);
    await pref.flush();
  }
}
