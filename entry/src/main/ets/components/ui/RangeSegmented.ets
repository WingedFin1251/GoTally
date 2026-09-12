// entry/src/main/ets/components/ui/RangeSegmented.ets
import { SegmentButton, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI';
import { Constants } from '../../common/constants/Constants';

/**
 * 周期筛选分段控件（官方胶囊形态 + 滑块式选中指示，替代原先的自绘胶囊按钮组）。
 *
 * 用法：
 *   RangeSegmented({ current: this.period, onPick: (p: string) => { ...切换逻辑... } })
 *
 * 说明：内部 selectedIndexes 需为 @State 数组并以 `$` 传给 SegmentButton 的 @Link，
 * 外部周期（current）变化时通过 @Watch 同步滑块位置。
 */
@Component
export struct RangeSegmented {
  /** 当前周期：today / 7d / 30d / all。 */
  @Watch('syncIndex') @Prop current: string = Constants.PERIOD_TODAY;
  /** 选中项下标数组（SegmentButton 的 @Link 入参）。 */
  @State selectedIndexes: number[] = [0];
  /** 选中回调：返回周期值。 */
  onPick: (period: string) => void = () => {};
  /** 选项配置：SegmentButton 的 options 需为状态变量（@State/@ObjectLink 语义）。 */
  @State options: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: [
      { text: $r('app.string.today') },
      { text: $r('app.string.days_7') },
      { text: $r('app.string.days_30') },
      { text: $r('app.string.all') },
    ] as SegmentButtonItemTuple,
    multiply: false,
  });

  aboutToAppear(): void {
    this.syncIndex();
  }

  /** 周期值 → 下标（顺序与上方 buttons 一致）。 */
  private static periods(): string[] {
    return [Constants.PERIOD_TODAY, '7d', '30d', Constants.PERIOD_ALL];
  }

  /** 外部周期变化时同步滑块选中项（如自动刷新、重置）。 */
  syncIndex(): void {
    const i = RangeSegmented.periods().indexOf(this.current);
    this.selectedIndexes = [i >= 0 ? i : 0];
  }

  build() {
    SegmentButton({
      options: this.options,
      selectedIndexes: $selectedIndexes,
      onItemClicked: (index: number) => {
        this.onPick(RangeSegmented.periods()[index]);
      },
    })
      .width('100%')
  }
}