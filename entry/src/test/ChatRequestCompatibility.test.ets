import { describe, expect, it } from '@ohos/hypium';
import { shouldDisableThinking } from '../main/ets/services/ChatRequestCompatibility';

export default function chatRequestCompatibilityTest() {
  describe('ChatRequestCompatibility', () => {
    it('supports DashScope hybrid-thinking model families', 0, () => {
      const origin: string = 'https://dashscope.aliyuncs.com';

      expect(shouldDisableThinking(origin, 'qwen3.7-plus')).assertTrue();
      expect(shouldDisableThinking(origin, 'qwen3.7-max-2026-06-08')).assertTrue();
      expect(shouldDisableThinking(origin, 'qwen3.5-flash')).assertTrue();
      expect(shouldDisableThinking(origin, 'qwen-plus-latest')).assertTrue();
      expect(shouldDisableThinking(origin, 'deepseek-v3.2')).assertTrue();
      expect(shouldDisableThinking(origin, 'glm-5.2')).assertTrue();
      expect(shouldDisableThinking(origin, 'stepfun/step-3.7-flash')).assertTrue();
      expect(shouldDisableThinking(origin, 'kimi-k2.6')).assertTrue();
    });

    it('rejects DashScope thinking-only and unknown models', 0, () => {
      const origin: string = 'https://dashscope.aliyuncs.com';

      expect(shouldDisableThinking(origin, 'qwen3.8-max-preview')).assertFalse();
      expect(shouldDisableThinking(origin, 'qwen3.7-max-preview')).assertFalse();
      expect(shouldDisableThinking(origin, 'qwen3-235b-a22b-thinking-2507')).assertFalse();
      expect(shouldDisableThinking(origin, 'deepseek-r1')).assertFalse();
      expect(shouldDisableThinking(origin, 'kimi-k2.7-code')).assertFalse();
      expect(shouldDisableThinking(origin, 'MiniMax-M2.5')).assertFalse();
      expect(shouldDisableThinking(origin, 'unpublished-model')).assertFalse();
    });

    it('supports documented SiliconFlow switchable models only', 0, () => {
      const origin: string = 'https://api.siliconflow.cn';

      expect(shouldDisableThinking(origin, 'Pro/zai-org/GLM-5')).assertTrue();
      expect(shouldDisableThinking(origin, 'deepseek-ai/DeepSeek-V3.2')).assertTrue();
      expect(shouldDisableThinking(origin, 'Qwen/Qwen3.5-27B')).assertTrue();
      expect(shouldDisableThinking(origin, 'MiniMaxAI/MiniMax-M2')).assertFalse();
    });

    it('supports documented Tencent TokenHub Qwen models', 0, () => {
      const origin: string = 'https://tokenhub.tencentmaas.com';

      expect(shouldDisableThinking(origin, 'qwen3.5-plus')).assertTrue();
      expect(shouldDisableThinking(origin, 'qwen3.5-flash')).assertTrue();
      expect(shouldDisableThinking(origin, 'hunyuan-turbos-latest')).assertFalse();
    });

    it('does not send vendor extensions to unknown or standard OpenAI origins', 0, () => {
      expect(shouldDisableThinking('https://api.openai.com', 'qwen3.7-plus')).assertFalse();
      expect(shouldDisableThinking('https://api.example.com', 'Qwen/Qwen3.5-27B')).assertFalse();
    });
  });
}
