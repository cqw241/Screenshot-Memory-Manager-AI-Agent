import { url } from '@kit.ArkTS';
import { OFFICIAL_ORIGINS } from '../models/EndpointCatalog';
import {
  VerificationConfirmations,
  VerificationError,
  VerificationErrorCategory
} from '../models/VerificationModels';

export interface UrlPreflightResult {
  normalizedBaseURL: string;
  endpointURL: string;
  origin: string;
  hostname: string;
  isOfficial: boolean;
  isLoopbackHttp: boolean;
}

export interface ParsedServiceURL {
  protocol: string;
  hostname: string;
  username: string;
  password: string;
  search: string;
  hash: string;
  origin: string;
  serialized: string;
}

export interface ServiceURLParser {
  parse(rawURL: string): ParsedServiceURL;
}

export class HarmonyServiceURLParser implements ServiceURLParser {
  parse(rawURL: string): ParsedServiceURL {
    try {
      const parsed: url.URL = url.URL.parseURL(rawURL);
      return {
        protocol: parsed.protocol,
        hostname: parsed.hostname,
        username: parsed.username,
        password: parsed.password,
        search: parsed.search,
        hash: parsed.hash,
        origin: parsed.origin,
        serialized: parsed.toString()
      };
    } catch (error) {
      throw error as Error;
    }
  }
}

export function parseOrigin(rawURL: string): string {
  try {
    return url.URL.parseURL(rawURL.trim()).origin;
  } catch (_error) {
    return '';
  }
}

export function preflightURL(rawURL: string, confirmations: VerificationConfirmations,
  parser: ServiceURLParser = new HarmonyServiceURLParser()): UrlPreflightResult {
  let parsed: ParsedServiceURL;
  try {
    parsed = parser.parse(rawURL.trim());
  } catch (_error) {
    throw new VerificationError(
      VerificationErrorCategory.ADDRESS,
      'Base URL 无法解析，请填写完整的 http:// 或 https:// 地址。'
    );
  }

  const protocol: string = parsed.protocol.toLowerCase();
  const hostname: string = parsed.hostname.toLowerCase();
  if ((protocol !== 'https:' && protocol !== 'http:') || hostname.length === 0 ||
    parsed.username.length > 0 || parsed.password.length > 0 || parsed.search.length > 0 || parsed.hash.length > 0) {
    throw new VerificationError(
      VerificationErrorCategory.ADDRESS,
      'Base URL 必须是无账号、查询参数和片段的 HTTP(S) 服务根地址。'
    );
  }

  const loopback: boolean = hostname === 'localhost' || hostname === '127.0.0.1' ||
    hostname === '[::1]' || hostname === '::1';
  if (protocol === 'http:' && !loopback) {
    throw new VerificationError(
      VerificationErrorCategory.ADDRESS,
      '远程服务必须使用 HTTPS；为保护 API Key，已在发送请求前停止。'
    );
  }
  if (protocol === 'http:' && loopback && !confirmations.loopbackHttpAccepted) {
    throw new VerificationError(
      VerificationErrorCategory.TRUST,
      '请先确认本地 HTTP 连接未加密的风险。'
    );
  }

  const official: boolean = OFFICIAL_ORIGINS.includes(parsed.origin);
  if (!official && !loopback && !confirmations.customOriginTrusted) {
    throw new VerificationError(
      VerificationErrorCategory.TRUST,
      `请先确认信任服务源 ${hostname}，再发送 API Key 与挑战图。`
    );
  }

  let normalized: string = parsed.serialized;
  const fragmentAt: number = normalized.indexOf('#');
  if (fragmentAt >= 0) {
    normalized = normalized.substring(0, fragmentAt);
  }
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }

  return {
    normalizedBaseURL: normalized,
    endpointURL: `${normalized}/chat/completions`,
    origin: parsed.origin,
    hostname: hostname,
    isOfficial: official,
    isLoopbackHttp: protocol === 'http:' && loopback
  };
}
