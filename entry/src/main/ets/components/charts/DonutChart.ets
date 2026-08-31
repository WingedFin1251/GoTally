// entry/src/main/ets/components/charts/DonutChart.ets

export interface DonutItem {
  label: string;
  value: number;
  color: string;
}

@Component
export struct DonutChart {
  @Watch('redraw') @Prop items: DonutItem[] = [];
  /** 渲染版本号：父组件每次整体更新数据/维度都 +1，强制重绘，避免 @Prop 判定「未变化」导致中心文字滞旧。 */
  @Watch('redraw') @Prop version: number = 0;
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
    // 中心文字
    this.ctx.fillStyle = '#1a1a1a';
    this.ctx.font = 'bold 14vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(this.centerValue, cx, cy - 2);
    this.ctx.font = '10vp sans-serif';
    this.ctx.fillStyle = '#999999';
    this.ctx.fillText(this.centerTitle, cx, cy + 14);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.redraw();
      })
  }
}
