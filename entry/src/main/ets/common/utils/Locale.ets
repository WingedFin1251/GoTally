// entry/src/main/ets/common/utils/Locale.ets
/** 模块级当前语言（'zh' | 'en'），供纯格式化函数使用，避免到处传参。 */
let currentLanguage: string = 'zh';

export function setLanguage(lang: string): void {
  currentLanguage = lang === 'en' ? 'en' : 'zh';
}

export function getLanguage(): string {
  return currentLanguage;
}

export function isZh(): boolean {
  return currentLanguage === 'zh';
}
