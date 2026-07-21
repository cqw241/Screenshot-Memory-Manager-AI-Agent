import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { OcrSession, OcrSessionFactory } from './ScreenshotImportPorts';

class HarmonyOcrSession implements OcrSession {
  private readonly source: image.ImageSource;
  private readonly pixelMap: image.PixelMap;

  constructor(source: image.ImageSource, pixelMap: image.PixelMap) {
    this.source = source;
    this.pixelMap = pixelMap;
  }

  async recognizeText(): Promise<string> {
    const result: textRecognition.TextRecognitionResult = await textRecognition.recognizeText({
      pixelMap: this.pixelMap
    }, {
      isDirectionDetectionSupported: false
    });
    return result.value;
  }

  async release(): Promise<void> {
    try {
      await this.pixelMap.release();
    } finally {
      await this.source.release();
    }
  }
}
export class HarmonyOcrSessionFactory implements OcrSessionFactory {
  async open(imageUri: string): Promise<OcrSession> {
    const source: image.ImageSource = image.createImageSource(imageUri);
    try {
      const pixelMap: image.PixelMap = await source.createPixelMap();
      return new HarmonyOcrSession(source, pixelMap);
    } catch (error) {
      await source.release();
      throw error as Error;
    }
  }
}
