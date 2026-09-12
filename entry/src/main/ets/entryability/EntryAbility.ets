// entry/src/main/ets/entryability/EntryAbility.ets
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppContext } from '../common/AppContext';
import { SettingsStore } from '../data/SettingsStore';
import { DataProvider } from '../data/DataProvider';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContext.context = this.context;
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    this.applySavedLanguage();
    this.applySavedGlowLevel();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  /** 启动时应用用户保存的沉浸光感档位（供 HdsTabs 悬浮导航栏选择系统材质等级）。 */
  private async applySavedGlowLevel(): Promise<void> {
    try {
      const level = await SettingsStore.getGlowLevel();
      AppStorage.setOrCreate('glowLevel', level);
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'Failed to apply saved glow level. Cause: %{public}s', String(e));
    }
  }

  /** 启动时应用用户保存的语言偏好（配合设置页 ApplicationContext.setLanguage 运行时切换）。 */
  private async applySavedLanguage(): Promise<void> {
    try {
      const lang = await SettingsStore.getLanguage();
      this.context.getApplicationContext().setLanguage(lang === 'zh' ? 'zh-CN' : 'en-US');
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'Failed to apply saved language. Cause: %{public}s', String(e));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    const loadContent = (): void => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    };
    // 先在启动闪屏期间预读登录态，再加载首页：Index 首帧即可判定登录态，
    // 避免「先渲染欢迎/登录页、再跳首页」的闪屏跳变。
    this.preloadAuthState().then(() => {
      // 沉浸式布局：内容延伸到状态栏/导航条区域，再配合页面内的系统避让区内边距实现全屏效果
      try {
        windowStage.getMainWindowSync().setWindowLayoutFullScreen(true).then(loadContent).catch(loadContent);
      } catch (e) {
        loadContent();
      }
    });
  }

  /**
   * 启动前预读本地 token 并写入 AppStorage（authPreloaded / hasToken）。
   * 读取失败或超时（首次启动需建库/迁移历史数据，可能较慢）时不置 authPreloaded，
   * 交由 Index 的占位页 + 异步判定兜底，避免启动闪屏被长时间卡住。
   */
  private async preloadAuthState(): Promise<void> {
    const read = async (): Promise<void> => {
      const token = await DataProvider.getStore().getToken();
      AppStorage.setOrCreate('hasToken', token.trim() !== '');
      AppStorage.setOrCreate('authPreloaded', true);
    };
    try {
      await Promise.race([read(), EntryAbility.delay(300)]);
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'Failed to preload auth state. Cause: %{public}s', String(e));
    }
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  onWindowStageDestroy(): void { /* 释放资源 */ }
  onForeground(): void { /* 前台 */ }
  onBackground(): void { /* 后台 */ }
}
