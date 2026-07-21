export enum ScreenshotType {
  POSTER = 'POSTER',
  PICKUP_CODE = 'PICKUP_CODE',
  DDL_NOTICE = 'DDL_NOTICE',
  COUPON = 'COUPON',
  UNCATEGORIZED = 'UNCATEGORIZED'
}

export enum SuggestedAction {
  REMIND = 'REMIND',
  NAVIGATE = 'NAVIGATE',
  COPY_CODE = 'COPY_CODE',
  ADD_CALENDAR = 'ADD_CALENDAR'
}

export enum ParseStatus {
  PARSED = 'PARSED',
  FALLBACK_INVALID_RESPONSE = 'FALLBACK_INVALID_RESPONSE'
}

export interface StructuredEntities {
  timeText: string | null;
  eventTime: string | null;
  location: string | null;
  code: string | null;
  amount: string | null;
}

export interface StructuredUnderstanding {
  type: ScreenshotType;
  entities: StructuredEntities;
  actions: SuggestedAction[];
  parseStatus: ParseStatus;
}

export interface ThumbnailDescriptor {
  uri: string;
  path: string;
  mimeType: string;
  width: number;
  height: number;
  byteCount: number;
}

export interface UnderstandingOutcome {
  thumbnail: ThumbnailDescriptor;
  understanding: StructuredUnderstanding;
}

export enum UnderstandingErrorCategory {
  AUTHENTICATION = '认证失败',
  NETWORK = '网络错误',
  RATE_LIMIT = '请求过于频繁',
  ADDRESS = '地址或接口错误',
  IMAGE_CAPABILITY = '图片能力错误',
  SERVICE = '服务错误'
}

export class UnderstandingError extends Error {
  readonly category: UnderstandingErrorCategory;
  readonly userMessage: string;

  constructor(category: UnderstandingErrorCategory, userMessage: string) {
    super(userMessage);
    this.name = 'UnderstandingError';
    this.category = category;
    this.userMessage = userMessage;
  }
}
