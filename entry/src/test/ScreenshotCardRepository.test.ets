import { describe, expect, it } from '@ohos/hypium';
import {
  CardStorageError,
  CardStorageErrorCategory,
  CreateScreenshotCardInput,
  ScreenshotCard
} from '../main/ets/models/ScreenshotCardModels';
import { PrivateImageDescriptor } from '../main/ets/models/ScreenshotImportModels';
import {
  ParseStatus,
  ScreenshotType,
  StructuredUnderstanding,
  SuggestedAction,
  UnderstandingOutcome
} from '../main/ets/models/StructuredUnderstandingModels';
import {
  CardClock,
  CardRow,
  CardRowStore,
  CardUnderstandingRowUpdate,
  eventTimeToEpochMilliseconds,
  ScreenshotCardRepository
} from '../main/ets/services/ScreenshotCardRepository';

const CREATED_AT: number = 1784649600000;

class FakeCardClock implements CardClock {
  private readonly value: number;

  constructor(value: number = CREATED_AT) {
    this.value = value;
  }

  now(): number {
    return this.value;
  }
}

class InMemoryCardRowStore implements CardRowStore {
  readonly rows: Map<string, CardRow> = new Map<string, CardRow>();
  failMessage: string = '';
  insertCount: number = 0;
  deleteCount: number = 0;

  async insert(row: CardRow): Promise<void> {
    this.failIfRequested();
    this.insertCount += 1;
    if (this.rows.has(row.id)) {
      throw new Error('duplicate');
    }
    this.rows.set(row.id, cloneRow(row));
  }

  async findById(id: string): Promise<CardRow | undefined> {
    this.failIfRequested();
    const row: CardRow | undefined = this.rows.get(id);
    return row === undefined ? undefined : cloneRow(row);
  }

  async updateUnderstanding(id: string, update: CardUnderstandingRowUpdate): Promise<boolean> {
    this.failIfRequested();
    const row: CardRow | undefined = this.rows.get(id);
    if (row === undefined) {
      return false;
    }
    this.rows.set(id, {
      id: row.id,
      imageUri: row.imageUri,
      thumbnailUri: row.thumbnailUri,
      type: update.type,
      entitiesJson: update.entitiesJson,
      actionsJson: update.actionsJson,
      status: update.status,
      createdAtMs: row.createdAtMs,
      eventTimeMs: update.eventTimeMs
    });
    return true;
  }

  async deleteById(id: string): Promise<boolean> {
    this.failIfRequested();
    const removed: boolean = this.rows.delete(id);
    if (removed) {
      this.deleteCount += 1;
    }
    return removed;
  }

  async listTimeline(): Promise<CardRow[]> {
    this.failIfRequested();
    const rows: CardRow[] = [];
    this.rows.forEach((row: CardRow): void => {
      rows.push(cloneRow(row));
    });
    rows.sort((left: CardRow, right: CardRow): number => {
      if (left.eventTimeMs !== right.eventTimeMs) {
        if (left.eventTimeMs === null) {
          return 1;
        }
        if (right.eventTimeMs === null) {
          return -1;
        }
        return right.eventTimeMs - left.eventTimeMs;
      }
      if (left.createdAtMs !== right.createdAtMs) {
        return right.createdAtMs - left.createdAtMs;
      }
      return right.id.localeCompare(left.id);
    });
    return rows;
  }

  private failIfRequested(): void {
    if (this.failMessage.length > 0) {
      throw new Error(this.failMessage);
    }
  }
}

function cloneRow(row: CardRow): CardRow {
  return {
    id: row.id,
    imageUri: row.imageUri,
    thumbnailUri: row.thumbnailUri,
    type: row.type,
    entitiesJson: row.entitiesJson,
    actionsJson: row.actionsJson,
    status: row.status,
    createdAtMs: row.createdAtMs,
    eventTimeMs: row.eventTimeMs
  };
}

function understanding(type: ScreenshotType = ScreenshotType.POSTER,
  eventTime: string | null = '2026-07-25T14:00:00+08:00'): StructuredUnderstanding {
  return {
    type: type,
    entities: {
      timeText: eventTime === null ? null : '7月25日 14:00',
      eventTime: eventTime,
      location: '图书馆报告厅',
      code: null,
      amount: null
    },
    actions: [SuggestedAction.REMIND, SuggestedAction.NAVIGATE],
    parseStatus: ParseStatus.PARSED
  };
}

function fallbackUnderstanding(): StructuredUnderstanding {
  return {
    type: ScreenshotType.UNCATEGORIZED,
    entities: { timeText: null, eventTime: null, location: null, code: null, amount: null },
    actions: [],
    parseStatus: ParseStatus.FALLBACK_INVALID_RESPONSE
  };
}

