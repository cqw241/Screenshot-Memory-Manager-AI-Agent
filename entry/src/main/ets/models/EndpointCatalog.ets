import { url } from '@kit.ArkTS';

export interface EndpointTemplate {
  label: string;
  baseURL: string;
}

export interface ModelSuggestion {
  label: string;
  model: string;
}

export const MULTIMODAL_ENDPOINTS: EndpointTemplate[] = [
  { label: 'OpenAI', baseURL: 'https://api.openai.com/v1' },
  { label: '阿里云百炼', baseURL: 'https://dashscope.aliyuncs.com/compatible-mode/v1' },
  { label: '火山方舟', baseURL: 'https://ark.cn-beijing.volces.com/api/v3' },
  { label: '小米 MiMo', baseURL: 'https://api.xiaomimimo.com/v1' },
  { label: '智谱开放平台', baseURL: 'https://open.bigmodel.cn/api/paas/v4' },
  { label: 'Kimi 开放平台', baseURL: 'https://api.moonshot.cn/v1' },
  { label: '腾讯混元', baseURL: 'https://api.hunyuan.cloud.tencent.com/v1' },
  { label: 'MiniMax', baseURL: 'https://api.minimax.io/v1' }
];

export const CODING_ENDPOINTS: EndpointTemplate[] = [
  { label: '阿里云 Coding Plan', baseURL: 'https://coding.dashscope.aliyuncs.com/v1' },
  { label: '火山方舟 Coding Plan', baseURL: 'https://ark.cn-beijing.volces.com/api/coding/v3' },
  { label: 'MiMo Token Plan（中国）', baseURL: 'https://token-plan-cn.xiaomimimo.com/v1' },
  { label: '智谱 Coding Plan', baseURL: 'https://open.bigmodel.cn/api/coding/paas/v4' },
  { label: 'Kimi Code', baseURL: 'https://api.kimi.com/coding/v1' },
  { label: '腾讯云 Coding Plan', baseURL: 'https://api.lkeap.cloud.tencent.com/coding/v3' }
];

// 最近依据厂商官方模型/API 文档核对：2026-07-21。建议仅用于减少输入成本，最终能力以视觉挑战为准。
export const RECOMMENDED_MODELS: ModelSuggestion[] = [
  { label: 'OpenAI · GPT-4.1', model: 'gpt-4.1' },
  { label: '百炼 · Qwen VL Plus', model: 'qwen-vl-plus' },
  { label: '火山 · Doubao Vision', model: 'doubao-1.5-vision-pro' },
  { label: '智谱 · GLM-4.6V', model: 'glm-4.6v' }
];

export function isKnownOfficialOrigin(rawURL: string): boolean {
  try {
    const candidate: url.URL = url.URL.parseURL(rawURL.trim());
    return MULTIMODAL_ENDPOINTS.concat(CODING_ENDPOINTS).some((template: EndpointTemplate) => {
      return url.URL.parseURL(template.baseURL).origin === candidate.origin;
    });
  } catch (_error) {
    return false;
  }
}

export function targetHost(rawURL: string): string {
  try {
    return url.URL.parseURL(rawURL.trim()).hostname;
  } catch (_error) {
    return rawURL.trim().length > 0 ? rawURL.trim() : '尚未填写';
  }
}

export function isLoopbackHttpOrigin(rawURL: string): boolean {
  try {
    const parsed: url.URL = url.URL.parseURL(rawURL.trim());
    const host: string = parsed.hostname.toLowerCase();
    return parsed.protocol === 'http:' &&
      (host === 'localhost' || host === '127.0.0.1' || host === '[::1]' || host === '::1');
  } catch (_error) {
    return false;
  }
}
