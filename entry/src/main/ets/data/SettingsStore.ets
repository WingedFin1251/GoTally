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
  static readonly GLOW_LEVEL: string = 'glow_level';
  /** 可选的 OpenCode Go API Key（填写后配额优先走官方接口）。 */
  static readonly GO_API_KEY: string = 'go_api_key';
}

export interface AppSettings {
  syncIntervalSec: number;
  windowDays: number | null;
  autoSync: boolean;
  theme: string;
  currency: string;
  language: string;
  /** 沉浸光感档位：0 弱(GENTLE) / 1 均衡(ADAPTIVE) / 2 强(EXQUISITE)。 */
  glowLevel: number;
  /** 可选的 OpenCode Go API Key（空串表示未配置）。 */
  goApiKey: string;
}

const DEFAULT_SETTINGS: AppSettings = {
  syncIntervalSec: 300,
  windowDays: 60,
  autoSync: true,
  // 新装默认跟随系统深色模式（老用户已存的值不受影响）
  theme: 'system',
  currency: 'CNY',
  language: 'zh',
  glowLevel: 1,
  goApiKey: '',
};

/** Preferences 设置存储（同步间隔/范围/开关/主题/货币/语言）。 */
export class SettingsStore {
  private static pref: preferences.Preferences | null = null;

  static async getPref(): Promise<preferences.Preferences> {
    try {
      if (SettingsStore.pref !== null) {
        return SettingsStore.pref;
      }
      const ctx = AppContext.get();
      const pref = await preferences.getPreferences(ctx, Constants.PREF_NAME);
      SettingsStore.pref = pref;
      return pref;
    } catch (e) {
      throw e instanceof Error ? e : new Error(String(e));
    }
  }

  static async getAll(): Promise<AppSettings> {
    try {
      const pref = await SettingsStore.getPref();
      const interval = await pref.get(SettingsKeys.SYNC_INTERVAL_SEC, DEFAULT_SETTINGS.syncIntervalSec) as number;
      const windowRaw = await pref.get(SettingsKeys.WINDOW_DAYS, 60) as number;
      const autoSync = await pref.get(SettingsKeys.AUTO_SYNC, DEFAULT_SETTINGS.autoSync) as boolean;
      const theme = await pref.get(SettingsKeys.THEME, DEFAULT_SETTINGS.theme) as string;
      const currency = await pref.get(SettingsKeys.CURRENCY, DEFAULT_SETTINGS.currency) as string;
      const language = await pref.get(SettingsKeys.LANGUAGE, DEFAULT_SETTINGS.language) as string;
      const glowLevel = await pref.get(SettingsKeys.GLOW_LEVEL, DEFAULT_SETTINGS.glowLevel) as number;
      const goApiKey = await pref.get(SettingsKeys.GO_API_KEY, DEFAULT_SETTINGS.goApiKey) as string;
      return {
        syncIntervalSec: interval,
        windowDays: windowRaw > 0 ? windowRaw : null,
        autoSync: autoSync,
        theme: theme,
        currency: currency,
        language: language,
        glowLevel: glowLevel,
        goApiKey: goApiKey,
      };
    } catch (e) {
      throw e instanceof Error ? e : new Error(String(e));
    }
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

  static async getGlowLevel(): Promise<number> {
    return (await SettingsStore.getAll()).glowLevel;
  }

  /** 主题模式：'system'（跟随系统）/ 'dark' / 'light'。 */
  static async getTheme(): Promise<string> {
    return (await SettingsStore.getAll()).theme;
  }

  /** 可选的 OpenCode Go API Key（空串表示未配置）。 */
  static async getGoApiKey(): Promise<string> {
    return (await SettingsStore.getAll()).goApiKey;
  }

  /**
   * 单独写 API Key。
   *
   * 刻意不放进 save()：设置页持有的是「加载时」的 AppSettings 快照，
   * 若 save() 一并回写 goApiKey，任何一次改主题/光感等操作都可能把后设置的 Key 覆盖成空串。
   */
  static async setGoApiKey(key: string): Promise<void> {
    await SettingsStore.put(SettingsKeys.GO_API_KEY, key.trim());
  }

  static async put(key: string, value: preferences.ValueType): Promise<void> {
    try {
      const pref = await SettingsStore.getPref();
      await pref.put(key, value);
      await pref.flush();
    } catch (e) {
      throw e instanceof Error ? e : new Error(String(e));
    }
  }

  static async save(payload: AppSettings): Promise<void> {
    try {
      const pref = await SettingsStore.getPref();
      await pref.put(SettingsKeys.SYNC_INTERVAL_SEC, payload.syncIntervalSec);
      await pref.put(SettingsKeys.WINDOW_DAYS, payload.windowDays !== null ? payload.windowDays : 0);
      await pref.put(SettingsKeys.AUTO_SYNC, payload.autoSync);
      await pref.put(SettingsKeys.THEME, payload.theme);
      await pref.put(SettingsKeys.CURRENCY, payload.currency);
      await pref.put(SettingsKeys.LANGUAGE, payload.language);
      await pref.put(SettingsKeys.GLOW_LEVEL, payload.glowLevel);
      // 注意：goApiKey 不在此处写入，改由 setGoApiKey 单独维护（避免被陈旧快照覆盖）
      await pref.flush();
    } catch (e) {
      throw e instanceof Error ? e : new Error(String(e));
    }
  }
}
