import { PrivateImageDescriptor } from '../models/ScreenshotImportModels';
import {
  ThumbnailDescriptor,
  UnderstandingErrorCategory
} from '../models/StructuredUnderstandingModels';

export interface ThumbnailPayload {
  descriptor: ThumbnailDescriptor;
  dataURL: string;
}

export interface ThumbnailGenerator {
  generate(source: PrivateImageDescriptor): Promise<ThumbnailPayload>;
}

export interface UnderstandingTemporalContext {
  currentLocalTime: string;
  timeZoneId: string;
}

export interface UnderstandingClock {
  capture(): UnderstandingTemporalContext;
}

export interface UnderstandingMetricsLogger {
  recordThumbnail(width: number, height: number, encodedByteCount: number): void;
  recordSuccess(requestCount: number, elapsedMs: number): void;
  recordError(requestCount: number, elapsedMs: number, category: UnderstandingErrorCategory): void;
}
