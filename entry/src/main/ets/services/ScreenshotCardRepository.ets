import {
  CardStorageError,
  CardStorageErrorCategory,
  CreateScreenshotCardInput,
  ScreenshotCard,
  ScreenshotCardRepositoryPort
} from '../models/ScreenshotCardModels';
import {
  ParseStatus,
  ScreenshotType,
  StructuredEntities,
  StructuredUnderstanding,
  SuggestedAction
} from '../models/StructuredUnderstandingModels';
import { isIso8601WithTimezone } from './StructuredResponseParser';

export interface CardRow {
  id: string;
  imageUri: string;
  thumbnailUri: string;
  type: string;
  entitiesJson: string;
  actionsJson: string;
  status: string;
  createdAtMs: number;
  eventTimeMs: number | null;
}

export interface CardUnderstandingRowUpdate {
  type: string;
  entitiesJson: string;
  actionsJson: string;
  status: string;
  eventTimeMs: number | null;
}

export interface CardRowStore {
  insert(row: CardRow): Promise<void>;
  findById(id: string): Promise<CardRow | undefined>;
  updateUnderstanding(id: string, update: CardUnderstandingRowUpdate): Promise<boolean>;
  deleteById(id: string): Promise<boolean>;
  listTimeline(): Promise<CardRow[]>;
}

export interface CardClock {
  now(): number;
}

export class SystemCardClock implements CardClock {
  now(): number {
    return Date.now();
  }
}

const SCREENSHOT_TYPES: string[] = [
  ScreenshotType.POSTER,
  ScreenshotType.PICKUP_CODE,
  ScreenshotType.DDL_NOTICE,
  ScreenshotType.COUPON,
  ScreenshotType.UNCATEGORIZED
];

const ACTIONS: string[] = [
  SuggestedAction.REMIND,
  SuggestedAction.NAVIGATE,
  SuggestedAction.COPY_CODE,
  SuggestedAction.ADD_CALENDAR
];

const PARSE_STATUSES: string[] = [ParseStatus.PARSED, ParseStatus.FALLBACK_INVALID_RESPONSE];
const ENTITY_KEYS: string[] = ['amount', 'code', 'eventTime', 'location', 'timeText'];

export class ScreenshotCardRepository implements ScreenshotCardRepositoryPort {
  private readonly rows: CardRowStore;
  private readonly clock: CardClock;

  constructor(rows: CardRowStore, clock: CardClock = new SystemCardClock()) {
    this.rows = rows;
    this.clock = clock;
  }

  async create(input: CreateScreenshotCardInput): Promise<ScreenshotCard> {
    try {
      requireNonEmpty(input.image.id);
      requireNonEmpty(input.image.uri);
      requireNonEmpty(input.outcome.thumbnail.uri);
      const understanding: StructuredUnderstanding = validateUnderstanding(input.outcome.understanding);
      const createdAt: number = this.clock.now();
      if (!Number.isSafeInteger(createdAt) || createdAt < 0) {
        throw corruptError();
      }
      const row: CardRow = buildRow(input.image.id, input.image.uri, input.outcome.thumbnail.uri,
        understanding, createdAt);
      await this.rows.insert(row);
      return decodeRow(row);
    } catch (error) {
      throw normalizeError(error, CardStorageErrorCategory.WRITE,
        '卡片未能保存到本机，请稍后重试。');
    }
  }

  async getById(id: string): Promise<ScreenshotCard | undefined> {
    try {
      requireNonEmpty(id);
      const row: CardRow | undefined = await this.rows.findById(id);
      return row === undefined ? undefined : decodeRow(row);
    } catch (error) {
      throw normalizeError(error, CardStorageErrorCategory.READ,
        '暂时无法读取本地卡片。');
    }
  }

  async updateUnderstanding(id: string, understanding: StructuredUnderstanding): Promise<ScreenshotCard> {
    try {
      requireNonEmpty(id);
      const valid: StructuredUnderstanding = validateUnderstanding(understanding);
      const update: CardUnderstandingRowUpdate = encodeUnderstanding(valid);
      if (!await this.rows.updateUnderstanding(id, update)) {
        throw new CardStorageError(CardStorageErrorCategory.WRITE, '没有找到需要更新的卡片。');
      }
      const updated: CardRow | undefined = await this.rows.findById(id);
      if (updated === undefined) {
        throw new CardStorageError(CardStorageErrorCategory.WRITE, '没有找到需要更新的卡片。');
      }
      return decodeRow(updated);
    } catch (error) {
      throw normalizeError(error, CardStorageErrorCategory.WRITE,
        '卡片修改未能保存，请稍后重试。');
    }
  }

  async deleteById(id: string): Promise<boolean> {
    try {
      requireNonEmpty(id);
      return await this.rows.deleteById(id);
    } catch (error) {
      throw normalizeError(error, CardStorageErrorCategory.WRITE,
        '卡片未能删除，请稍后重试。');
    }
  }

  async listTimeline(): Promise<ScreenshotCard[]> {
    try {
      const rows: CardRow[] = await this.rows.listTimeline();
      return rows.map((row: CardRow): ScreenshotCard => decodeRow(row));
    } catch (error) {
      throw normalizeError(error, CardStorageErrorCategory.READ,
        '暂时无法读取本地卡片。');
    }
  }
}

