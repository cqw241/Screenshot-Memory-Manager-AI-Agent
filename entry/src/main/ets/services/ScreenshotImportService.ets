import {
  ImportOutcome,
  ImportOutcomeKind,
  OcrStatus,
  PrivateImageDescriptor
} from '../models/ScreenshotImportModels';
import {
  OcrSession,
  OcrSessionFactory,
  PhotoSelectionPort,
  PrivateImageStorePort
} from './ScreenshotImportPorts';

export class ScreenshotImportService {
  private readonly picker: PhotoSelectionPort;
  private readonly imageStore: PrivateImageStorePort;
  private readonly ocrFactory: OcrSessionFactory;

  constructor(picker: PhotoSelectionPort, imageStore: PrivateImageStorePort, ocrFactory: OcrSessionFactory) {
    this.picker = picker;
    this.imageStore = imageStore;
    this.ocrFactory = ocrFactory;
  }

  async importSingle(): Promise<ImportOutcome> {
    const selectedUri: string | undefined = await this.picker.selectSingleImage();
    if (selectedUri === undefined || selectedUri.length === 0) {
      return { kind: ImportOutcomeKind.CANCELLED };
    }

    const privateImage: PrivateImageDescriptor = await this.imageStore.importImage(selectedUri);
    const session: OcrSession = await this.ocrFactory.open(privateImage.uri);
    let text: string = '';
    let status: OcrStatus = OcrStatus.RETRY_PENDING;
    try {
      text = normalizeOcrText(await session.recognizeText());
      status = text.length > 0 ? OcrStatus.SUCCESS : OcrStatus.RETRY_PENDING;
    } catch (_error) {
      text = '';
      status = OcrStatus.RETRY_PENDING;
    } finally {
      await session.release();
    }

    return {
      kind: ImportOutcomeKind.READY,
      image: privateImage,
      ocrText: text,
      ocrStatus: status
    };
  }
}

export function normalizeOcrText(raw: string): string {
  return raw.replace(/\r\n?/g, '\n').trim();
}
