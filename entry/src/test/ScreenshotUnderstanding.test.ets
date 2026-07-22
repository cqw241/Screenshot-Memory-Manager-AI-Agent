import { describe, expect, it } from '@ohos/hypium';
import { RuntimeModelConfig } from '../main/ets/models/ModelConfig';
import { PrivateImageDescriptor } from '../main/ets/models/ScreenshotImportModels';
import {
  ParseStatus,
  ScreenshotType,
  StructuredUnderstanding,
  UnderstandingError,
  UnderstandingErrorCategory,
  UnderstandingOutcome
} from '../main/ets/models/StructuredUnderstandingModels';
import {
  HttpTransport,
  HttpTransportRequest,
  HttpTransportResponse,
  TransportError,
  TransportErrorKind
} from '../main/ets/models/VerificationModels';
import { calculateThumbnailSize, ThumbnailSize } from '../main/ets/services/HarmonyThumbnailGenerator';
import { VerifiedConfigAccess } from '../main/ets/services/ConfigStoragePorts';
import {
  ThumbnailGenerator,
  ThumbnailPayload,
  UnderstandingClock,
  UnderstandingMetricsLogger,
  UnderstandingTemporalContext
} from '../main/ets/services/ScreenshotUnderstandingPorts';
import {
  buildUnderstandingRequestBody,
  ScreenshotUnderstandingService
} from '../main/ets/services/ScreenshotUnderstandingService';
import {
  InvalidStructuredContentError,
  isIso8601WithTimezone,
  parseStructuredContent
} from '../main/ets/services/StructuredResponseParser';
import { ParsedServiceURL, ServiceURLParser } from '../main/ets/services/UrlPreflight';

const TEST_IMAGE: PrivateImageDescriptor = {
  id: 'image-id',
  uri: 'file:///private/imports/image-id.png',
  path: '/private/imports/image-id.png',
  mimeType: 'image/png',
  width: 1080,
  height: 1600,
  byteCount: 72158
};

const THUMBNAIL_DATA_URL: string = 'data:image/jpeg;base64,VEhVTUJOQUlM';

class FakeConfigAccess implements VerifiedConfigAccess {
  readonly runtime: RuntimeModelConfig = {
    baseURL: 'https://api.example.com/v1',
    apiKey: 'test-only-key',
    model: 'vision-model',
    verifiedAt: 100,
    verificationProtocolVersion: 1,
    trustedOrigin: 'https://api.example.com'
  };

  async withVerifiedConfig<T>(action: (config: RuntimeModelConfig) => Promise<T>): Promise<T> {
    try {
      return await action(this.runtime);
    } finally {
      this.runtime.apiKey = '';
    }
  }
}

class FakeThumbnailGenerator implements ThumbnailGenerator {
  async generate(_source: PrivateImageDescriptor): Promise<ThumbnailPayload> {
    return {
      descriptor: {
        uri: 'file:///private/thumbnails/image-id.jpg',
        path: '/private/thumbnails/image-id.jpg',
        mimeType: 'image/jpeg',
        width: 691,
        height: 1024,
        byteCount: 12345
      },
      dataURL: THUMBNAIL_DATA_URL
    };
  }
}

class FakeClock implements UnderstandingClock {
  captureCount: number = 0;

  capture(): UnderstandingTemporalContext {
    this.captureCount += 1;
    return {
      currentLocalTime: '2026-07-21T09:30:00-07:00',
      timeZoneId: 'America/Tijuana'
    };
  }
}

class FakeLogger implements UnderstandingMetricsLogger {
  thumbnailCount: number = 0;
  successCount: number = 0;
  errorCount: number = 0;
  lastError?: UnderstandingErrorCategory;

  recordThumbnail(_width: number, _height: number, _encodedByteCount: number): void {
    this.thumbnailCount += 1;
  }

  recordSuccess(_requestCount: number, _elapsedMs: number): void {
    this.successCount += 1;
  }

  recordError(_requestCount: number, _elapsedMs: number, category: UnderstandingErrorCategory): void {
    this.errorCount += 1;
    this.lastError = category;
  }
}

