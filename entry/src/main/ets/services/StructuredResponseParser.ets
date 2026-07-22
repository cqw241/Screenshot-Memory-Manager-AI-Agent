import {
  ParseStatus,
  ScreenshotType,
  StructuredEntities,
  StructuredUnderstanding,
  SuggestedAction
} from '../models/StructuredUnderstandingModels';

interface EntitiesCandidate {
  timeText?: string | null;
  eventTime?: string | null;
  location?: string | null;
  code?: string | null;
  amount?: string | null;
}

interface ResponseCandidate {
  type?: string;
  entities?: EntitiesCandidate;
  actions?: string[];
}

export class InvalidStructuredContentError extends Error {
  constructor() {
    super('invalid structured content');
    this.name = 'InvalidStructuredContentError';
  }
}

const ROOT_KEYS: string[] = ['actions', 'entities', 'type'];
const ENTITY_KEYS: string[] = ['amount', 'code', 'eventTime', 'location', 'timeText'];

export function parseStructuredContent(raw: string): StructuredUnderstanding {
  const trimmed: string = raw.trim();
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}') || trimmed.includes('```')) {
    throw new InvalidStructuredContentError();
  }

  let parsed: Object;
  try {
    parsed = JSON.parse(trimmed) as Object;
  } catch (_error) {
    throw new InvalidStructuredContentError();
  }
  if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object' ||
    !hasExactKeys(parsed, ROOT_KEYS)) {
    throw new InvalidStructuredContentError();
  }

  const candidate: ResponseCandidate = parsed as ResponseCandidate;
  if (!isScreenshotType(candidate.type) || candidate.entities === undefined || candidate.entities === null ||
    typeof candidate.entities !== 'object' || Array.isArray(candidate.entities) ||
    !hasExactKeys(candidate.entities as Object, ENTITY_KEYS) || !Array.isArray(candidate.actions)) {
    throw new InvalidStructuredContentError();
  }

  const entities: EntitiesCandidate = candidate.entities;
  if (!isNullableString(entities.timeText) || !isNullableString(entities.eventTime) ||
    !isNullableString(entities.location) || !isNullableString(entities.code) ||
    !isNullableString(entities.amount) ||
    (entities.eventTime !== null && (!isIso8601WithTimezone(entities.eventTime as string) ||
      entities.timeText === null || !matchesEventTimeEvidence(entities.timeText as string,
        entities.eventTime as string)))) {
    throw new InvalidStructuredContentError();
  }

  const actions: SuggestedAction[] = [];
  for (const action of candidate.actions) {
    if (!isSuggestedAction(action)) {
      throw new InvalidStructuredContentError();
    }
    actions.push(action as SuggestedAction);
  }

  const structuredEntities: StructuredEntities = {
    timeText: entities.timeText as string | null,
    eventTime: entities.eventTime as string | null,
    location: entities.location as string | null,
    code: entities.code as string | null,
    amount: entities.amount as string | null
  };
  return {
    type: candidate.type as ScreenshotType,
    entities: structuredEntities,
    actions: actions,
    parseStatus: ParseStatus.PARSED
  };
}

export function fallbackInvalidResponse(): StructuredUnderstanding {
  return {
    type: ScreenshotType.UNCATEGORIZED,
    entities: {
      timeText: null,
      eventTime: null,
      location: null,
      code: null,
      amount: null
    },
    actions: [],
    parseStatus: ParseStatus.FALLBACK_INVALID_RESPONSE
  };
}

export function isIso8601WithTimezone(value: string): boolean {
  const match: RegExpExecArray | null =
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?(Z|([+-])(\d{2}):(\d{2}))$/.exec(value);
  if (match === null) {
    return false;
  }

  const year: number = Number.parseInt(match[1], 10);
  const month: number = Number.parseInt(match[2], 10);
  const day: number = Number.parseInt(match[3], 10);
  const hour: number = Number.parseInt(match[4], 10);
  const minute: number = Number.parseInt(match[5], 10);
  const second: number = match[6] === undefined ? 0 : Number.parseInt(match[6], 10);
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month) ||
    hour > 23 || minute > 59 || second > 59) {
    return false;
  }

  if (match[8] !== 'Z') {
    const offsetHour: number = Number.parseInt(match[10], 10);
    const offsetMinute: number = Number.parseInt(match[11], 10);
    if (offsetHour > 14 || offsetMinute > 59 || (offsetHour === 14 && offsetMinute !== 0)) {
      return false;
    }
  }
  return true;
}

function matchesEventTimeEvidence(timeText: string, eventTime: string): boolean {
  const chinese: RegExpExecArray | null =
    /(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日[^\d]*(\d{1,2}):(\d{2})(?::(\d{2}))?/.exec(timeText);
  const numeric: RegExpExecArray | null =
    /(\d{4})\s*([-\/.])\s*(\d{1,2})\s*\2\s*(\d{1,2})[^\d]*(\d{1,2}):(\d{2})(?::(\d{2}))?/.exec(timeText);
  const source: RegExpExecArray | null = chinese ?? numeric;
  if (source === null) {
    return false;
  }

  const event: RegExpExecArray | null =
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?/.exec(eventTime);
  if (event === null) {
    return false;
  }

  const sourceValues: number[] = chinese !== null ? [
    Number.parseInt(source[1], 10), Number.parseInt(source[2], 10), Number.parseInt(source[3], 10),
    Number.parseInt(source[4], 10), Number.parseInt(source[5], 10)
  ] : [
    Number.parseInt(source[1], 10), Number.parseInt(source[3], 10), Number.parseInt(source[4], 10),
    Number.parseInt(source[5], 10), Number.parseInt(source[6], 10)
  ];
  for (let index: number = 0; index < sourceValues.length; index += 1) {
    if (sourceValues[index] !== Number.parseInt(event[index + 1], 10)) {
      return false;
    }
  }

  const sourceSecondText: string | undefined = chinese !== null ? source[6] : source[7];
  const sourceSecond: number = sourceSecondText === undefined ? 0 : Number.parseInt(sourceSecondText, 10);
  const eventSecond: number = event[6] === undefined ? 0 : Number.parseInt(event[6], 10);
  return sourceSecond === eventSecond;
}

function hasExactKeys(value: Object, expected: string[]): boolean {
  const actual: string[] = Object.keys(value).sort();
  if (actual.length !== expected.length) {
    return false;
  }
  for (let index: number = 0; index < expected.length; index += 1) {
    if (actual[index] !== expected[index]) {
      return false;
    }
  }
  return true;
}

function isNullableString(value: string | null | undefined): boolean {
  return value === null || typeof value === 'string';
}

function isScreenshotType(value: string | undefined): boolean {
  return value === ScreenshotType.POSTER || value === ScreenshotType.PICKUP_CODE ||
    value === ScreenshotType.DDL_NOTICE || value === ScreenshotType.COUPON ||
    value === ScreenshotType.UNCATEGORIZED;
}

function isSuggestedAction(value: string): boolean {
  return value === SuggestedAction.REMIND || value === SuggestedAction.NAVIGATE ||
    value === SuggestedAction.COPY_CODE || value === SuggestedAction.ADD_CALENDAR;
}

function daysInMonth(year: number, month: number): number {
  if (month === 2) {
    const leap: boolean = year % 400 === 0 || (year % 4 === 0 && year % 100 !== 0);
    return leap ? 29 : 28;
  }
  if (month === 4 || month === 6 || month === 9 || month === 11) {
    return 30;
  }
  return 31;
}
