// entry/src/main/ets/common/utils/ThemeUtil.ets
import { ConfigurationConstant } from '@kit.AbilityKit';

/**
 * 主题模式工具：支持「跟随系统 / 深色 / 浅色」三态。
 *
 * - `system`：跟随系统深色模式（`COLOR_MODE_NOT_SET`，由系统决定）
 * - `dark` / `light`：用户显式选择，不随系统变化
 *
 * 页面据此判断图标等资源该用哪一套（深色/浅色两套已预制）。
 */
export class ThemeUtil {
  static readonly MODE_SYSTEM: string = 'system';
  static readonly MODE_LIGHT: string = 'light';
  static readonly MODE_DARK: string = 'dark';

  /** 主题设置 + 系统当前是否深色 → 实际是否深色（纯函数，便于回归测试）。 */
  static resolveDark(themeMode: string, systemDark: boolean): boolean {
    if (themeMode === ThemeUtil.MODE_DARK) {
      return true;
    }
    if (themeMode === ThemeUtil.MODE_LIGHT) {
      return false;
    }
    // system（或历史遗留的未知值）→ 跟随系统
    return systemDark;
  }

  /** 是否跟随系统。 */
  static isFollowSystem(themeMode: string): boolean {
    return themeMode !== ThemeUtil.MODE_DARK && themeMode !== ThemeUtil.MODE_LIGHT;
  }

  /** 主题设置 → 应用色彩模式（system 用 NOT_SET 表示交给系统）。 */
  static colorModeOf(themeMode: string): ConfigurationConstant.ColorMode {
    if (themeMode === ThemeUtil.MODE_DARK) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    if (themeMode === ThemeUtil.MODE_LIGHT) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }

  /** 把系统色彩模式归一成布尔（仅深色为 true；未设置/未知按浅色处理由调用方兜底）。 */
  static systemDarkOf(colorMode: ConfigurationConstant.ColorMode | undefined): boolean {
    return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
}
