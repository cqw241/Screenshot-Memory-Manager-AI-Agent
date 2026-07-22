import { describe, expect, it } from '@ohos/hypium';
import {
  CardStorageError,
  CardStorageErrorCategory,
  CreateScreenshotCardInput,
  ScreenshotCard
} from '../main/ets/models/ScreenshotCardModels';
import {
  ImportOutcome,
  ImportOutcomeKind,
  OcrStatus,
  PrivateImageDescriptor
} from '../main/ets/models/ScreenshotImportModels';
import {
  ParseStatus,
  ScreenshotType,
  SuggestedAction,
  UnderstandingError,
  UnderstandingErrorCategory,
  UnderstandingOutcome
} from '../main/ets/models/StructuredUnderstandingModels';
import {
  FailedIngestionResult,
  IngestionFailureCategory,
  IngestionObserver,
  IngestionResult,
  IngestionResultKind,
  IngestionStage,
  SavedIngestionResult,
  ScreenshotIngestionCoordinator
} from '../main/ets/services/ScreenshotIngestionCoordinator';
import {
  ScreenshotCardWriter,
  ScreenshotImporter,
  ScreenshotUnderstander
} from '../main/ets/services/ScreenshotIngestionPorts';
import { ScreenshotImportLifecycleObserver } from '../main/ets/services/ScreenshotImportPorts';

const IMAGE: PrivateImageDescriptor = {
  id: 'poster-id',
  uri: 'file:///private/imports/poster.png',
  path: '/private/imports/poster.png',
  mimeType: 'image/png',
  width: 1080,
  height: 1600,
  byteCount: 72158
};

const OUTCOME: UnderstandingOutcome = {
  thumbnail: {
    uri: 'file:///private/thumbnails/poster.jpg',
    path: '/private/thumbnails/poster.jpg',
    mimeType: 'image/jpeg',
    width: 691,
    height: 1024,
    byteCount: 12345
  },
  understanding: {
    type: ScreenshotType.POSTER,
    entities: {
      timeText: '2026年7月25日 14:00',
      eventTime: '2026-07-25T14:00:00+08:00',
      location: '图书馆报告厅',
      code: null,
      amount: null
    },
    actions: [SuggestedAction.REMIND],
    parseStatus: ParseStatus.PARSED
  }
};

const CARD: ScreenshotCard = {
  id: IMAGE.id,
  imageUri: IMAGE.uri,
  thumbnailUri: OUTCOME.thumbnail.uri,
  type: ScreenshotType.POSTER,
  entities: OUTCOME.understanding.entities,
  actions: OUTCOME.understanding.actions,
  parseStatus: ParseStatus.PARSED,
  createdAt: 1784649600000,
  eventTime: OUTCOME.understanding.entities.eventTime
};

class ReadyImporter implements ScreenshotImporter {
  async importSingle(observer?: ScreenshotImportLifecycleObserver): Promise<ImportOutcome> {
    observer?.onSelectionConfirmed();
    return {
      kind: ImportOutcomeKind.READY,
      image: IMAGE,
      ocrText: '人工智能前沿讲座',
      ocrStatus: OcrStatus.SUCCESS
    };
  }
}

class SuccessfulUnderstander implements ScreenshotUnderstander {
  async understand(_image: PrivateImageDescriptor, _ocrText: string): Promise<UnderstandingOutcome> {
    return OUTCOME;
  }
}

class SuccessfulWriter implements ScreenshotCardWriter {
  async create(input: CreateScreenshotCardInput): Promise<ScreenshotCard> {
    return {
      id: CARD.id,
      imageUri: CARD.imageUri,
      thumbnailUri: CARD.thumbnailUri,
      type: input.outcome.understanding.type,
      entities: input.outcome.understanding.entities,
      actions: input.outcome.understanding.actions,
      parseStatus: input.outcome.understanding.parseStatus,
      createdAt: CARD.createdAt,
      eventTime: input.outcome.understanding.entities.eventTime
    };
  }
}