class FakeURLParser implements ServiceURLParser {
  parse(rawURL: string): ParsedServiceURL {
    if (rawURL === 'https://api.example.com/v1') {
      return {
        protocol: 'https:',
        hostname: 'api.example.com',
        username: '',
        password: '',
        search: '',
        hash: '',
        origin: 'https://api.example.com',
        serialized: rawURL
      };
    }
    if (rawURL === 'https://dashscope.aliyuncs.com/compatible-mode/v1') {
      return {
        protocol: 'https:',
        hostname: 'dashscope.aliyuncs.com',
        username: '',
        password: '',
        search: '',
        hash: '',
        origin: 'https://dashscope.aliyuncs.com',
        serialized: rawURL
      };
    }
    throw new Error('invalid test URL');
  }
}

class FakeTransport implements HttpTransport {
  readonly requests: HttpTransportRequest[] = [];
  readonly requestBodies: string[] = [];
  responses: HttpTransportResponse[] = [];
  failure?: TransportError;

  async send(request: HttpTransportRequest): Promise<HttpTransportResponse> {
    this.requests.push(request);
    this.requestBodies.push(request.body);
    if (this.failure !== undefined) {
      throw this.failure;
    }
    return this.responses.shift() ?? { statusCode: 200, body: completion(validPoster()) };
  }
}

function service(transport: FakeTransport, config: FakeConfigAccess = new FakeConfigAccess(),
  clock: FakeClock = new FakeClock(), logger: FakeLogger = new FakeLogger()): ScreenshotUnderstandingService {
  return new ScreenshotUnderstandingService(config, new FakeThumbnailGenerator(), transport, clock, logger,
    new FakeURLParser());
}

function completion(content: string): string {
  return '{"choices":[{"message":{"content":' + JSON.stringify(content) + '}}]}';
}

function validPoster(): string {
  return '{"type":"POSTER","entities":{"timeText":"2026年7月25日 14:00",' +
    '"eventTime":"2026-07-25T14:00:00+08:00","location":"图书馆报告厅","code":null,"amount":null},' +
    '"actions":["REMIND","NAVIGATE","ADD_CALENDAR"]}';
}

function validFor(type: ScreenshotType): string {
  return `{"type":"${type}","entities":{"timeText":null,"eventTime":null,"location":null,` +
    '"code":null,"amount":null},"actions":[]}';
}

function invalidThenFallbackTransport(): FakeTransport {
  const transport: FakeTransport = new FakeTransport();
  transport.responses = [
    { statusCode: 200, body: completion('not-json') },
    { statusCode: 200, body: completion('```json\n{}\n```') }
  ];
  return transport;
}

async function capturedCategory(transport: FakeTransport): Promise<UnderstandingErrorCategory | undefined> {
  try {
    await service(transport).understand(TEST_IMAGE, 'OCR');
  } catch (error) {
    return (error as UnderstandingError).category;
  }
  return undefined;
}

function assertInvalid(raw: string): void {
  let invalid: boolean = false;
  try {
    parseStructuredContent(raw);
  } catch (error) {
    invalid = error instanceof InvalidStructuredContentError;
  }
  expect(invalid).assertTrue();
}