function input(id: string = 'card-id', value: StructuredUnderstanding = understanding()): CreateScreenshotCardInput {
  const image: PrivateImageDescriptor = {
    id: id,
    uri: `file:///private/imports/${id}.png`,
    path: `/private/imports/${id}.png`,
    mimeType: 'image/png',
    width: 1080,
    height: 1600,
    byteCount: 72158
  };
  const outcome: UnderstandingOutcome = {
    thumbnail: {
      uri: `file:///private/thumbnails/${id}.jpg`,
      path: `/private/thumbnails/${id}.jpg`,
      mimeType: 'image/jpeg',
      width: 691,
      height: 1024,
      byteCount: 12345
    },
    understanding: value
  };
  return { image: image, outcome: outcome };
}

function repository(rows: InMemoryCardRowStore, createdAt: number = CREATED_AT): ScreenshotCardRepository {
  return new ScreenshotCardRepository(rows, new FakeCardClock(createdAt));
}

function requireStorageError(error: Object): CardStorageError {
  expect(error instanceof CardStorageError).assertTrue();
  return error as CardStorageError;
}

export default function screenshotCardRepositoryTest() {
  describe('ScreenshotCardRepository', () => {
    it('creates and reads a complete card without OCR or payload data', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      const cards: ScreenshotCardRepository = repository(rows);
      const created: ScreenshotCard = await cards.create(input());
      const loaded: ScreenshotCard | undefined = await cards.getById('card-id');

      expect(created.id).assertEqual('card-id');
      expect(created.createdAt).assertEqual(CREATED_AT);
      expect(created.eventTime).assertEqual('2026-07-25T14:00:00+08:00');
      expect(created.actions.length).assertEqual(2);
      expect(loaded?.thumbnailUri).assertEqual('file:///private/thumbnails/card-id.jpg');
      const stored: string = JSON.stringify(rows.rows.get('card-id'));
      expect(stored.includes('OCR')).assertFalse();
      expect(stored.includes('base64')).assertFalse();
      expect(stored.includes('apiKey')).assertFalse();
    });

    it('stores the exact fallback card with nullable entities', 0, async () => {
      const cards: ScreenshotCardRepository = repository(new InMemoryCardRowStore());
      const card: ScreenshotCard = await cards.create(input('fallback', fallbackUnderstanding()));

      expect(card.type).assertEqual(ScreenshotType.UNCATEGORIZED);
      expect(card.parseStatus).assertEqual(ParseStatus.FALLBACK_INVALID_RESPONSE);
      expect(card.eventTime === null).assertTrue();
      expect(card.actions.length).assertEqual(0);
      expect(card.entities.location === null).assertTrue();
    });

    it('rejects duplicate ids with a sanitized write error', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      const cards: ScreenshotCardRepository = repository(rows);
      await cards.create(input());
      try {
        await cards.create(input());
        expect(false).assertTrue();
      } catch (error) {
        const storageError: CardStorageError = requireStorageError(error as Object);
        expect(storageError.category).assertEqual(CardStorageErrorCategory.WRITE);
        expect(storageError.message.includes('/private/')).assertFalse();
      }
    });

    it('updates only understanding fields and keeps identity images and creation time immutable', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      const cards: ScreenshotCardRepository = repository(rows);
      const original: ScreenshotCard = await cards.create(input());
      const replacement: StructuredUnderstanding = understanding(ScreenshotType.PICKUP_CODE,
        '2026-07-24T22:00:00Z');
      replacement.entities.code = 'A1B2';
      replacement.actions = [SuggestedAction.COPY_CODE];
      const updated: ScreenshotCard = await cards.updateUnderstanding('card-id', replacement);

      expect(updated.type).assertEqual(ScreenshotType.PICKUP_CODE);
      expect(updated.entities.code).assertEqual('A1B2');
      expect(updated.imageUri).assertEqual(original.imageUri);
      expect(updated.thumbnailUri).assertEqual(original.thumbnailUri);
      expect(updated.createdAt).assertEqual(original.createdAt);
    });

    it('returns not found and reports missing updates without creating rows', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      const cards: ScreenshotCardRepository = repository(rows);
      expect((await cards.getById('missing')) === undefined).assertTrue();
      expect(await cards.deleteById('missing')).assertFalse();
      try {
        await cards.updateUnderstanding('missing', understanding());
        expect(false).assertTrue();
      } catch (error) {
        expect(requireStorageError(error as Object).category).assertEqual(CardStorageErrorCategory.WRITE);
      }
      expect(rows.rows.size).assertEqual(0);
    });

    it('deletes only the card row and has no file deletion side effect', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      const cards: ScreenshotCardRepository = repository(rows);
      const card: ScreenshotCard = await cards.create(input());
      const imageUri: string = card.imageUri;
      const thumbnailUri: string = card.thumbnailUri;

      expect(await cards.deleteById(card.id)).assertTrue();
      expect(rows.deleteCount).assertEqual(1);
      expect((await cards.getById(card.id)) === undefined).assertTrue();
      expect(imageUri).assertEqual('file:///private/imports/card-id.png');
      expect(thumbnailUri).assertEqual('file:///private/thumbnails/card-id.jpg');
    });

    it('converts equivalent cross-timezone instants to the same epoch', 0, () => {
      expect(eventTimeToEpochMilliseconds('2026-07-25T14:00:00+08:00'))
        .assertEqual(eventTimeToEpochMilliseconds('2026-07-25T06:00:00Z'));
    });

    it('orders timeline by event time then creation time then id with null events last', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      await repository(rows, 100).create(input('event-old', understanding(ScreenshotType.POSTER,
        '2026-07-24T12:00:00Z')));
      await repository(rows, 200).create(input('null-new', understanding(ScreenshotType.COUPON, null)));
      await repository(rows, 300).create(input('event-new-a', understanding(ScreenshotType.DDL_NOTICE,
        '2026-07-25T12:00:00Z')));
      await repository(rows, 300).create(input('event-new-b', understanding(ScreenshotType.DDL_NOTICE,
        '2026-07-25T12:00:00Z')));
      const timeline: ScreenshotCard[] = await repository(rows).listTimeline();

      expect(timeline.map((card: ScreenshotCard): string => card.id).join(','))
        .assertEqual('event-new-b,event-new-a,event-old,null-new');
    });

    it('rejects corrupt json enums event indexes and invalid input without exposing values', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      rows.rows.set('bad-json', {
        id: 'bad-json', imageUri: 'file:///private/imports/secret.png',
        thumbnailUri: 'file:///private/thumbnails/secret.jpg', type: ScreenshotType.POSTER,
        entitiesJson: '{broken', actionsJson: '[]', status: ParseStatus.PARSED,
        createdAtMs: CREATED_AT, eventTimeMs: null
      });
      try {
        await repository(rows).getById('bad-json');
        expect(false).assertTrue();
      } catch (error) {
        const storageError: CardStorageError = requireStorageError(error as Object);
        expect(storageError.category).assertEqual(CardStorageErrorCategory.CORRUPT);
        expect(storageError.message.includes('secret')).assertFalse();
      }

      const invalid: StructuredUnderstanding = understanding();
      invalid.type = 'UNKNOWN' as ScreenshotType;
      try {
        await repository(rows).create(input('invalid', invalid));
        expect(false).assertTrue();
      } catch (error) {
        expect(requireStorageError(error as Object).category).assertEqual(CardStorageErrorCategory.CORRUPT);
      }
    });

    it('rejects unknown actions invalid event times and mismatched indexed instants', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      const cards: ScreenshotCardRepository = repository(rows);
      await cards.create(input());
      const original: CardRow = rows.rows.get('card-id') as CardRow;

      const unknownAction: CardRow = cloneRow(original);
      unknownAction.id = 'unknown-action';
      unknownAction.actionsJson = '["UNKNOWN"]';
      rows.rows.set('unknown-action', unknownAction);
      const invalidTime: CardRow = cloneRow(original);
      invalidTime.id = 'invalid-time';
      invalidTime.entitiesJson = invalidTime.entitiesJson.replace('+08:00', '');
      rows.rows.set('invalid-time', invalidTime);
      const mismatchedIndex: CardRow = cloneRow(original);
      mismatchedIndex.id = 'mismatched-index';
      mismatchedIndex.eventTimeMs = (mismatchedIndex.eventTimeMs as number) + 1;
      rows.rows.set('mismatched-index', mismatchedIndex);

      for (const id of ['unknown-action', 'invalid-time', 'mismatched-index']) {
        try {
          await cards.getById(id);
          expect(false).assertTrue();
        } catch (error) {
          expect(requireStorageError(error as Object).category).assertEqual(CardStorageErrorCategory.CORRUPT);
        }
      }
    });

    it('normalizes adapter failures and never returns row payloads in errors', 0, async () => {
      const rows: InMemoryCardRowStore = new InMemoryCardRowStore();
      rows.failMessage = 'file:///private/imports/secret.png code=1234';
      try {
        await repository(rows).listTimeline();
        expect(false).assertTrue();
      } catch (error) {
        const storageError: CardStorageError = requireStorageError(error as Object);
        expect(storageError.category).assertEqual(CardStorageErrorCategory.READ);
        expect(storageError.message.includes('secret')).assertFalse();
        expect(storageError.message.includes('1234')).assertFalse();
      }
    });
  });
}
