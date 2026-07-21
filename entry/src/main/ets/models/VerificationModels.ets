export enum VerificationErrorCategory {
  ADDRESS = '地址或接口错误',
  AUTHENTICATION = '认证失败',
  VISION = '无法确认图像理解',
  NETWORK = '网络错误',
  SERVICE = '服务错误',
  RESPONSE = '响应格式错误',
  TRUST = '需要确认服务源'
}

export class VerificationError extends Error {
  readonly category: VerificationErrorCategory;
  readonly userMessage: string;

  constructor(category: VerificationErrorCategory, userMessage: string) {
    super(userMessage);
    this.name = 'VerificationError';
    this.category = category;
    this.userMessage = userMessage;
  }
}

export interface VerificationConfirmations {
  customOriginTrusted: boolean;
  loopbackHttpAccepted: boolean;
}

export interface VerificationCandidate {
  baseURL: string;
  apiKey: string;
  model: string;
}

export interface VerificationSuccess {
  normalizedBaseURL: string;
  trustedOrigin: string;
  challengeId: string;
}

export interface HttpTransportRequest {
  url: string;
  apiKey: string;
  body: string;
  timeoutMs: number;
}

export interface HttpTransportResponse {
  statusCode: number;
  body: string;
}

export interface HttpTransport {
  send(request: HttpTransportRequest): Promise<HttpTransportResponse>;
}

export enum TransportErrorKind {
  NETWORK = 'NETWORK',
  TIMEOUT = 'TIMEOUT'
}

export class TransportError extends Error {
  readonly kind: TransportErrorKind;

  constructor(kind: TransportErrorKind) {
    super(kind === TransportErrorKind.TIMEOUT ? 'transport timeout' : 'transport network failure');
    this.name = 'TransportError';
    this.kind = kind;
  }
}
