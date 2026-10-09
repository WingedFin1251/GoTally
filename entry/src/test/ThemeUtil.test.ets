// entry/src/test/ThemeUtil.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { ThemeUtil } from '../main/ets/common/utils/ThemeUtil';

/**
 * 主题三态（跟随系统 / 深色 / 浅色）解析（回归测试）。
 *
 * 关闭「跟随系统」时要按**当前实际外观**固化，避免开关瞬间跳色；
 * 打开时交回系统决定。这里锁定解析规则。
 */
export default function themeUtilTest() {
  describe('ThemeUtilTest', () => {
    it('explicit_modes_ignore_system', 0, () => {
      expect(ThemeUtil.resolveDark(ThemeUtil.MODE_DARK, false)).assertTrue();
      expect(ThemeUtil.resolveDark(ThemeUtil.MODE_DARK, true)).assertTrue();
      expect(ThemeUtil.resolveDark(ThemeUtil.MODE_LIGHT, true)).assertFalse();
      expect(ThemeUtil.resolveDark(ThemeUtil.MODE_LIGHT, false)).assertFalse();
    });

    it('system_mode_follows_system', 0, () => {
      expect(ThemeUtil.resolveDark(ThemeUtil.MODE_SYSTEM, true)).assertTrue();
      expect(ThemeUtil.resolveDark(ThemeUtil.MODE_SYSTEM, false)).assertFalse();
      // 历史遗留/未知值也按跟随系统处理（不会误判成深色）
      expect(ThemeUtil.resolveDark('', false)).assertFalse();
      expect(ThemeUtil.resolveDark('auto', true)).assertTrue();
    });

    it('is_follow_system', 0, () => {
      expect(ThemeUtil.isFollowSystem(ThemeUtil.MODE_SYSTEM)).assertTrue();
      expect(ThemeUtil.isFollowSystem('auto')).assertTrue();
      expect(ThemeUtil.isFollowSystem(ThemeUtil.MODE_DARK)).assertFalse();
      expect(ThemeUtil.isFollowSystem(ThemeUtil.MODE_LIGHT)).assertFalse();
    });

    it('color_mode_mapping', 0, () => {
      // NOT_SET(=跟随系统) 的枚举值在各 API 版本可能不同，这里只校验互不相等且可解析
      const sys = ThemeUtil.colorModeOf(ThemeUtil.MODE_SYSTEM);
      const dark = ThemeUtil.colorModeOf(ThemeUtil.MODE_DARK);
      const light = ThemeUtil.colorModeOf(ThemeUtil.MODE_LIGHT);
      expect(dark === light).assertFalse();
      expect(sys === dark).assertFalse();
      expect(sys === light).assertFalse();
      // 系统深色判定
      expect(ThemeUtil.systemDarkOf(dark)).assertTrue();
      expect(ThemeUtil.systemDarkOf(light)).assertFalse();
      expect(ThemeUtil.systemDarkOf(undefined)).assertFalse();
    });
  });
}
