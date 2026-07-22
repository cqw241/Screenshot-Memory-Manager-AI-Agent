const DASHSCOPE_ORIGIN: string = 'https://dashscope.aliyuncs.com';
const DASHSCOPE_ORIGIN_SUFFIX: string = '.dashscope.aliyuncs.com';
const ALIBABA_MAAS_ORIGIN_SUFFIX: string = '.maas.aliyuncs.com';
const SILICONFLOW_ORIGINS: string[] = [
  'https://api.siliconflow.cn',
  'https://api.siliconflow.com'
];
const TENCENT_TOKENHUB_ORIGIN: string = 'https://tokenhub.tencentmaas.com';

const DASHSCOPE_EXACT_HYBRID_MODELS: string[] = [
  'qwen3.6-35b-a3b',
  'qwen3.5-397b-a17b',
  'qwen3.5-122b-a10b',
  'qwen3.5-27b',
  'qwen3.5-35b-a3b',
  'qwen3-235b-a22b',
  'qwen3-32b',
  'qwen3-30b-a3b',
  'qwen3-14b',
  'qwen3-8b',
  'stepfun/step-3.7-flash',
  'deepseek-v4-pro',
  'deepseek-v4-flash',
  'deepseek-v3.2',
  'deepseek-v3.2-exp',
  'deepseek-v3.1',
  'siliconflow/deepseek-v3.2',
  'siliconflow/deepseek-v3.1-terminus',
  'vanchin/deepseek-v3.2-think',
  'vanchin/deepseek-v3.1-terminus',
  'glm-5.2',
  'glm-5.2-us',
  'glm-5.2-fast-preview',
  'glm-5.1',
  'glm-5',
  'glm-4.7',
  'glm-4.6',
  'glm-4.5',
  'glm-4.5-air',
  'kimi-k2.6',
  'kimi-k2.5',
  'kimi/kimi-k2.6',
  'kimi/kimi-k2.5'
];

const SILICONFLOW_HYBRID_MODELS: string[] = [
  'pro/zai-org/glm-5',
  'pro/zai-org/glm-4.7',
  'deepseek-ai/deepseek-v3.2',
  'pro/deepseek-ai/deepseek-v3.2',
  'zai-org/glm-4.6',
  'qwen/qwen3-8b',
  'qwen/qwen3-14b',
  'qwen/qwen3-32b',
  'qwen/qwen3-30b-a3b',
  'tencent/hunyuan-a13b-instruct',
  'zai-org/glm-4.5v',
  'deepseek-ai/deepseek-v3.1-terminus',
  'pro/deepseek-ai/deepseek-v3.1-terminus',
  'qwen/qwen3.5-397b-a17b',
  'qwen/qwen3.5-122b-a10b',
  'qwen/qwen3.5-35b-a3b',
  'qwen/qwen3.5-27b',
  'qwen/qwen3.5-9b',
  'qwen/qwen3.5-4b'
];

function matchesFamily(model: string, family: string): boolean {
  return model === family || model.startsWith(family + '-');
}

function isDashScopeOrigin(origin: string): boolean {
  return origin === DASHSCOPE_ORIGIN || origin.endsWith(DASHSCOPE_ORIGIN_SUFFIX) ||
    origin.endsWith(ALIBABA_MAAS_ORIGIN_SUFFIX);
}

function isDashScopeHybridModel(model: string): boolean {
  if (model === 'qwen3.7-max-preview' || model === 'qwen3.7-max-2026-05-17') {
    return false;
  }
  if (DASHSCOPE_EXACT_HYBRID_MODELS.includes(model)) {
    return true;
  }
  return matchesFamily(model, 'qwen3.7-max') || matchesFamily(model, 'qwen3.7-plus') ||
    matchesFamily(model, 'qwen3.6-max-preview') || matchesFamily(model, 'qwen3.6-plus') ||
    matchesFamily(model, 'qwen3.6-flash') || matchesFamily(model, 'qwen3.5-plus') ||
    matchesFamily(model, 'qwen3.5-flash') || matchesFamily(model, 'qwen3-max') ||
    matchesFamily(model, 'qwen-plus') || matchesFamily(model, 'qwen-flash') ||
    matchesFamily(model, 'qwen-turbo');
}

export function shouldDisableThinking(origin: string, model: string): boolean {
  const normalizedOrigin: string = origin.trim().toLowerCase();
  const normalizedModel: string = model.trim().toLowerCase();
  if (isDashScopeOrigin(normalizedOrigin)) {
    return isDashScopeHybridModel(normalizedModel);
  }
  if (SILICONFLOW_ORIGINS.includes(normalizedOrigin)) {
    return SILICONFLOW_HYBRID_MODELS.includes(normalizedModel);
  }
  if (normalizedOrigin === TENCENT_TOKENHUB_ORIGIN) {
    return normalizedModel === 'qwen3.5-plus' || normalizedModel === 'qwen3.5-flash';
  }
  return false;
}
