import { common } from '@kit.AbilityKit';
import { ConfigRepository } from './ConfigRepository';
import { HuksSecretCipher } from './HuksSecretCipher';
import { PreferencesKeyValueStore } from './PreferencesKeyValueStore';

export function createConfigRepository(context: common.Context): ConfigRepository {
  return new ConfigRepository(new PreferencesKeyValueStore(context), new HuksSecretCipher());
}
