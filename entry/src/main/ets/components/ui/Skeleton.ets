// entry/src/main/ets/components/ui/Skeleton.ets

/**
 * 骨架屏占位块：数据加载时用灰块占住「即将出现的布局」，避免一屏 0 值让人误以为数据丢了。
 *
 * 用法：`SkeletonBlock({ blockWidth: 120, blockHeight: 14 })`
 * 带微光呼吸动画（opacity 在 0.35 ↔ 0.85 间无限交替），让用户明确感知"正在加载"。
 */
@Component
export struct SkeletonBlock {
  @Prop blockWidth: Length = '100%';
  @Prop blockHeight: number = 14;
  @Prop radius: number = 4;
  @State private lit: boolean = false;

  build() {
    Row()
      .width(this.blockWidth)
      .height(this.blockHeight)
      .borderRadius(this.radius)
      .backgroundColor($r('app.color.divider'))
      .opacity(this.lit ? 0.85 : 0.35)
      .animation({ duration: 900, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
      .onAppear(() => { this.lit = true; })
  }
}

/** KPI 卡片骨架：标题条 + 数值条（与 StatCard 尺寸对齐，替换时不跳动）。 */
@Component
export struct SkeletonStatCard {
  build() {
    Column({ space: 8 }) {
      SkeletonBlock({ blockWidth: '60%', blockHeight: 11 })
      SkeletonBlock({ blockWidth: '80%', blockHeight: 16 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }
}

/** 配额窗口骨架：标签 + 进度条 + 百分比行（与 QuotaProgress 高度接近）。 */
@Component
export struct SkeletonQuota {
  build() {
    Column({ space: 8 }) {
      Row() {
        SkeletonBlock({ blockWidth: 72, blockHeight: 13 })
        Blank()
        SkeletonBlock({ blockWidth: 48, blockHeight: 13 })
      }
      .width('100%')
      SkeletonBlock({ blockWidth: '100%', blockHeight: 8, radius: 4 })
      Row() {
        SkeletonBlock({ blockWidth: 96, blockHeight: 10 })
        Blank()
        SkeletonBlock({ blockWidth: 64, blockHeight: 10 })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }
}

/** 图表骨架：标题行 + 一大块图区遮罩。 */
@Component
export struct SkeletonChart {
  @Prop blockHeight: number = 140;

  build() {
    Column({ space: 10 }) {
      Row() {
        SkeletonBlock({ blockWidth: 96, blockHeight: 14 })
        Blank()
        SkeletonBlock({ blockWidth: 56, blockHeight: 11 })
      }
      .width('100%')
      SkeletonBlock({ blockWidth: '100%', blockHeight: this.blockHeight, radius: 8 })
    }
    .width('100%')
  }
}