class CancelledImporter implements ScreenshotImporter {
  async importSingle(_observer?: ScreenshotImportLifecycleObserver): Promise<ImportOutcome> {
    return { kind: ImportOutcomeKind.CANCELLED };
  }
}

class RetryPendingImporter implements ScreenshotImporter {
  async importSingle(observer?: ScreenshotImportLifecycleObserver): Promise<ImportOutcome> {
    observer?.onSelectionConfirmed();
    return {
      kind: ImportOutcomeKind.READY,
      image: IMAGE,
      ocrText: '',
      ocrStatus: OcrStatus.RETRY_PENDING
    };
  }
}

class FailingUnderstander implements ScreenshotUnderstander {
  async understand(_image: PrivateImageDescriptor, _ocrText: string): Promise<UnderstandingOutcome> {
    throw new UnderstandingError(UnderstandingErrorCategory.NETWORK, '请检查网络连接后重试。');
  }
}

class FallbackUnderstander implements ScreenshotUnderstander {
  async understand(_image: PrivateImageDescriptor, _ocrText: string): Promise<UnderstandingOutcome> {
    return {
      thumbnail: OUTCOME.thumbnail,
      understanding: {
        type: ScreenshotType.UNCATEGORIZED,
        entities: { timeText: null, eventTime: null, location: null, code: null, amount: null },
        actions: [],
        parseStatus: ParseStatus.FALLBACK_INVALID_RESPONSE
      }
    };
  }
}

class NeverWriter implements ScreenshotCardWriter {
  async create(_input: CreateScreenshotCardInput): Promise<ScreenshotCard> {
    throw new Error('writer must not be reached');
  }
}

class FailingWriter implements ScreenshotCardWriter {
  async create(_input: CreateScreenshotCardInput): Promise<ScreenshotCard> {
    throw new CardStorageError(CardStorageErrorCategory.WRITE, '卡片未能保存到本机，请稍后重试。');
  }
}

class BlockingImporter implements ScreenshotImporter {
  private resolveImport?: (value: ImportOutcome) => void;

  importSingle(_observer?: ScreenshotImportLifecycleObserver): Promise<ImportOutcome> {
    return new Promise<ImportOutcome>((resolve: (value: ImportOutcome) => void): void => {
      this.resolveImport = resolve;
    });
  }

  cancel(): void {
    this.resolveImport?.({ kind: ImportOutcomeKind.CANCELLED });
  }
}

class StageRecorder implements IngestionObserver {
  readonly stages: IngestionStage[] = [];

  onStage(stage: IngestionStage): void {
    this.stages.push(stage);
  }
}

