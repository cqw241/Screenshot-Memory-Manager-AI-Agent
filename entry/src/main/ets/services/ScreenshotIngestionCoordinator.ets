import {
  CardStorageError,
  ScreenshotCard
} from '../models/ScreenshotCardModels';
import {
  ImportOutcome,
  ImportOutcomeKind,
  OcrStatus,
  ReadyImportOutcome
} from '../models/ScreenshotImportModels';
import {
  ParseStatus,
  UnderstandingError,
  UnderstandingOutcome
} from '../models/StructuredUnderstandingModels';
import {
  ScreenshotCardWriter,
  ScreenshotImporter,
  ScreenshotUnderstander
} from './ScreenshotIngestionPorts';
import { ScreenshotImportLifecycleObserver } from './ScreenshotImportPorts';

export enum IngestionStage {
  WAITING_FOR_SELECTION = 'WAITING_FOR_SELECTION',
  IMPORTING_AND_OCR = 'IMPORTING_AND_OCR',
  UNDERSTANDING = 'UNDERSTANDING',
  SAVING = 'SAVING',
  REFRESHING_TIMELINE = 'REFRESHING_TIMELINE'
}

export enum IngestionResultKind {
  CANCELLED = 'CANCELLED',
  SAVED = 'SAVED',
  FAILED = 'FAILED'
}

export enum IngestionFailureCategory {
  IMPORT = 'IMPORT',
  UNDERSTANDING = 'UNDERSTANDING',
  STORAGE = 'STORAGE',
  BUSY = 'BUSY'
}

export interface IngestionObserver {
  onStage(stage: IngestionStage, ocrStatus?: OcrStatus): void;
}

export interface CancelledIngestionResult {
  kind: IngestionResultKind.CANCELLED;
}

export interface SavedIngestionResult {
  kind: IngestionResultKind.SAVED;
  card: ScreenshotCard;
  ocrStatus: OcrStatus;
  parseStatus: ParseStatus;
}

export interface FailedIngestionResult {
  kind: IngestionResultKind.FAILED;
  ocrStatus?: OcrStatus;
  failureCategory: IngestionFailureCategory;
  errorCategory: string;
  userMessage: string;
}

export type IngestionResult = CancelledIngestionResult | SavedIngestionResult | FailedIngestionResult;

class ImportObserver implements ScreenshotImportLifecycleObserver {
  private readonly observer: IngestionObserver;

  constructor(observer: IngestionObserver) {
    this.observer = observer;
  }

  onSelectionConfirmed(): void {
    this.observer.onStage(IngestionStage.IMPORTING_AND_OCR);
  }
}

export class ScreenshotIngestionCoordinator {
  private readonly importer: ScreenshotImporter;
  private readonly understander: ScreenshotUnderstander;
  private readonly writer: ScreenshotCardWriter;
  private isBusy: boolean = false;

  constructor(importer: ScreenshotImporter, understander: ScreenshotUnderstander, writer: ScreenshotCardWriter) {
    this.importer = importer;
    this.understander = understander;
    this.writer = writer;
  }

  async ingestSingle(observer: IngestionObserver): Promise<IngestionResult> {
    if (this.isBusy) {
      return failed(IngestionFailureCategory.BUSY, '正在处理', '已有一张截图正在处理中，请稍候。');
    }
    this.isBusy = true;
    try {
      return await this.performIngestion(observer);
    } finally {
      this.isBusy = false;
    }
  }

  private async performIngestion(observer: IngestionObserver): Promise<IngestionResult> {
    observer.onStage(IngestionStage.WAITING_FOR_SELECTION);
    let imported: ImportOutcome;
    try {
      imported = await this.importer.importSingle(new ImportObserver(observer));
    } catch (_error) {
      return failed(IngestionFailureCategory.IMPORT, '导入失败', '请确认图片可读取后重试。');
    }
    if (imported.kind === ImportOutcomeKind.CANCELLED) {
      return { kind: IngestionResultKind.CANCELLED };
    }

    const ready: ReadyImportOutcome = imported as ReadyImportOutcome;
    observer.onStage(IngestionStage.UNDERSTANDING, ready.ocrStatus);
    let outcome: UnderstandingOutcome;
    try {
      outcome = await this.understander.understand(ready.image, ready.ocrText);
    } catch (error) {
      if (error instanceof UnderstandingError) {
        return failed(IngestionFailureCategory.UNDERSTANDING, error.category, error.userMessage, ready.ocrStatus);
      }
      return failed(IngestionFailureCategory.UNDERSTANDING, '服务错误',
        '模型理解暂时不可用，请稍后重试。', ready.ocrStatus);
    }

    observer.onStage(IngestionStage.SAVING);
    try {
      const card: ScreenshotCard = await this.writer.create({ image: ready.image, outcome: outcome });
      return {
        kind: IngestionResultKind.SAVED,
        card: card,
        ocrStatus: ready.ocrStatus,
        parseStatus: outcome.understanding.parseStatus
      };
    } catch (error) {
      if (error instanceof CardStorageError) {
        return failed(IngestionFailureCategory.STORAGE, error.category, error.userMessage, ready.ocrStatus);
      }
      return failed(IngestionFailureCategory.STORAGE, '卡片写入失败',
        '卡片未能保存到本机，请稍后重试。', ready.ocrStatus);
    }
  }
}

function failed(category: IngestionFailureCategory, errorCategory: string, userMessage: string,
  ocrStatus?: OcrStatus): FailedIngestionResult {
  return {
    kind: IngestionResultKind.FAILED,
    ocrStatus: ocrStatus,
    failureCategory: category,
    errorCategory: errorCategory,
    userMessage: userMessage
  };
}
