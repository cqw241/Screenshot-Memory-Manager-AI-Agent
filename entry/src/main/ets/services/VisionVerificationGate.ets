import {
  HttpTransport,
  HttpTransportRequest,
  HttpTransportResponse,
  TransportError,
  TransportErrorKind,
  VerificationCandidate,
  VerificationConfirmations,
  VerificationError,
  VerificationErrorCategory,
  VerificationSuccess
} from '../models/VerificationModels';
import {
  HarmonyServiceURLParser,
  preflightURL,
  ServiceURLParser,
  UrlPreflightResult
} from './UrlPreflight';
import { shouldDisableThinking } from './ChatRequestCompatibility';
import { chooseChallenge, VisionChallenge } from './VisionChallenges';

interface ChatContentPart {
  type: string;
  text?: string;
  image_url?: ChatImageURL;
}

interface ChatImageURL {
  url: string;
}

interface ChatMessage {
  role: string;
  content: ChatContentPart[];
}

interface ChatCompletionRequestBody {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  max_tokens: number;
  enable_thinking?: boolean;
}

interface CompletionTextPart {
  type?: string;
  text?: string;
}

interface CompletionMessage {
  content?: string | CompletionTextPart[];
}

interface CompletionChoice {
  message?: CompletionMessage;
}

interface CompletionResponse {
  choices?: CompletionChoice[];
}

const REQUEST_TIMEOUT_MS: number = 15000;

export class VisionVerificationGate {
  private readonly transport: HttpTransport;
  private readonly randomSource: () => number;
  private readonly urlParser: ServiceURLParser;

  constructor(transport: HttpTransport, randomSource: () => number = Math.random,
    urlParser: ServiceURLParser = new HarmonyServiceURLParser()) {
    this.transport = transport;
    this.randomSource = randomSource;
    this.urlParser = urlParser;
  }

  async verify(candidate: VerificationCandidate,
    confirmations: VerificationConfirmations): Promise<VerificationSuccess> {
    if (candidate.apiKey.length === 0 || candidate.model.trim().length === 0) {
      throw new VerificationError(
        VerificationErrorCategory.ADDRESS,
        'Base URL、API Key 和 Model ID 必须填写完整。'
      );
    }

    const target: UrlPreflightResult = preflightURL(candidate.baseURL, confirmations, this.urlParser);
    const challenge: VisionChallenge = chooseChallenge(this.randomSource());
    const request: HttpTransportRequest = {
      url: target.endpointURL,
      apiKey: candidate.apiKey,
      body: this.buildRequestBody(candidate.model.trim(), challenge, target.origin),
      timeoutMs: REQUEST_TIMEOUT_MS
    };

    let response: HttpTransportResponse;
    try {
      response = await this.transport.send(request);
    } catch (error) {
      if (error instanceof TransportError) {
        const detail: string = error.kind === TransportErrorKind.TIMEOUT ? '连接模型服务超时，请稍后重试。' :
          '无法连接模型服务，请检查网络、DNS 或代理设置。';
        throw new VerificationError(VerificationErrorCategory.NETWORK, detail);
      }
      throw new VerificationError(
        VerificationErrorCategory.NETWORK,
        '无法连接模型服务，请检查网络后重试。'
      );
    } finally {
      request.apiKey = '';
    }

    this.ensureSuccessfulStatus(response);
    const answer: string = this.extractAnswer(response.body);
    if (answer.trim().toUpperCase() !== challenge.expectedAnswer) {
      throw new VerificationError(
        VerificationErrorCategory.VISION,
        '模型没有正确回答视觉挑战。请改用支持图片输入的多模态模型，例如 GPT-4.1、Qwen VL 或 GLM-4.6V。'
      );
    }

    return {
      normalizedBaseURL: target.normalizedBaseURL,
      trustedOrigin: target.origin,
      challengeId: challenge.id
    };
  }

  private buildRequestBody(model: string, challenge: VisionChallenge, origin: string): string {
    const textPart: ChatContentPart = { type: 'text', text: challenge.prompt };
    const imagePart: ChatContentPart = {
      type: 'image_url',
      image_url: { url: challenge.imageDataURL }
    };
    const message: ChatMessage = { role: 'user', content: [textPart, imagePart] };
    const body: ChatCompletionRequestBody = {
      model: model,
      messages: [message],
      temperature: 0,
      max_tokens: 12
    };
    if (shouldDisableThinking(origin, model)) {
      body.enable_thinking = false;
    }
    return JSON.stringify(body);
  }

  private ensureSuccessfulStatus(response: HttpTransportResponse): void {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    if (response.statusCode === 401 || response.statusCode === 403) {
      throw new VerificationError(
        VerificationErrorCategory.AUTHENTICATION,
        '认证未通过，请检查 API Key、账号权限或套餐状态。'
      );
    }
    if (response.statusCode === 404 || response.statusCode === 405) {
      throw new VerificationError(
        VerificationErrorCategory.ADDRESS,
        '未找到 Chat Completions 接口，请检查 Base URL 是否包含正确的服务根路径。'
      );
    }

    const body: string = response.body.toLowerCase();
    const mentionsImage: boolean = body.includes('image') || body.includes('vision') || body.includes('multimodal');
    const rejectsCapability: boolean = body.includes('not support') || body.includes('unsupported') ||
      body.includes('cannot') || body.includes('does not accept') || body.includes('拒绝') || body.includes('不支持');
    if (response.statusCode >= 400 && response.statusCode < 500 && mentionsImage && rejectsCapability) {
      throw new VerificationError(
        VerificationErrorCategory.VISION,
        '服务明确拒绝了图片输入。请改用支持视觉理解的模型 ID。'
      );
    }

    throw new VerificationError(
      VerificationErrorCategory.SERVICE,
      response.statusCode >= 500 ? '模型服务暂时不可用，请稍后重试。' :
        `模型服务拒绝了请求（HTTP ${response.statusCode}），请检查账号权限、模型 ID 与服务条款。`
    );
  }

  private extractAnswer(body: string): string {
    let parsed: CompletionResponse;
    try {
      parsed = JSON.parse(body) as CompletionResponse;
    } catch (_error) {
      throw new VerificationError(
        VerificationErrorCategory.RESPONSE,
        '服务返回的不是合法 JSON，当前接口可能不兼容 OpenAI Chat Completions。'
      );
    }

    if (!Array.isArray(parsed.choices) || parsed.choices.length === 0 || parsed.choices[0].message === undefined) {
      throw new VerificationError(
        VerificationErrorCategory.RESPONSE,
        '响应缺少 choices 或 message，当前接口格式不兼容。'
      );
    }
    const content: string | CompletionTextPart[] | undefined = parsed.choices[0].message?.content;
    if (typeof content === 'string') {
      if (content.trim().length === 0) {
        throw new VerificationError(VerificationErrorCategory.RESPONSE, '响应中的 content 为空。');
      }
      return content.trim();
    }
    if (Array.isArray(content) && content.length > 0) {
      let combined: string = '';
      for (const part of content) {
        if (typeof part.text !== 'string') {
          throw new VerificationError(
            VerificationErrorCategory.RESPONSE,
            '响应的文本数组缺少 text 字段，当前接口格式不兼容。'
          );
        }
        combined += part.text;
      }
      if (combined.trim().length > 0) {
        return combined.trim();
      }
    }
    throw new VerificationError(
      VerificationErrorCategory.RESPONSE,
      '响应缺少可读取的 message.content，当前接口格式不兼容。'
    );
  }
}
