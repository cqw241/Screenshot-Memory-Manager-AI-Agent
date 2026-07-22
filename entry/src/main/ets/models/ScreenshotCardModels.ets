import {
  ParseStatus,
  ScreenshotType,
  StructuredEntities,
  StructuredUnderstanding,
  SuggestedAction,
  UnderstandingOutcome
} from './StructuredUnderstandingModels';
import { PrivateImageDescriptor } from './ScreenshotImportModels';

export interface CreateScreenshotCardInput {
  image: PrivateImageDescriptor;
  outcome: UnderstandingOutcome;
}

export interface ScreenshotCard {
  id: string;
  imageUri: string;
  thumbnailUri: string;
  type: ScreenshotType;
  entities: StructuredEntities;
  actions: SuggestedAction[];
  parseStatus: ParseStatus;
  createdAt: number;
  eventTime: string | null;
}

export interface ScreenshotCardRepositoryPort {
  create(input: CreateScreenshotCardInput): Promise<ScreenshotCard>;
  getById(id: string): Promise<ScreenshotCard | undefined>;
  updateUnderstanding(id: string, understanding: StructuredUnderstanding): Promise<ScreenshotCard>;
  deleteById(id: string): Promise<boolean>;
  listTimeline(): Promise<ScreenshotCard[]>;
}

export enum CardStorageErrorCategory {
  OPEN = '本地存储不可用',
  READ = '卡片读取失败',
  WRITE = '卡片写入失败',
  CORRUPT = '卡片数据损坏'
}

export class CardStorageError extends Error {
  readonly category: CardStorageErrorCategory;
  readonly userMessage: string;

  constructor(category: CardStorageErrorCategory, userMessage: string) {
    super(userMessage);
    this.name = 'CardStorageError';
    this.category = category;
    this.userMessage = userMessage;
  }
}
