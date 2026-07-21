import { describe, expect, it } from '@ohos/hypium';
import {
  ConfigState,
  EncryptedSecret,
  RuntimeModelConfig,
  StoredConfigEnvelope
} from '../main/ets/models/ModelConfig';
import { ConfigRepository } from '../main/ets/services/ConfigRepository';
import { KeyValueStore, SecretCipher } from '../main/ets/services/ConfigStoragePorts';
import { isMissingHuksEntity } from '../main/ets/services/HuksErrorPolicy';

class FakeCipher implements SecretCipher {
  failEncrypt: boolean = false;
  failDecrypt: boolean = false;

  async encrypt(plainText: string): Promise<EncryptedSecret> {
    if (this.failEncrypt) {
      throw new Error('injected encryption failure');
    }
    return {
      cryptoVersion: 1,
      nonceBase64: 'bm9uY2U=',
      cipherBlobBase64: `cipher:${plainText.split('').reverse().join('')}`
    };
  }

  async decrypt(secret: EncryptedSecret): Promise<string> {
    if (this.failDecrypt || !secret.cipherBlobBase64.startsWith('cipher:')) {
      throw new Error('injected decryption failure');
    }
    return secret.cipherBlobBase64.substring('cipher:'.length).split('').reverse().join('');
  }
}

class FakeStore implements KeyValueStore {
  readonly values: Map<string, string> = new Map<string, string>();
  flushCount: number = 0;
  failFlushAt: number = -1;

  async getString(key: string): Promise<string> {
    return this.values.get(key) ?? '';
  }

  async putString(key: string, value: string): Promise<void> {
    this.values.set(key, value);
  }

  async flush(): Promise<void> {
    this.flushCount += 1;
    if (this.flushCount === this.failFlushAt) {
      throw new Error('injected flush failure');
    }
  }
}

function config(baseURL: string, apiKey: string, model: string): RuntimeModelConfig {
  return {
    baseURL: baseURL,
    apiKey: apiKey,
    model: model,
    verifiedAt: 100,
    verificationProtocolVersion: 1,
    trustedOrigin: 'https://example.com:443'
  };
}

export default function configRepositoryTest() {
  describe('ConfigRepository', () => {
    it('recognizes the HUKS missing-key error used during first setup', 0, () => {
      expect(isMissingHuksEntity(12000011)).assertTrue();
      expect(isMissingHuksEntity(12000012)).assertFalse();
    });

    it('reports unconfigured before first commit', 0, async () => {
      const repository: ConfigRepository = new ConfigRepository(new FakeStore(), new FakeCipher());
      expect(await repository.getState()).assertEqual(ConfigState.UNCONFIGURED);
    });

    it('commits and reads a verified configuration without plain-text persistence', 0, async () => {
      const store: FakeStore = new FakeStore();
      const repository: ConfigRepository = new ConfigRepository(store, new FakeCipher());
      await repository.replaceVerified(config('https://example.com/v1', 'sentinel-secret', 'vision-model'));

      expect(await repository.getState()).assertEqual(ConfigState.VERIFIED);
      expect(JSON.stringify(Array.from(store.values.values())).includes('sentinel-secret')).assertFalse();
      const model: string = await repository.withVerifiedConfig(async (runtime: RuntimeModelConfig) => runtime.model);
      expect(model).assertEqual('vision-model');
    });

    it('keeps the old slot active when candidate encryption fails', 0, async () => {
      const store: FakeStore = new FakeStore();
      const cipher: FakeCipher = new FakeCipher();
      const repository: ConfigRepository = new ConfigRepository(store, cipher);
      await repository.replaceVerified(config('https://old.example/v1', 'old-secret', 'old-model'));
      cipher.failEncrypt = true;

      try {
        await repository.replaceVerified(config('https://new.example/v1', 'new-secret', 'new-model'));
      } catch (_error) {
      }

      const model: string = await repository.withVerifiedConfig(async (runtime: RuntimeModelConfig) => runtime.model);
      expect(model).assertEqual('old-model');
    });

    it('restores the old active pointer when activation flush fails', 0, async () => {
      const store: FakeStore = new FakeStore();
      const repository: ConfigRepository = new ConfigRepository(store, new FakeCipher());
      await repository.replaceVerified(config('https://old.example/v1', 'old-secret', 'old-model'));
      store.failFlushAt = store.flushCount + 2;

      try {
        await repository.replaceVerified(config('https://new.example/v1', 'new-secret', 'new-model'));
      } catch (_error) {
      }

      const model: string = await repository.withVerifiedConfig(async (runtime: RuntimeModelConfig) => runtime.model);
      expect(model).assertEqual('old-model');
    });

    it('marks invalid active data as corrupted', 0, async () => {
      const store: FakeStore = new FakeStore();
      store.values.set('activeSlot', 'A');
      store.values.set('configSlotA', '{broken');
      const repository: ConfigRepository = new ConfigRepository(store, new FakeCipher());
      expect(await repository.getState()).assertEqual(ConfigState.CORRUPTED);
    });

    it('marks a HUKS-equivalent decryption failure as corrupted', 0, async () => {
      const store: FakeStore = new FakeStore();
      const cipher: FakeCipher = new FakeCipher();
      const repository: ConfigRepository = new ConfigRepository(store, cipher);
      await repository.replaceVerified(config('https://example.com/v1', 'device-key', 'vision-model'));
      cipher.failDecrypt = true;

      expect(await repository.getState()).assertEqual(ConfigState.CORRUPTED);
    });

    it('marks an incompatible stored schema as corrupted', 0, async () => {
      const store: FakeStore = new FakeStore();
      const repository: ConfigRepository = new ConfigRepository(store, new FakeCipher());
      await repository.replaceVerified(config('https://example.com/v1', 'device-key', 'vision-model'));
      const active: string = await store.getString('activeSlot');
      const slotKey: string = active === 'A' ? 'configSlotA' : 'configSlotB';
      const envelope: StoredConfigEnvelope = JSON.parse(await store.getString(slotKey)) as StoredConfigEnvelope;
      envelope.schemaVersion = 999;
      await store.putString(slotKey, JSON.stringify(envelope));

      expect(await repository.getState()).assertEqual(ConfigState.CORRUPTED);
    });
  });
}
