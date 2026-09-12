// entry/src/main/ets/common/utils/AppInfo.ets
import { bundleManager } from '@kit.AbilityKit';

/** 应用信息读取（版本号唯一来源：bundle 配置，避免多处硬编码不一致）。 */
export class AppInfo {
  private static cached: string = '';

  /** 应用版本名（如 "1.2.0"）；读取失败返回空串，调用方回退占位显示。 */
  static async versionName(): Promise<string> {
    if (AppInfo.cached !== '') {
      return AppInfo.cached;
    }
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      AppInfo.cached = info.versionName;
      return AppInfo.cached;
    } catch (e) {
      console.error('AppInfo.versionName failed: ' + (e instanceof Error ? e.message : String(e)));
      return '';
    }
  }
}