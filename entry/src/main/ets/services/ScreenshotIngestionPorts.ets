import {
  CreateScreenshotCardInput,
  ScreenshotCard
} from '../models/ScreenshotCardModels';
import {
  ImportOutcome,
  PrivateImageDescriptor
} from '../models/ScreenshotImportModels';
import { UnderstandingOutcome } from '../models/StructuredUnderstandingModels';
import { ScreenshotImportLifecycleObserver } from './ScreenshotImportPorts';

export interface ScreenshotImporter {
  importSingle(observer?: ScreenshotImportLifecycleObserver): Promise<ImportOutcome>;
}

export interface ScreenshotUnderstander {
  understand(image: PrivateImageDescriptor, ocrText: string): Promise<UnderstandingOutcome>;
}

export interface ScreenshotCardWriter {
  create(input: CreateScreenshotCardInput): Promise<ScreenshotCard>;
}