function buildRow(id: string, imageUri: string, thumbnailUri: string, understanding: StructuredUnderstanding,
  createdAtMs: number): CardRow {
  const encoded: CardUnderstandingRowUpdate = encodeUnderstanding(understanding);
  return {
    id: id,
    imageUri: imageUri,
    thumbnailUri: thumbnailUri,
    type: encoded.type,
    entitiesJson: encoded.entitiesJson,
    actionsJson: encoded.actionsJson,
    status: encoded.status,
    createdAtMs: createdAtMs,
    eventTimeMs: encoded.eventTimeMs
  };
}

function encodeUnderstanding(understanding: StructuredUnderstanding): CardUnderstandingRowUpdate {
  const eventTime: string | null = understanding.entities.eventTime;
  return {
    type: understanding.type,
    entitiesJson: JSON.stringify(understanding.entities),
    actionsJson: JSON.stringify(understanding.actions),
    status: understanding.parseStatus,
    eventTimeMs: eventTime === null ? null : eventTimeToEpochMilliseconds(eventTime)
  };
}

export function eventTimeToEpochMilliseconds(value: string): number {
  if (!isIso8601WithTimezone(value)) {
    throw corruptError();
  }
  const parsed: number = Date.parse(value);
  if (!Number.isSafeInteger(parsed)) {
    throw corruptError();
  }
  return parsed;
}

export function decodeRow(row: CardRow): ScreenshotCard {
  requireNonEmpty(row.id);
  requireNonEmpty(row.imageUri);
  requireNonEmpty(row.thumbnailUri);
  if (!Number.isSafeInteger(row.createdAtMs) || row.createdAtMs < 0) {
    throw corruptError();
  }
  if (SCREENSHOT_TYPES.indexOf(row.type) < 0 || PARSE_STATUSES.indexOf(row.status) < 0) {
    throw corruptError();
  }

  const entities: StructuredEntities = decodeEntities(row.entitiesJson);
  const actions: SuggestedAction[] = decodeActions(row.actionsJson);
  const expectedEventTimeMs: number | null = entities.eventTime === null ? null :
    eventTimeToEpochMilliseconds(entities.eventTime);
  if (expectedEventTimeMs !== row.eventTimeMs) {
    throw corruptError();
  }
  return {
    id: row.id,
    imageUri: row.imageUri,
    thumbnailUri: row.thumbnailUri,
    type: row.type as ScreenshotType,
    entities: entities,
    actions: actions,
    parseStatus: row.status as ParseStatus,
    createdAt: row.createdAtMs,
    eventTime: entities.eventTime
  };
}

function validateUnderstanding(value: StructuredUnderstanding): StructuredUnderstanding {
  if (SCREENSHOT_TYPES.indexOf(value.type) < 0 || PARSE_STATUSES.indexOf(value.parseStatus) < 0) {
    throw corruptError();
  }
  const entities: StructuredEntities = decodeEntities(JSON.stringify(value.entities));
  const actions: SuggestedAction[] = decodeActions(JSON.stringify(value.actions));
  return {
    type: value.type,
    entities: entities,
    actions: actions,
    parseStatus: value.parseStatus
  };
}

function decodeEntities(raw: string): StructuredEntities {
  let parsed: Object;
  try {
    parsed = JSON.parse(raw) as Object;
  } catch (_error) {
    throw corruptError();
  }
  if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
    throw corruptError();
  }
  const record: Record<string, Object | null> = parsed as Record<string, Object | null>;
  const keys: string[] = Object.keys(record).sort();
  if (keys.length !== ENTITY_KEYS.length || keys.some((key: string, index: number): boolean =>
    key !== ENTITY_KEYS[index])) {
    throw corruptError();
  }
  requireNullableString(record.timeText);
  requireNullableString(record.eventTime);
  requireNullableString(record.location);
  requireNullableString(record.code);
  requireNullableString(record.amount);
  const eventTime: string | null = record.eventTime as string | null;
  if (eventTime !== null && !isIso8601WithTimezone(eventTime)) {
    throw corruptError();
  }
  return {
    timeText: record.timeText as string | null,
    eventTime: eventTime,
    location: record.location as string | null,
    code: record.code as string | null,
    amount: record.amount as string | null
  };
}

function decodeActions(raw: string): SuggestedAction[] {
  let parsed: Object;
  try {
    parsed = JSON.parse(raw) as Object;
  } catch (_error) {
    throw corruptError();
  }
  if (!Array.isArray(parsed)) {
    throw corruptError();
  }
  const values: Object[] = parsed as Object[];
  if (values.some((value: Object): boolean => typeof value !== 'string' ||
    ACTIONS.indexOf(value as string) < 0)) {
    throw corruptError();
  }
  return values.map((value: Object): SuggestedAction => value as SuggestedAction);
}

function requireNullableString(value: Object | null): void {
  if (value !== null && typeof value !== 'string') {
    throw corruptError();
  }
}

function requireNonEmpty(value: string): void {
  if (value.trim().length === 0) {
    throw corruptError();
  }
}

function corruptError(): CardStorageError {
  return new CardStorageError(CardStorageErrorCategory.CORRUPT,
    '本地卡片数据不完整或格式不兼容。');
}

function normalizeError(error: Object, category: CardStorageErrorCategory, message: string): CardStorageError {
  if (error instanceof CardStorageError) {
    return error;
  }
  return new CardStorageError(category, message);
}
