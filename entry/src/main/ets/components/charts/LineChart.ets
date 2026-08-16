// entry/src/main/ets/components/charts/LineChart.ets

export interface LineSeries {
  name: string;
  color: string;
  values: number[];
}

@Component
export struct LineChart {
  @Prop series: LineSeries[] = [];
  @Prop labels: string[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private maxValue(): number {
    let m = 0;
    for (const s of this.series) {
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
    const padR = 10;
    const padT = 12;
    const padB = 22;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;
    this.ctx.clearRect(0, 0, w, h);
    const n = this.labels.length;
    if (n === 0) {
      return;
    }
    const max = this.maxValue();
    const xOf = (i: number): number => padL + (n === 1 ? plotW / 2 : (plotW * i) / (n - 1));
    const yOf = (v: number): number => padT + plotH - (v / max) * plotH;
    // 网格
    this.ctx.strokeStyle = '#999999';
    this.ctx.globalAlpha = 0.15;
    this.ctx.font = '9vp sans-serif';
    for (let g = 0; g <= 4; g++) {
      const gy = padT + (plotH * g) / 4;
      this.ctx.beginPath();
      this.ctx.moveTo(padL, gy);
      this.ctx.lineTo(w - padR, gy);
      this.ctx.stroke();
    }
    this.ctx.globalAlpha = 1;
    // 折线
    for (const s of this.series) {
      this.ctx.strokeStyle = s.color;
      this.ctx.lineWidth = 2;
      this.ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const x = xOf(i);
        const v = i < s.values.length ? s.values[i] : 0;
        const y = yOf(v);
        if (i === 0) {
          this.ctx.moveTo(x, y);
        } else {
          this.ctx.lineTo(x, y);
        }
      }
      this.ctx.stroke();
    }
    // X 标签（抽样显示）
    this.ctx.fillStyle = '#999999';
    const step = Math.max(1, Math.floor(n / 6));
    for (let i = 0; i < n; i += step) {
      this.ctx.fillText(this.labels[i], xOf(i), h - 6);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.draw();
      })
  }
}