export default function screenshotUnderstandingTest() {
  describe('ScreenshotUnderstanding', () => {
    it('calculates proportional thumbnail sizes without enlarging small images', 0, () => {
      const portrait: ThumbnailSize = calculateThumbnailSize(1080, 1600);
      const landscape: ThumbnailSize = calculateThumbnailSize(2400, 1080);
      const boundary: ThumbnailSize = calculateThumbnailSize(1024, 600);
      const small: ThumbnailSize = calculateThumbnailSize(320, 200);

      expect(portrait.width).assertEqual(691);
      expect(portrait.height).assertEqual(1024);
      expect(landscape.width).assertEqual(1024);
      expect(landscape.height).assertEqual(461);
      expect(boundary.width).assertEqual(1024);
      expect(boundary.height).assertEqual(600);
      expect(small.width).assertEqual(320);
      expect(small.height).assertEqual(200);
    });

    it('builds a thumbnail-only request with device time, timezone and OCR text', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      const config: FakeConfigAccess = new FakeConfigAccess();
      const clock: FakeClock = new FakeClock();
      transport.responses = [{ statusCode: 200, body: completion(validPoster()) }];

      const outcome: UnderstandingOutcome = await service(transport, config, clock)
        .understand(TEST_IMAGE, '人工智能前沿讲座');

      const body: string = transport.requestBodies[0];
      expect(outcome.understanding.type).assertEqual(ScreenshotType.POSTER);
      expect(body.includes(THUMBNAIL_DATA_URL)).assertTrue();
      expect(body.includes(TEST_IMAGE.uri)).assertFalse();
      expect(body.includes('2026-07-21T09:30:00-07:00')).assertTrue();
      expect(body.includes('America/Tijuana')).assertTrue();
      expect(body.includes('人工智能前沿讲座')).assertTrue();
      expect(body.includes('test-only-key')).assertFalse();
      expect(body.includes('"detail"')).assertFalse();
      expect(body.includes('"enable_thinking"')).assertFalse();
      expect(clock.captureCount).assertEqual(1);
      expect(config.runtime.apiKey).assertEqual('');
      expect(transport.requests[0].apiKey).assertEqual('');
    });

    it('disables thinking for another supported DashScope understanding model', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      const config: FakeConfigAccess = new FakeConfigAccess();
      config.runtime.baseURL = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
      config.runtime.trustedOrigin = 'https://dashscope.aliyuncs.com';
      config.runtime.model = 'qwen-plus-latest';
      transport.responses = [{ statusCode: 200, body: completion(validPoster()) }];

      await service(transport, config).understand(TEST_IMAGE, 'OCR');

      expect(transport.requestBodies[0].includes('"enable_thinking":false')).assertTrue();
      expect(transport.requestBodies[0].includes('"detail"')).assertFalse();
    });

    it('accepts all fixed screenshot types and nullable entities', 0, () => {
      const types: ScreenshotType[] = [ScreenshotType.POSTER, ScreenshotType.PICKUP_CODE,
        ScreenshotType.DDL_NOTICE, ScreenshotType.COUPON, ScreenshotType.UNCATEGORIZED];
      for (const type of types) {
        const parsed: StructuredUnderstanding = parseStructuredContent(validFor(type));
        expect(parsed.type).assertEqual(type);
        expect(parsed.entities.eventTime === null).assertTrue();
        expect(parsed.parseStatus).assertEqual(ParseStatus.PARSED);
      }
    });

    it('accepts completion content split across text parts', 0, async () => {
      const raw: string = validPoster();
      const splitAt: number = 80;
      const response: string = '{"choices":[{"message":{"content":[' +
        '{"type":"text","text":' + JSON.stringify(raw.substring(0, splitAt)) + '},' +
        '{"type":"text","text":' + JSON.stringify(raw.substring(splitAt)) + '}]}}]}';
      const transport: FakeTransport = new FakeTransport();
      transport.responses = [{ statusCode: 200, body: response }];

      const outcome: UnderstandingOutcome = await service(transport).understand(TEST_IMAGE, 'OCR');

      expect(outcome.understanding.type).assertEqual(ScreenshotType.POSTER);
    });

    it('strictly rejects malformed content, wrong shapes, unknown enums and extra fields', 0, () => {
      assertInvalid('```json\n' + validPoster() + '\n```');
      assertInvalid('{broken');
      assertInvalid('{"type":"POSTER","entities":{},"actions":[]}');
      assertInvalid('{"type":"POSTER","entities":{"timeText":null,"eventTime":null,"location":null,' +
        '"code":null,"amount":null},"actions":[],"extra":true}');
      assertInvalid('{"type":"CHAT","entities":{"timeText":null,"eventTime":null,"location":null,' +
        '"code":null,"amount":null},"actions":[]}');
      assertInvalid('{"type":"POSTER","entities":{"timeText":7,"eventTime":null,"location":null,' +
        '"code":null,"amount":null},"actions":[]}');
      assertInvalid('{"type":"POSTER","entities":{"timeText":null,"eventTime":null,"location":null,' +
        '"code":null,"amount":null,"extra":null},"actions":[]}');
      assertInvalid('{"type":"POSTER","entities":{"timeText":"7月25日","eventTime":' +
        '"2026-07-25T14:00:00","location":null,"code":null,"amount":null},"actions":[]}');
      assertInvalid('{"type":"POSTER","entities":{"timeText":null,"eventTime":null,"location":null,' +
        '"code":null,"amount":null},"actions":["DELETE"]}');
    });

    it('requires a real ISO-8601 calendar time with timezone', 0, () => {
      expect(isIso8601WithTimezone('2026-07-25T14:00:00+08:00')).assertTrue();
      expect(isIso8601WithTimezone('2026-07-25T06:00Z')).assertTrue();
      expect(isIso8601WithTimezone('2026-07-25T14:00:00')).assertFalse();
      expect(isIso8601WithTimezone('2026-02-29T14:00:00+08:00')).assertFalse();
      expect(isIso8601WithTimezone('2026-07-25T14:00:00+15:00')).assertFalse();
    });

    it('rejects an event time when the source text omits the year', 0, () => {
      assertInvalid('{"type":"PICKUP_CODE","entities":{"timeText":"7月23日前","eventTime":' +
        '"2026-07-23T23:59:00-07:00","location":"南门快递站","code":"A8B6","amount":null},' +
        '"actions":["COPY_CODE"]}');
    });

    it('rejects an event time when the source text omits the clock time', 0, () => {
      assertInvalid('{"type":"POSTER","entities":{"timeText":"2026年7月25日","eventTime":' +
        '"2026-07-25T14:00:00+08:00","location":"图书馆报告厅","code":null,"amount":null},' +
        '"actions":["REMIND"]}');
    });

    it('rejects an event time when the source text omits the calendar day', 0, () => {
      assertInvalid('{"type":"POSTER","entities":{"timeText":"2026年7月 14:00","eventTime":' +
        '"2026-07-25T14:00:00+08:00","location":null,"code":null,"amount":null},"actions":[]}');
    });

    it('rejects event times that conflict with their source components or invent seconds', 0, () => {
      assertInvalid('{"type":"POSTER","entities":{"timeText":"2026年7月25日 14:00","eventTime":' +
        '"2026-07-26T14:00:00+08:00","location":null,"code":null,"amount":null},"actions":[]}');
      assertInvalid('{"type":"POSTER","entities":{"timeText":"2026年7月25日 14:00","eventTime":' +
        '"2026-07-25T14:00:30+08:00","location":null,"code":null,"amount":null},"actions":[]}');
    });

    it('accepts complete numeric source dates and nullable normalized times', 0, () => {
      const numeric: StructuredUnderstanding = parseStructuredContent(
        '{"type":"DDL_NOTICE","entities":{"timeText":"截止：2026/7/28 23:59","eventTime":' +
        '"2026-07-28T23:59:00-07:00","location":null,"code":null,"amount":null},"actions":[]}'
      );
      const nullable: StructuredUnderstanding = parseStructuredContent(
        '{"type":"DDL_NOTICE","entities":{"timeText":"2026年7月28日 23:59","eventTime":null,' +
        '"location":null,"code":null,"amount":null},"actions":[]}'
      );
      const hyphenated: StructuredUnderstanding = parseStructuredContent(
        '{"type":"POSTER","entities":{"timeText":"2026-7-25 14:00","eventTime":' +
        '"2026-07-25T14:00:00+08:00","location":null,"code":null,"amount":null},"actions":[]}'
      );

      expect(numeric.entities.eventTime).assertEqual('2026-07-28T23:59:00-07:00');
      expect(nullable.entities.eventTime === null).assertTrue();
      expect(hyphenated.entities.eventTime).assertEqual('2026-07-25T14:00:00+08:00');
    });

    it('retries invalid content once using the same inputs without echoing the raw response', 0, async () => {
      const firstRaw: string = 'INVALID_PRIVATE_FIRST_RESPONSE';
      const transport: FakeTransport = new FakeTransport();
      transport.responses = [
        { statusCode: 200, body: completion(firstRaw) },
        { statusCode: 200, body: completion(validPoster()) }
      ];

      const outcome: UnderstandingOutcome = await service(transport).understand(TEST_IMAGE, '同一 OCR 文本');

      expect(outcome.understanding.parseStatus).assertEqual(ParseStatus.PARSED);
      expect(transport.requestBodies.length).assertEqual(2);
      expect(transport.requestBodies[0].includes(THUMBNAIL_DATA_URL)).assertTrue();
      expect(transport.requestBodies[1].includes(THUMBNAIL_DATA_URL)).assertTrue();
      expect(transport.requestBodies[0].includes('同一 OCR 文本')).assertTrue();
      expect(transport.requestBodies[1].includes('同一 OCR 文本')).assertTrue();
      expect(transport.requestBodies[1].includes(firstRaw)).assertFalse();
      expect(transport.requestBodies[1].includes('2026-07-21T09:30:00-07:00')).assertTrue();
    });

    it('returns the exact uncategorized fallback after two invalid responses', 0, async () => {
      const transport: FakeTransport = invalidThenFallbackTransport();
      const config: FakeConfigAccess = new FakeConfigAccess();
      const outcome: UnderstandingOutcome = await service(transport, config).understand(TEST_IMAGE, 'OCR');

      expect(outcome.understanding.type).assertEqual(ScreenshotType.UNCATEGORIZED);
      expect(outcome.understanding.entities.timeText === null).assertTrue();
      expect(outcome.understanding.entities.eventTime === null).assertTrue();
      expect(outcome.understanding.entities.location === null).assertTrue();
      expect(outcome.understanding.entities.code === null).assertTrue();
      expect(outcome.understanding.entities.amount === null).assertTrue();
      expect(outcome.understanding.actions.length).assertEqual(0);
      expect(outcome.understanding.parseStatus).assertEqual(ParseStatus.FALLBACK_INVALID_RESPONSE);
      expect(config.runtime.apiKey).assertEqual('');
      expect(transport.requests[0].apiKey).assertEqual('');
      expect(transport.requests[1].apiKey).assertEqual('');
    });

    it('classifies authentication, address, rate-limit, image and service failures without retrying', 0, async () => {
      const auth: FakeTransport = new FakeTransport();
      auth.responses = [{ statusCode: 401, body: 'secret server body' }];
      const forbidden: FakeTransport = new FakeTransport();
      forbidden.responses = [{ statusCode: 403, body: 'secret server body' }];
      const address: FakeTransport = new FakeTransport();
      address.responses = [{ statusCode: 404, body: 'missing' }];
      const method: FakeTransport = new FakeTransport();
      method.responses = [{ statusCode: 405, body: 'missing' }];
      const limit: FakeTransport = new FakeTransport();
      limit.responses = [{ statusCode: 429, body: 'slow down' }];
      const image: FakeTransport = new FakeTransport();
      image.responses = [{ statusCode: 400, body: 'model does not support image input' }];
      const serviceFailure: FakeTransport = new FakeTransport();
      serviceFailure.responses = [{ statusCode: 500, body: 'private diagnostics' }];

      expect(await capturedCategory(auth)).assertEqual(UnderstandingErrorCategory.AUTHENTICATION);
      expect(await capturedCategory(forbidden)).assertEqual(UnderstandingErrorCategory.AUTHENTICATION);
      expect(await capturedCategory(address)).assertEqual(UnderstandingErrorCategory.ADDRESS);
      expect(await capturedCategory(method)).assertEqual(UnderstandingErrorCategory.ADDRESS);
      expect(await capturedCategory(limit)).assertEqual(UnderstandingErrorCategory.RATE_LIMIT);
      expect(await capturedCategory(image)).assertEqual(UnderstandingErrorCategory.IMAGE_CAPABILITY);
      expect(await capturedCategory(serviceFailure)).assertEqual(UnderstandingErrorCategory.SERVICE);
      expect(auth.requests.length).assertEqual(1);
      expect(limit.requests.length).assertEqual(1);
    });

    it('classifies network and incompatible outer responses without producing fallback', 0, async () => {
      const network: FakeTransport = new FakeTransport();
      network.failure = new TransportError(TransportErrorKind.TIMEOUT);
      const invalidEnvelope: FakeTransport = new FakeTransport();
      invalidEnvelope.responses = [{ statusCode: 200, body: '{"choices":[]}' }];
      const malformedEnvelope: FakeTransport = new FakeTransport();
      malformedEnvelope.responses = [{ statusCode: 200, body: '{broken' }];

      expect(await capturedCategory(network)).assertEqual(UnderstandingErrorCategory.NETWORK);
      expect(await capturedCategory(invalidEnvelope)).assertEqual(UnderstandingErrorCategory.SERVICE);
      expect(await capturedCategory(malformedEnvelope)).assertEqual(UnderstandingErrorCategory.SERVICE);
      expect(network.requests.length).assertEqual(1);
      expect(invalidEnvelope.requests.length).assertEqual(1);
      expect(malformedEnvelope.requests.length).assertEqual(1);
      expect(network.requests[0].apiKey).assertEqual('');
    });

    it('builds a correction prompt without requiring response-format extensions', 0, () => {
      const body: string = buildUnderstandingRequestBody('vision-model', '', THUMBNAIL_DATA_URL, {
        currentLocalTime: '2026-07-21T09:30:00-07:00',
        timeZoneId: 'America/Tijuana'
      }, true);

      expect(body.includes('上一次输出未通过客户端校验')).assertTrue();
      expect(body.includes('eventTime 非空时，timeText 必须明确包含年、月、日、时、分')).assertTrue();
      expect(body.includes('response_format')).assertFalse();
      expect(body.includes('"temperature":0')).assertTrue();
      expect(body.includes('"max_tokens":500')).assertTrue();
    });
  });
}
