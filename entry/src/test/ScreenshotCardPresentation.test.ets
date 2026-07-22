import { describe, expect, it } from '@ohos/hypium';
import { ScreenshotCard } from '../main/ets/models/ScreenshotCardModels';
import {
  ParseStatus,
  ScreenshotType,
  SuggestedAction
} from '../main/ets/models/StructuredUnderstandingModels';
import {
  buildTimelineSections,
  CardBadgeTone,
  formatCreatedAt,
  formatScreenshotTitle,
  formatScreenshotTypeLabel,
  TimelineSectionViewData
} from '../main/ets/models/ScreenshotCardPresentation';

export default function screenshotCardPresentationTest() {
  describe('ScreenshotCardPresentation', () => {
    it('gives every supported screenshot type a stable Chinese label and title', 0, () => {
      expect(formatScreenshotTypeLabel(ScreenshotType.POSTER)).assertEqual('讲座海报');
      expect(formatScreenshotTitle(ScreenshotType.POSTER)).assertEqual('讲座海报');
      expect(formatScreenshotTypeLabel(ScreenshotType.PICKUP_CODE)).assertEqual('取件码');
      expect(formatScreenshotTitle(ScreenshotType.PICKUP_CODE)).assertEqual('待取快递');
      expect(formatScreenshotTypeLabel(ScreenshotType.DDL_NOTICE)).assertEqual('DDL 通知');
      expect(formatScreenshotTitle(ScreenshotType.DDL_NOTICE)).assertEqual('截止事项');
      expect(formatScreenshotTypeLabel(ScreenshotType.COUPON)).assertEqual('优惠券');
      expect(formatScreenshotTitle(ScreenshotType.COUPON)).assertEqual('优惠券');
      expect(formatScreenshotTypeLabel(ScreenshotType.UNCATEGORIZED)).assertEqual('未分类');
      expect(formatScreenshotTitle(ScreenshotType.UNCATEGORIZED)).assertEqual('未分类截图');
    });

    it('turns a stored pickup card into one render-ready timeline section', 0, () => {
      const card: ScreenshotCard = makeCard(
        'pickup-1',
        ScreenshotType.PICKUP_CODE,
        '2026-07-23T10:30:00+08:00',
        1784649600000,
        '7月23日前',
        '东门菜鸟驿站',
        '3-1-6052',
        null,
        [SuggestedAction.COPY_CODE, SuggestedAction.REMIND]
      );

      const sections: TimelineSectionViewData[] = buildTimelineSections([card], -480);

      expect(sections.length).assertEqual(1);
      expect(sections[0].key).assertEqual('event:2026-07-23');
      expect(sections[0].label).assertEqual('7 月 23 日');
      expect(sections[0].cards.length).assertEqual(1);
      expect(sections[0].cards[0].id).assertEqual('pickup-1');
      expect(sections[0].cards[0].title).assertEqual('待取快递');
      expect(sections[0].cards[0].typeLabel).assertEqual('取件码');
      expect(sections[0].cards[0].badgeTone).assertEqual(CardBadgeTone.FOREST);
      expect(sections[0].cards[0].entityLines.join('|'))
        .assertEqual('时间 · 7月23日前|地点 · 东门菜鸟驿站|码号 · 3-1-6052');
      expect(sections[0].cards[0].actionText).assertEqual('复制码 · 提醒');
      expect(sections[0].cards[0].parseStatusLabel).assertEqual('已解析');
    });

    it('places an undated fallback card last with its import date and no invented entities', 0, () => {
      const card: ScreenshotCard = makeCard(
        'fallback-1',
        ScreenshotType.UNCATEGORIZED,
        null,
        1784607300000,
        null,
        null,
        null,
        null,
        [],
        ParseStatus.FALLBACK_INVALID_RESPONSE
      );

      const sections: TimelineSectionViewData[] = buildTimelineSections([card], -480);

      expect(sections[0].key).assertEqual('undated');
      expect(sections[0].label).assertEqual('未识别事件时间');
      expect(sections[0].cards[0].entityLines.join('|')).assertEqual('导入 · 2026年7月21日');
      expect(sections[0].cards[0].actionText).assertEqual('');
      expect(sections[0].cards[0].parseStatusLabel).assertEqual('安全回退');
    });

    it('formats a stored creation instant in the device timezone for card details', 0, () => {
      expect(formatCreatedAt(1784607300000, -480)).assertEqual('2026年7月21日 12:15');
    });

    it('preserves repository order while grouping an event across a timezone date boundary', 0, () => {
      const cards: ScreenshotCard[] = [
        makeCard('late-poster', ScreenshotType.POSTER, '2026-07-21T23:30:00Z', 1,
          null, null, null, null, []),
        makeCard('earlier-coupon', ScreenshotType.COUPON, '2026-07-20T20:00:00Z', 2,
          null, null, null, '20 元', []),
        makeCard('undated', ScreenshotType.UNCATEGORIZED, null, 1784607300000,
          null, null, null, null, [])
      ];

      const sections: TimelineSectionViewData[] = buildTimelineSections(cards, -480);

      expect(sections.map((section: TimelineSectionViewData): string => section.key).join('|'))
        .assertEqual('event:2026-07-22|event:2026-07-21|undated');
      expect(sections.map((section: TimelineSectionViewData): string => section.cards[0].id).join('|'))
        .assertEqual('late-poster|earlier-coupon|undated');
    });

    it('assigns the approved badge tones to all card families', 0, () => {
      const cards: ScreenshotCard[] = [
        makeCard('poster', ScreenshotType.POSTER, null, 1, null, null, null, null, []),
        makeCard('pickup', ScreenshotType.PICKUP_CODE, null, 2, null, null, null, null, []),
        makeCard('ddl', ScreenshotType.DDL_NOTICE, null, 3, null, null, null, null, []),
        makeCard('coupon', ScreenshotType.COUPON, null, 4, null, null, null, null, []),
        makeCard('uncategorized', ScreenshotType.UNCATEGORIZED, null, 5, null, null, null, null, [])
      ];

      const tones: string = buildTimelineSections(cards, 0)[0].cards
        .map((card): string => card.badgeTone).join('|');

      expect(tones).assertEqual('CLAY|FOREST|AMBER|CLAY|MUTED');
    });
  });
}

function makeCard(id: string, type: ScreenshotType, eventTime: string | null, createdAt: number,
  timeText: string | null, location: string | null, code: string | null, amount: string | null,
  actions: SuggestedAction[], parseStatus: ParseStatus = ParseStatus.PARSED): ScreenshotCard {
  return {
    id: id,
    imageUri: `file:///${id}.png`,
    thumbnailUri: `file:///${id}-thumb.jpg`,
    type: type,
    entities: {
      timeText: timeText,
      eventTime: eventTime,
      location: location,
      code: code,
      amount: amount
    },
    actions: actions,
    parseStatus: parseStatus,
    createdAt: createdAt,
    eventTime: eventTime
  };
}