export default function screenshotIngestionCoordinatorTest() {
  describe('ScreenshotIngestionCoordinator', () => {
    it('turns one selected screenshot into a saved card with observable progress', 0, async () => {
      const recorder: StageRecorder = new StageRecorder();
      const coordinator: ScreenshotIngestionCoordinator = new ScreenshotIngestionCoordinator(
        new ReadyImporter(), new SuccessfulUnderstander(), new SuccessfulWriter()
      );

      const result: IngestionResult = await coordinator.ingestSingle(recorder);
      const saved: SavedIngestionResult = result as SavedIngestionResult;

      expect(result.kind).assertEqual(IngestionResultKind.SAVED);
      expect(saved.card.id).assertEqual('poster-id');
      expect(saved.ocrStatus).assertEqual(OcrStatus.SUCCESS);
      expect(recorder.stages.join(',')).assertEqual([
        IngestionStage.WAITING_FOR_SELECTION,
        IngestionStage.IMPORTING_AND_OCR,
        IngestionStage.UNDERSTANDING,
        IngestionStage.SAVING
      ].join(','));
    });

    it('treats picker cancellation as a normal outcome', 0, async () => {
      const recorder: StageRecorder = new StageRecorder();
      const result: IngestionResult = await new ScreenshotIngestionCoordinator(
        new CancelledImporter(), new SuccessfulUnderstander(), new SuccessfulWriter()
      ).ingestSingle(recorder);

      expect(result.kind).assertEqual(IngestionResultKind.CANCELLED);
      expect(recorder.stages.join(',')).assertEqual(IngestionStage.WAITING_FOR_SELECTION);
    });

    it('continues image understanding when OCR needs retry', 0, async () => {
      const result: IngestionResult = await new ScreenshotIngestionCoordinator(
        new RetryPendingImporter(), new SuccessfulUnderstander(), new SuccessfulWriter()
      ).ingestSingle(new StageRecorder());
      const saved: SavedIngestionResult = result as SavedIngestionResult;

      expect(result.kind).assertEqual(IngestionResultKind.SAVED);
      expect(saved.ocrStatus).assertEqual(OcrStatus.RETRY_PENDING);
      expect(saved.card.id).assertEqual('poster-id');
    });

    it('returns a sanitized understanding failure without attempting storage', 0, async () => {
      const result: IngestionResult = await new ScreenshotIngestionCoordinator(
        new ReadyImporter(), new FailingUnderstander(), new NeverWriter()
      ).ingestSingle(new StageRecorder());
      const failure: FailedIngestionResult = result as FailedIngestionResult;

      expect(result.kind).assertEqual(IngestionResultKind.FAILED);
      expect(failure.failureCategory).assertEqual(IngestionFailureCategory.UNDERSTANDING);
      expect(failure.errorCategory).assertEqual(UnderstandingErrorCategory.NETWORK);
      expect(failure.userMessage).assertEqual('请检查网络连接后重试。');
    });

    it('saves the safe uncategorized fallback after invalid model content', 0, async () => {
      const result: IngestionResult = await new ScreenshotIngestionCoordinator(
        new ReadyImporter(), new FallbackUnderstander(), new SuccessfulWriter()
      ).ingestSingle(new StageRecorder());
      const saved: SavedIngestionResult = result as SavedIngestionResult;

      expect(result.kind).assertEqual(IngestionResultKind.SAVED);
      expect(saved.parseStatus).assertEqual(ParseStatus.FALLBACK_INVALID_RESPONSE);
      expect(saved.card.type).assertEqual(ScreenshotType.UNCATEGORIZED);
      expect(saved.card.eventTime === null).assertTrue();
    });

    it('returns a sanitized storage failure instead of reporting success', 0, async () => {
      const result: IngestionResult = await new ScreenshotIngestionCoordinator(
        new ReadyImporter(), new SuccessfulUnderstander(), new FailingWriter()
      ).ingestSingle(new StageRecorder());
      const failure: FailedIngestionResult = result as FailedIngestionResult;

      expect(result.kind).assertEqual(IngestionResultKind.FAILED);
      expect(failure.failureCategory).assertEqual(IngestionFailureCategory.STORAGE);
      expect(failure.errorCategory).assertEqual(CardStorageErrorCategory.WRITE);
      expect(failure.userMessage).assertEqual('卡片未能保存到本机，请稍后重试。');
    });

    it('rejects a second ingestion while the first picker is still open', 0, async () => {
      const importer: BlockingImporter = new BlockingImporter();
      const coordinator: ScreenshotIngestionCoordinator = new ScreenshotIngestionCoordinator(
        importer, new SuccessfulUnderstander(), new SuccessfulWriter()
      );
      const first: Promise<IngestionResult> = coordinator.ingestSingle(new StageRecorder());

      const second: IngestionResult = await coordinator.ingestSingle(new StageRecorder());
      const failure: FailedIngestionResult = second as FailedIngestionResult;
      importer.cancel();
      await first;

      expect(second.kind).assertEqual(IngestionResultKind.FAILED);
      expect(failure.failureCategory).assertEqual(IngestionFailureCategory.BUSY);
    });
  });
}
