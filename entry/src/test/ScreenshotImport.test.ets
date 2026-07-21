import { describe, expect, it } from '@ohos/hypium';
import {
  ImportOutcome,
  ImportOutcomeKind,
  OcrStatus,
  PrivateImageDescriptor,
  ReadyImportOutcome
} from '../main/ets/models/ScreenshotImportModels';
import {
  OcrSession,
  OcrSessionFactory,
  PhotoSelectionPort,
  PrivateImageStorePort
} from '../main/ets/services/ScreenshotImportPorts';
import { normalizeOcrText, ScreenshotImportService } from '../main/ets/services/ScreenshotImportService';

const TEST_IMAGE: PrivateImageDescriptor = {
  id: 'sample-id',
  uri: 'file:///private/sample.png',
  path: '/private/sample.png',
  mimeType: 'image/png',
  width: 1080,
  height: 2400,
  byteCount: 4096
};

class FakePicker implements PhotoSelectionPort {
  selected?: string = 'photo://sample';

  async selectSingleImage(): Promise<string | undefined> {
    return this.selected;
  }
}

class FakeImageStore implements PrivateImageStorePort {
  importCount: number = 0;

  async importImage(_sourceUri: string): Promise<PrivateImageDescriptor> {
    this.importCount += 1;
    return TEST_IMAGE;
  }
}

class FakeOcrSession implements OcrSession {
  text: string = '  取件码 A8B6\r\n南门驿站  ';
  failure: boolean = false;
  releaseCount: number = 0;

  async recognizeText(): Promise<string> {
    if (this.failure) {
      throw new Error('injected OCR failure');
    }
    return this.text;
  }

  async release(): Promise<void> {
    this.releaseCount += 1;
  }
}

class FakeOcrFactory implements OcrSessionFactory {
  readonly session: FakeOcrSession = new FakeOcrSession();
  openCount: number = 0;

  async open(_imageUri: string): Promise<OcrSession> {
    this.openCount += 1;
    return this.session;
  }
}

function ready(outcome: ImportOutcome): ReadyImportOutcome {
  return outcome as ReadyImportOutcome;
}

export default function screenshotImportTest() {
  describe('ScreenshotImportService', () => {
    it('treats an empty picker result as a normal cancellation', 0, async () => {
      const picker: FakePicker = new FakePicker();
      picker.selected = undefined;
      const store: FakeImageStore = new FakeImageStore();
      const ocr: FakeOcrFactory = new FakeOcrFactory();

      const outcome: ImportOutcome = await new ScreenshotImportService(picker, store, ocr).importSingle();

      expect(outcome.kind).assertEqual(ImportOutcomeKind.CANCELLED);
      expect(store.importCount).assertEqual(0);
      expect(ocr.openCount).assertEqual(0);
    });

    it('imports one private copy and returns normalized OCR text', 0, async () => {
      const picker: FakePicker = new FakePicker();
      const store: FakeImageStore = new FakeImageStore();
      const ocr: FakeOcrFactory = new FakeOcrFactory();

      const outcome: ReadyImportOutcome = ready(
        await new ScreenshotImportService(picker, store, ocr).importSingle()
      );

      expect(outcome.kind).assertEqual(ImportOutcomeKind.READY);
      expect(outcome.image.uri).assertEqual(TEST_IMAGE.uri);
      expect(outcome.ocrText).assertEqual('取件码 A8B6\n南门驿站');
      expect(outcome.ocrStatus).assertEqual(OcrStatus.SUCCESS);
      expect(store.importCount).assertEqual(1);
      expect(ocr.session.releaseCount).assertEqual(1);
    });

    it('marks an empty OCR result for retry and still releases resources', 0, async () => {
      const ocr: FakeOcrFactory = new FakeOcrFactory();
      ocr.session.text = ' \r\n ';

      const outcome: ReadyImportOutcome = ready(await new ScreenshotImportService(
        new FakePicker(), new FakeImageStore(), ocr
      ).importSingle());

      expect(outcome.ocrText).assertEqual('');
      expect(outcome.ocrStatus).assertEqual(OcrStatus.RETRY_PENDING);
      expect(ocr.session.releaseCount).assertEqual(1);
    });

    it('turns an OCR exception into retry pending and releases resources', 0, async () => {
      const ocr: FakeOcrFactory = new FakeOcrFactory();
      ocr.session.failure = true;

      const outcome: ReadyImportOutcome = ready(await new ScreenshotImportService(
        new FakePicker(), new FakeImageStore(), ocr
      ).importSingle());

      expect(outcome.ocrText).assertEqual('');
      expect(outcome.ocrStatus).assertEqual(OcrStatus.RETRY_PENDING);
      expect(ocr.session.releaseCount).assertEqual(1);
    });

    it('normalizes line endings without rewriting recognized characters', 0, () => {
      expect(normalizeOcrText('  A8B6\r位置：南门\r\n07-25  '))
        .assertEqual('A8B6\n位置：南门\n07-25');
    });
  });
}
