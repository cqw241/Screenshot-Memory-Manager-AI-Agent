export enum CapabilityLevel {
  UNKNOWN = 'UNKNOWN',
  L0 = 'L0',
  L1 = 'L1',
  L2 = 'L2'
}

export interface CapabilityEvidence {
  deliverySignatureVerified: boolean;
  permissionGranted: boolean;
  mediaMatrixComplete: boolean;
  screenshotRuleVerified: boolean;
  foregroundTrials: number;
  foregroundCallbacks: number;
  backgroundResidentTrials: number;
  backgroundResidentCallbacks: number;
  resumeScanTrials: number;
  resumeScanDiscoveries: number;
}

export function evaluateCapability(evidence: CapabilityEvidence): CapabilityLevel {
  if (!evidence.deliverySignatureVerified) {
    return CapabilityLevel.UNKNOWN;
  }
  if (!evidence.permissionGranted) {
    return CapabilityLevel.L0;
  }
  if (!evidence.mediaMatrixComplete) {
    return CapabilityLevel.UNKNOWN;
  }
  if (!evidence.screenshotRuleVerified) {
    return CapabilityLevel.L0;
  }
  if (evidence.foregroundTrials < 3 || evidence.backgroundResidentTrials < 3 ||
    evidence.resumeScanTrials < 1) {
    return CapabilityLevel.UNKNOWN;
  }
  const foregroundReliable: boolean = evidence.foregroundCallbacks === evidence.foregroundTrials;
  const backgroundReliable: boolean = evidence.backgroundResidentCallbacks === evidence.backgroundResidentTrials;
  if (foregroundReliable && backgroundReliable) {
    return CapabilityLevel.L2;
  }
  const resumeReliable: boolean = evidence.resumeScanDiscoveries === evidence.resumeScanTrials;
  return foregroundReliable || resumeReliable ? CapabilityLevel.L1 : CapabilityLevel.L0;
}

export enum ProbeEventKind {
  LIFECYCLE = 'LIFECYCLE',
  PERMISSION = 'PERMISSION',
  MEDIA_CHANGE = 'MEDIA_CHANGE',
  MEDIA_QUERY = 'MEDIA_QUERY',
  NOTIFICATION = 'NOTIFICATION',
  DEEP_LINK = 'DEEP_LINK',
  ERROR = 'ERROR'
}

export interface ProbeEvidenceInput {
  kind: ProbeEventKind;
  recordedAtMs: number;
  detail: string;
  uri?: string;
  identifier?: string;
  albumUri?: string;
  displayName?: string;
  mediaType?: string;
  byteCount?: number;
  dateAddedMs?: number;
  dateTakenMs?: number;
}

export interface ProbeEvidenceEvent {
  kind: ProbeEventKind;
  recordedAtMs: number;
  detail: string;
  uriDigest?: string;
  identifierDigest?: string;
  albumDigest?: string;
  displayNameDigest?: string;
  mediaType?: string;
  byteCount?: number;
  dateAddedMs?: number;
  dateTakenMs?: number;
}

export interface ProbeValueHasher {
  digest(value: string): Promise<string>;
}

export class ProbeEvidenceBuilder {
  private readonly hasher: ProbeValueHasher;

  constructor(hasher: ProbeValueHasher) {
    this.hasher = hasher;
  }

  async build(input: ProbeEvidenceInput): Promise<ProbeEvidenceEvent> {
    const event: ProbeEvidenceEvent = {
      kind: input.kind,
      recordedAtMs: input.recordedAtMs,
      detail: input.detail
    };
    if (input.uri !== undefined && input.uri.length > 0) {
      event.uriDigest = await this.hasher.digest(input.uri);
    }
    if (input.identifier !== undefined && input.identifier.length > 0) {
      event.identifierDigest = await this.hasher.digest(input.identifier);
    }
    if (input.albumUri !== undefined && input.albumUri.length > 0) {
      event.albumDigest = await this.hasher.digest(input.albumUri);
    }
    if (input.displayName !== undefined && input.displayName.length > 0) {
      event.displayNameDigest = await this.hasher.digest(input.displayName);
    }
    if (input.mediaType !== undefined) {
      event.mediaType = input.mediaType;
    }
    if (input.byteCount !== undefined) {
      event.byteCount = input.byteCount;
    }
    if (input.dateAddedMs !== undefined) {
      event.dateAddedMs = input.dateAddedMs;
    }
    if (input.dateTakenMs !== undefined) {
      event.dateTakenMs = input.dateTakenMs;
    }
    return event;
  }
}

