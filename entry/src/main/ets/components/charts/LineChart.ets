// entry/src/main/ets/components/charts/LineChart.ets
import { formatCompact } from '../../common/utils/Formatter';
import { isZh } from '../../common/utils/Locale';

export interface LineSeries {
  name: string;
  color: string;
  values: number[];
  /** 所属坐标轴：left（默认）为主轴，right 走独立右轴（适用于量纲悬殊的系列，如美元成本）。 */
  axis?: 'left' | 'right';
}

@Component
export struct LineChart {
  @Watch('redraw') @Prop series: LineSeries[] = [];
  @Prop labels: string[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private redraw(): void {
    if (this.ctx.width > 0 && this.ctx.height > 0) {
      this.draw();
    }
  }

  private maxValue(axis: 'left' | 'right'): number {
    let m = 0;
    for (const s of this.series) {
      if ((s.axis ?? 'left') !== axis) {
        continue;
      }
      for (const v of s.values) {
        if (v > m) {
          m = v;
        }
      }
    }
    return m > 0 ? m : 1;
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    const padL = 40;
    const padR = 38; // 右轴刻度空间
    const padT = 30; // 顶部图例（可能两行）
    const padB = 22;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;
    this.ctx.clearRect(0, 0, w, h);
    const n = this.labels.length;
    if (n === 0) {
      return;
    }
    const maxL = this.maxValue('left');
    const maxR = this.maxValue('right');
    const xOf = (i: number): number => padL + (n === 1 ? plotW / 2 : (plotW * i) / (n - 1));
    const yOf = (v: number, m: number): number => padT + plotH - (v / m) * plotH;
    // 网格 + 左轴刻度
    this.ctx.strokeStyle = '#999999';
    this.ctx.globalAlpha = 0.15;
    this.ctx.font = '9vp sans-serif';
    for (let g = 0; g <= 4; g++) {
      const gy = padT + (plotH * g) / 4;
      this.ctx.beginPath();
      this.ctx.moveTo(padL, gy);
      this.ctx.lineTo(w - padR, gy);
      this.ctx.stroke();
      this.ctx.globalAlpha = 1;
      const val = Math.round(maxL - (maxL * g) / 4);
      this.ctx.fillStyle = '#999999';
      this.ctx.textAlign = 'left';
      this.ctx.fillText(formatCompact(val, isZh()), 4, gy + 3);
    }
    this.ctx.globalAlpha = 1;
    // 右轴刻度（成本等独立量纲）
    this.ctx.fillStyle = '#999999';
    this.ctx.textAlign = 'right';
    for (let g = 0; g <= 4; g++) {
      const gy = padT + (plotH * g) / 4;
      const val = maxR - (maxR * g) / 4;
      this.ctx.fillText(formatCompact(val, isZh()), w - padR + 30, gy + 3);
    }
    this.ctx.textAlign = 'left';
    // 图例（顶部，按实际文本宽度排布，超宽自动换行避免重叠）
    this.ctx.font = '9vp sans-serif';
    this.ctx.fillStyle = '#999999';
    let lx = padL;
    let ly = 5;
    for (const s of this.series) {
      const nameW = this.ctx.measureText(s.name).width;
      const blockW = 15 + nameW + 12;
      if (lx + blockW > w - padR && lx > padL) {
        lx = padL;
        ly += 12;
      }
      this.ctx.strokeStyle = s.color;
      this.ctx.lineWidth = 2;
      this.ctx.beginPath();
      this.ctx.moveTo(lx, ly);
      this.ctx.lineTo(lx + 12, ly);
      this.ctx.stroke();
      this.ctx.fillStyle = '#999999';
      this.ctx.fillText(s.name, lx + 15, ly + 3);
      lx += blockW;
    }
    this.ctx.lineWidth = 2;
    // 折线（每个系列按所属轴独立缩放）
    for (const s of this.series) {
      const m = (s.axis ?? 'left') === 'right' ? maxR : maxL;
      this.ctx.strokeStyle = s.color;
      this.ctx.lineWidth = 2;
      this.ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const x = xOf(i);
        const v = i < s.values.length ? s.values[i] : 0;
        const y = yOf(v, m);
        if (i === 0) {
          this.ctx.moveTo(x, y);
        } else {
          this.ctx.lineTo(x, y);
        }
      }
      this.ctx.stroke();
    }
    // X 标签（抽样居中显示，避免重叠与越界裁剪）
    this.ctx.fillStyle = '#999999';
    this.ctx.textAlign = 'center';
    const step = Math.max(1, Math.floor(n / 6));
    for (let i = 0; i < n; i += step) {
      const lx2 = Math.min(Math.max(xOf(i), padL), w - padR);
      this.ctx.fillText(this.labels[i], lx2, h - 6);
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