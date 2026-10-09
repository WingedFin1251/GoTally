// entry/src/main/ets/data/ConsoleIntraday.ets
import type { TrendPoint } from '../model/Stats';

/** 当日采样的一个点（累计值：当天到该时刻为止的用量）。 */
export interface IntradaySample {
  /** 采样时刻（epoch 分钟），同时用作去重主键。 */
  tsMin: number;
  input: number;
  output: number;
  requests: number;
  costUsd: number;
}

/**
 * 今日（小时级）趋势的本地重建。
 *
 * 背景：官方控制台只提供「逐日」聚合（`/usage/cost-by-day`），**没有小时级接口**；
 * 而旧登录下的本地逐条明细在控制台登录下为空，于是「今日趋势」图一直是空的。
 *
 * 做法：每次刷新（启动 / 定时 / 手动）把当日累计用量记为一个采样点，
 * 再把采样点按本地小时归并、对累计值求增量，得到逐小时用量：
 *   - 每个小时取该小时内**最后一个**采样点（同小时多次刷新只算一次）
 *   - 该小时用量 = 本小时累计 − 上一个有数据的小时的累计
 *   - 第一个有数据的小时直接取累计值（把「开始采样之前」的用量一并算进去，不丢数据）
 */
export class ConsoleIntraday {
  /** 本地日期（YYYY-MM-DD）。 */
  static localDay(d: Date): string {
    const y = d.getFullYear();
    const m = `${d.getMonth() + 1}`.padStart(2, '0');
    const day = `${d.getDate()}`.padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  /** epoch 毫秒 → epoch 分钟（采样去重粒度）。 */
  static toTsMin(ms: number): number {
    return Math.floor(ms / 60000);
  }

  /** 采样点所在本地小时（0-23）。 */
  static hourOf(tsMin: number): number {
    return new Date(tsMin * 60000).getHours();
  }

  /** 由采样点重建逐小时趋势（按小时升序）。 */
  static buildTrend(samples: IntradaySample[]): TrendPoint[] {
    if (samples.length === 0) {
      return [];
    }
    const sorted = samples.slice();
    sorted.sort((a, b) => a.tsMin - b.tsMin);
    // 同小时只保留最后一个采样点
    const hours: number[] = [];
    const lastOfHour = new Map<number, IntradaySample>();
    for (const s of sorted) {
      const hour = ConsoleIntraday.hourOf(s.tsMin);
      if (!lastOfHour.has(hour)) {
        hours.push(hour);
      }
      lastOfHour.set(hour, s);
    }
    hours.sort((a, b) => a - b);
    const out: TrendPoint[] = [];
    let prevInput = 0;
    let prevOutput = 0;
    for (let i = 0; i < hours.length; i++) {
      const hour = hours[i];
      const cur = lastOfHour.get(hour) as IntradaySample;
      // 第一个小时直接取累计，其余取与上一小时累计的差（负值兜底为 0，防接口口径回退）
      const baseIn = i === 0 ? 0 : prevInput;
      const baseOut = i === 0 ? 0 : prevOutput;
      out.push({
        hour: `${hour}`.padStart(2, '0') + ':00',
        input: Math.max(0, cur.input - baseIn),
        output: Math.max(0, cur.output - baseOut),
        // 官方聚合接口不提供推理 Token，恒为 0
        reasoning: 0,
      });
      prevInput = cur.input;
      prevOutput = cur.output;
    }
    return out;
  }
}
