// entry/src/main/ets/common/AppContext.ets
import { common } from '@kit.AbilityKit';

/** 在 EntryAbility.onCreate 注入，供 RDB/Preferences 等需要 context 的单例使用。 */
export class AppContext {
  static context: common.UIAbilityContext | null = null;

  static get(): common.UIAbilityContext {
    if (AppContext.context === null) {
      throw new Error('AppContext not initialized');
    }
    return AppContext.context;
  }
}
