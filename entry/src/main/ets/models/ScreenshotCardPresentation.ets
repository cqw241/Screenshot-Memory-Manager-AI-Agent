import { ScreenshotCard } from './ScreenshotCardModels';
import {
  ParseStatus,
  ScreenshotType,
  SuggestedAction
} from './StructuredUnderstandingModels';

export enum CardBadgeTone {
  FOREST = 'FOREST',
  CLAY = 'CLAY',
  AMBER = 'AMBER',
  MUTED = 'MUTED'
}

export interface TimelineCardViewData {
  id: string;
  thumbnailUri: string;
  typeLabel: string;
  title: string;
  badgeTone: CardBadgeTone;
  entityLines: string[];
  actionText: string;
  parseStatusLabel: string;
}

export interface TimelineSectionViewData {
  key: string;
  label: string;
  cards: TimelineCardViewData[];
}

export function formatScreenshotTypeLabel(type: ScreenshotType): string {
  switch (type) {
    case ScreenshotType.POSTER:
      return '讲座海报';
    case ScreenshotType.PICKUP_CODE:
      return '取件码';
    case ScreenshotType.DDL_NOTICE:
      return 'DDL 通知';
    case ScreenshotType.COUPON:
      return '优惠券';
    case ScreenshotType.UNCATEGORIZED:
      return '未分类';
  }
}

export function formatScreenshotTitle(type: ScreenshotType): string {
  switch (type) {
    case ScreenshotType.POSTER:
      return '讲座海报';
    case ScreenshotType.PICKUP_CODE:
      return '待取快递';
    case ScreenshotType.DDL_NOTICE:
      return '截止事项';
    case ScreenshotType.COUPON:
      return '优惠券';
    case ScreenshotType.UNCATEGORIZED:
      return '未分类截图';
  }
}

export function formatSuggestedActions(actions: SuggestedAction[]): string {
  return actions.map((action: SuggestedAction): string => formatSuggestedAction(action)).join(' · ');
}

export function formatParseStatus(status: ParseStatus): string {
  return status === ParseStatus.PARSED ? '已解析' : '安全回退';
}

export function formatCreatedAt(timestamp: number, timezoneOffsetMinutes?: number): string {
  const offset: number = timezoneOffsetMinutes === undefined ? new Date(timestamp).getTimezoneOffset() :
    timezoneOffsetMinutes;
  const localDate: Date = new Date(timestamp - offset * 60 * 1000);
  return `${localDate.getUTCFullYear()}年${localDate.getUTCMonth() + 1}月${localDate.getUTCDate()}日 ` +
    `${twoDigits(localDate.getUTCHours())}:${twoDigits(localDate.getUTCMinutes())}`;
}

export function buildTimelineSections(cards: ScreenshotCard[],
  timezoneOffsetMinutes?: number): TimelineSectionViewData[] {
  const sections: TimelineSectionViewData[] = [];
  for (const card of cards) {
    const group: TimelineGroup = timelineGroup(card, timezoneOffsetMinutes);
    const viewData: TimelineCardViewData = timelineCard(card, timezoneOffsetMinutes);
    const last: TimelineSectionViewData | undefined = sections.length === 0 ? undefined : sections[sections.length - 1];
    if (last !== undefined && last.key === group.key) {
      last.cards.push(viewData);
    } else {
      sections.push({
        key: group.key,
        label: group.label,
        cards: [viewData]
      });
    }
  }
  return sections;
}

interface TimelineGroup {
  key: string;
  label: string;
}

function timelineCard(card: ScreenshotCard, timezoneOffsetMinutes?: number): TimelineCardViewData {
  const lines: string[] = [];
  appendEntityLine(lines, '时间', card.entities.timeText);
  appendEntityLine(lines, '地点', card.entities.location);
  appendEntityLine(lines, '码号', card.entities.code);
  appendEntityLine(lines, '金额', card.entities.amount);
  if (card.eventTime === null) {
    lines.push(`导入 · ${formatLocalDate(card.createdAt, timezoneOffsetMinutes)}`);
  }
  return {
    id: card.id,
    thumbnailUri: card.thumbnailUri,
    typeLabel: formatScreenshotTypeLabel(card.type),
    title: formatScreenshotTitle(card.type),
    badgeTone: formatCardBadgeTone(card.type),
    entityLines: lines,
    actionText: formatSuggestedActions(card.actions),
    parseStatusLabel: formatParseStatus(card.parseStatus)
  };
}

function formatLocalDate(timestamp: number, timezoneOffsetMinutes?: number): string {
  const offset: number = timezoneOffsetMinutes === undefined ? new Date(timestamp).getTimezoneOffset() :
    timezoneOffsetMinutes;
  const localDate: Date = new Date(timestamp - offset * 60 * 1000);
  return `${localDate.getUTCFullYear()}年${localDate.getUTCMonth() + 1}月${localDate.getUTCDate()}日`;
}

function timelineGroup(card: ScreenshotCard, timezoneOffsetMinutes?: number): TimelineGroup {
  if (card.eventTime === null) {
    return {
      key: 'undated',
      label: '未识别事件时间'
    };
  }
  const timestamp: number = Date.parse(card.eventTime);
  const offset: number = timezoneOffsetMinutes === undefined ? new Date(timestamp).getTimezoneOffset() :
    timezoneOffsetMinutes;
  const localDate: Date = new Date(timestamp - offset * 60 * 1000);
  const year: number = localDate.getUTCFullYear();
  const month: number = localDate.getUTCMonth() + 1;
  const day: number = localDate.getUTCDate();
  return {
    key: `event:${year}-${twoDigits(month)}-${twoDigits(day)}`,
    label: `${month} 月 ${day} 日`
  };
}

function appendEntityLine(lines: string[], label: string, value: string | null): void {
  if (value !== null && value.length > 0) {
    lines.push(`${label} · ${value}`);
  }
}

function formatSuggestedAction(action: SuggestedAction): string {
  switch (action) {
    case SuggestedAction.REMIND:
      return '提醒';
    case SuggestedAction.NAVIGATE:
      return '导航';
    case SuggestedAction.COPY_CODE:
      return '复制码';
    case SuggestedAction.ADD_CALENDAR:
      return '写入日程';
  }
}

export function formatCardBadgeTone(type: ScreenshotType): CardBadgeTone {
  switch (type) {
    case ScreenshotType.POSTER:
    case ScreenshotType.COUPON:
      return CardBadgeTone.CLAY;
    case ScreenshotType.PICKUP_CODE:
      return CardBadgeTone.FOREST;
    case ScreenshotType.DDL_NOTICE:
      return CardBadgeTone.AMBER;
    case ScreenshotType.UNCATEGORIZED:
      return CardBadgeTone.MUTED;
  }
}

function twoDigits(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
