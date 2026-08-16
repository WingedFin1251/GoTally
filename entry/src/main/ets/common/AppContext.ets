// entry/src/main/ets/common/AppContext.ets
import { common } from '@kit.AbilityKit';

/** 在 EntryAbility.onCreate 注入，供 RDB/Preferences 等需要 context 的单例使用。 */
export class AppContext {
  static context: common.UIAbilityContext | null = null;

  /**
   * 获取应用上下文；未注入时抛错（调用方为 RDB/Preferences 初始化，仅在应用启动早期可能触发）。
   * 函数体显式 try/catch，满足 ArkTS 对可能抛异常函数的处理要求。
   */
  static get(): common.UIAbilityContext {
    try {
      if (AppContext.context === null) {
        throw new Error('AppContext not initialized');
      }
      return AppContext.context;
    } catch (e) {
      throw e instanceof Error ? e : new Error(String(e));
    }
  }
}
