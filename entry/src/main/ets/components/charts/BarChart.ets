// entry/src/main/ets/components/charts/BarChart.ets
import { formatCompact } from '../../common/utils/Formatter';
import { isZh } from '../../common/utils/Locale';

@Component
export struct BarChart {
  @Prop labels: string[] = [];
  @Prop values: number[] = [];
  @Prop colors: string[] = [];
  @Watch('redraw') @Prop version: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State axisColor: string = '#999999';
  @State textColor: string = '#666666';

  private max(): number {
    let m = 0;
    for (const v of this.values) {
      if (v > m) {
        m = v;
      }
    }
    return m > 0 ? m : 1;
  }

  private redraw(): void {
    if (this.ctx.width > 0 && this.ctx.height > 0) {
      this.draw();
    }
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    const padL = 34;
    const padR = 8;
    const padT = 10;
    const padB = 22;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;
    this.ctx.clearRect(0, 0, w, h);
    const n = this.values.length;
    if (n === 0) {
      return;
    }
    const slot = plotW / n;
    const bw = slot * 0.6;
    const max = this.max();
    // Y 轴网格
    this.ctx.fillStyle = this.axisColor;
    this.ctx.strokeStyle = this.axisColor;
    this.ctx.font = '9vp sans-serif';
    for (let g = 0; g <= 4; g++) {
      const gy = padT + plotH - (plotH * g / 4);
      this.ctx.beginPath();
      this.ctx.moveTo(padL, gy);
      this.ctx.lineTo(w - padR, gy);
      this.ctx.globalAlpha = 0.15;
      this.ctx.stroke();
      this.ctx.globalAlpha = 1;
      const val = Math.round(max * g / 4);
      this.ctx.fillText(formatCompact(val, isZh()), 4, gy + 3);
    }
    // 柱子
    for (let i = 0; i < n; i++) {
      const barH = this.values[i] > 0 ? (this.values[i] / max) * plotH : 1;
      const x = padL + i * slot + (slot - bw) / 2;
      const y = padT + plotH - barH;
      const c = this.colors.length > 0 ? this.colors[i % this.colors.length] : '#888888';
      this.ctx.fillStyle = c;
      this.ctx.fillRect(x, y, bw, barH);
    }
    // X 标签（抽样居中显示，避免重叠）
    this.ctx.fillStyle = this.textColor;
    this.ctx.textAlign = 'center';
    const labelStep = Math.max(1, Math.floor(n / 6));
    for (let i = 0; i < n; i += labelStep) {
      this.ctx.fillText(this.labels[i] ?? '', padL + i * slot + slot / 2, h - 8);
    }
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
