import { systemDateTime } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UnderstandingErrorCategory } from '../models/StructuredUnderstandingModels';
import {
  UnderstandingClock,
  UnderstandingMetricsLogger,
  UnderstandingTemporalContext
} from './ScreenshotUnderstandingPorts';

const LOG_DOMAIN: number = 0x5347;
const LOG_TAG: string = 'Understanding';

export class HarmonyUnderstandingClock implements UnderstandingClock {
  capture(): UnderstandingTemporalContext {
    const now: Date = new Date();
    return {
      currentLocalTime: formatLocalIso8601(now),
      timeZoneId: systemDateTime.getTimezoneSync()
    };
  }
}

export class HarmonyUnderstandingMetricsLogger implements UnderstandingMetricsLogger {
  recordThumbnail(width: number, height: number, encodedByteCount: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'thumbnail width=%{public}d height=%{public}d encodedBytes=%{public}d',
      width, height, encodedByteCount);
  }

  recordSuccess(requestCount: number, elapsedMs: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'understanding requests=%{public}d elapsedMs=%{public}d', requestCount, elapsedMs);
  }

  recordError(requestCount: number, elapsedMs: number, category: UnderstandingErrorCategory): void {
    hilog.error(LOG_DOMAIN, LOG_TAG,
      'understanding requests=%{public}d elapsedMs=%{public}d category=%{public}s',
      requestCount, elapsedMs, category);
  }
}

export function formatLocalIso8601(value: Date): string {
  const offsetMinutes: number = value.getTimezoneOffset();
  const sign: string = offsetMinutes <= 0 ? '+' : '-';
  const absoluteOffset: number = Math.abs(offsetMinutes);
  const offsetHours: number = Math.floor(absoluteOffset / 60);
  const offsetRemainder: number = absoluteOffset % 60;
  return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}` +
    `T${pad(value.getHours())}:${pad(value.getMinutes())}:${pad(value.getSeconds())}` +
    `${sign}${pad(offsetHours)}:${pad(offsetRemainder)}`;
}

function pad(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
