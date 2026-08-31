// entry/src/main/ets/components/charts/DonutChart.ets

export interface DonutItem {
  label: string;
  value: number;
  color: string;
}

@Component
export struct DonutChart {
  @Watch('redraw') @Prop items: DonutItem[] = [];
  /** 渲染版本号：父组件每次整体更新数据/维度都 +1，供父层用 if 奇偶分支强制重建 Canvas。 */
  @Prop version: number = 0;
  @Prop centerTitle: string = '';
  @Prop centerValue: string = '';
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private redraw(): void {
    if (this.ctx.width > 0 && this.ctx.height > 0) {
      this.draw();
    }
  }

  private total(): number {
    let t = 0;
    for (const it of this.items) {
      t += it.value;
    }
    return t;
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    this.ctx.clearRect(0, 0, w, h);
    const cx = w / 2;
    const cy = h / 2;
    const r = Math.min(w, h) / 2 - 8;
    const innerR = r * 0.62;
    const total = this.total();
    if (total <= 0) {
      this.ctx.fillStyle = '#e8eaed';
      this.ctx.beginPath();
      this.ctx.arc(cx, cy, r, 0, Math.PI * 2);
      this.ctx.fill();
      return;
    }
    let start = -Math.PI / 2;
    for (const it of this.items) {
      const sweep = Math.max(0, it.value / total * Math.PI * 2);
      this.ctx.beginPath();
      this.ctx.fillStyle = it.color;
      this.ctx.moveTo(cx, cy);
      this.ctx.arc(cx, cy, r, start, start + sweep);
      this.ctx.closePath();
      this.ctx.fill();
      // 内圈挖空（环形）
      this.ctx.globalCompositeOperation = 'destination-out';
      this.ctx.beginPath();
      this.ctx.arc(cx, cy, innerR, 0, Math.PI * 2);
      this.ctx.fill();
      this.ctx.globalCompositeOperation = 'source-over';
      start += sweep;
    }
    // 中心文字改为 UI 层 Text 渲染（见 build），保证与父组件数据同帧刷新，不依赖 Canvas 重绘
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.redraw();
        })
      // 中心文字用声明式 Text：父组件 build 传新值即自动刷新（与图例同一可靠机制），
      // 不再依赖 Canvas 重绘时机，彻底消除「中心数字滞旧」。
      Column({ space: 2 }) {
        Text(this.centerValue)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.centerTitle)
          .fontSize(10)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
  }
}