const MAX_PROBE_EVENTS: number = 200;
const PROBE_EVENT_KINDS: string[] = [
  ProbeEventKind.LIFECYCLE,
  ProbeEventKind.PERMISSION,
  ProbeEventKind.MEDIA_CHANGE,
  ProbeEventKind.MEDIA_QUERY,
  ProbeEventKind.NOTIFICATION,
  ProbeEventKind.DEEP_LINK,
  ProbeEventKind.ERROR
];

export class ProbeEventLog {
  private readonly events: ProbeEvidenceEvent[];

  private constructor(events: ProbeEvidenceEvent[]) {
    this.events = events;
  }

  static fromJson(raw: string): ProbeEventLog {
    try {
      const parsed: Object = JSON.parse(raw) as Object;
      if (!Array.isArray(parsed)) {
        return new ProbeEventLog([]);
      }
      const values: Object[] = parsed as Object[];
      const events: ProbeEvidenceEvent[] = [];
      values.forEach((value: Object): void => {
        const event: ProbeEvidenceEvent | undefined = decodeProbeEvent(value);
        if (event !== undefined) {
          events.push(event);
        }
      });
      return new ProbeEventLog(events.slice(-MAX_PROBE_EVENTS));
    } catch (_error) {
      return new ProbeEventLog([]);
    }
  }

  append(event: ProbeEvidenceEvent): void {
    const valid: ProbeEvidenceEvent | undefined = decodeProbeEvent(event as Object);
    if (valid === undefined) {
      return;
    }
    this.events.push(valid);
    if (this.events.length > MAX_PROBE_EVENTS) {
      this.events.splice(0, this.events.length - MAX_PROBE_EVENTS);
    }
  }

  list(): ProbeEvidenceEvent[] {
    return this.events.slice();
  }

  toJson(): string {
    return JSON.stringify(this.events);
  }
}

export interface ProbeWantParameters {
  cardId?: Object;
}

export function extractProbeCardId(parameters: ProbeWantParameters | undefined): string {
  if (parameters === undefined) {
    return '';
  }
  const value: Object | undefined = parameters.cardId;
  if (typeof value !== 'string') {
    return '';
  }
  const cardId: string = value.trim();
  return cardId.length > 0 && cardId.length <= 128 ? cardId : '';
}

function decodeProbeEvent(value: Object): ProbeEvidenceEvent | undefined {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    return undefined;
  }
  const record: Record<string, Object | null> = value as Record<string, Object | null>;
  if (typeof record.kind !== 'string' || PROBE_EVENT_KINDS.indexOf(record.kind) < 0 ||
    typeof record.recordedAtMs !== 'number' || !Number.isSafeInteger(record.recordedAtMs) ||
    record.recordedAtMs < 0 || typeof record.detail !== 'string') {
    return undefined;
  }
  const event: ProbeEvidenceEvent = {
    kind: record.kind as ProbeEventKind,
    recordedAtMs: record.recordedAtMs,
    detail: record.detail
  };
  copyOptionalString(record, 'uriDigest', event);
  copyOptionalString(record, 'identifierDigest', event);
  copyOptionalString(record, 'albumDigest', event);
  copyOptionalString(record, 'displayNameDigest', event);
  copyOptionalString(record, 'mediaType', event);
  if (typeof record.byteCount === 'number' && Number.isSafeInteger(record.byteCount) && record.byteCount >= 0) {
    event.byteCount = record.byteCount;
  }
  if (typeof record.dateAddedMs === 'number' && Number.isSafeInteger(record.dateAddedMs) &&
    record.dateAddedMs >= 0) {
    event.dateAddedMs = record.dateAddedMs;
  }
  if (typeof record.dateTakenMs === 'number' && Number.isSafeInteger(record.dateTakenMs) &&
    record.dateTakenMs >= 0) {
    event.dateTakenMs = record.dateTakenMs;
  }
  return event;
}

function copyOptionalString(source: Record<string, Object | null>, key: string,
  target: ProbeEvidenceEvent): void {
  const value: Object | null = source[key];
  if (typeof value !== 'string') {
    return;
  }
  if (key === 'uriDigest') {
    target.uriDigest = value;
  } else if (key === 'identifierDigest') {
    target.identifierDigest = value;
  } else if (key === 'albumDigest') {
    target.albumDigest = value;
  } else if (key === 'displayNameDigest') {
    target.displayNameDigest = value;
  } else if (key === 'mediaType') {
    target.mediaType = value;
  }
}
