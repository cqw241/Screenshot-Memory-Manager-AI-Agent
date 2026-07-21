import { PrivateImageDescriptor } from '../models/ScreenshotImportModels';

export interface PhotoSelectionPort {
  selectSingleImage(): Promise<string | undefined>;
}

export interface PrivateImageStorePort {
  importImage(sourceUri: string): Promise<PrivateImageDescriptor>;
}

export interface OcrSession {
  recognizeText(): Promise<string>;
  release(): Promise<void>;
}

export interface OcrSessionFactory {
  open(imageUri: string): Promise<OcrSession>;
}
