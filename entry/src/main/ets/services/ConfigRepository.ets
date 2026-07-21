import {
  ConfigState,
  RuntimeModelConfig,
  StoredConfigEnvelope,
  VerifiedConfigMetadata
} from '../models/ModelConfig';
import { KeyValueStore, SecretCipher } from './ConfigStoragePorts';

const ACTIVE_SLOT_KEY: string = 'activeSlot';
const SLOT_A_KEY: string = 'configSlotA';
const SLOT_B_KEY: string = 'configSlotB';
const SCHEMA_VERSION: number = 1;
const VERIFICATION_PROTOCOL_VERSION: number = 1;

enum ConfigSlot {
  A = 'A',
  B = 'B'
}

interface LoadedConfig {
  envelope: StoredConfigEnvelope;
  apiKey: string;
}

export class ConfigRepository {
  private readonly store: KeyValueStore;
  private readonly cipher: SecretCipher;

  constructor(store: KeyValueStore, cipher: SecretCipher) {
    this.store = store;
    this.cipher = cipher;
  }

  async getState(): Promise<ConfigState> {
    try {
      const active: string = await this.store.getString(ACTIVE_SLOT_KEY);
      if (active.length === 0) {
        return ConfigState.UNCONFIGURED;
      }
      await this.loadActive(active);
      return ConfigState.VERIFIED;
    } catch (_error) {
      return ConfigState.CORRUPTED;
    }
  }

  async getMetadata(): Promise<VerifiedConfigMetadata | undefined> {
    const active: string = await this.store.getString(ACTIVE_SLOT_KEY);
    if (active.length === 0) {
      return undefined;
    }
    const loaded: LoadedConfig = await this.loadActive(active);
    loaded.apiKey = '';
    return {
      baseURL: loaded.envelope.baseURL,
      model: loaded.envelope.model,
      verifiedAt: loaded.envelope.verifiedAt,
      verificationProtocolVersion: loaded.envelope.verificationProtocolVersion,
      trustedOrigin: loaded.envelope.trustedOrigin
    };
  }

  async withVerifiedConfig<T>(action: (config: RuntimeModelConfig) => Promise<T>): Promise<T> {
    const active: string = await this.store.getString(ACTIVE_SLOT_KEY);
    if (active.length === 0) {
      throw new Error('No verified model configuration');
    }
    const loaded: LoadedConfig = await this.loadActive(active);
    const runtime: RuntimeModelConfig = {
      baseURL: loaded.envelope.baseURL,
      apiKey: loaded.apiKey,
      model: loaded.envelope.model,
      verifiedAt: loaded.envelope.verifiedAt,
      verificationProtocolVersion: loaded.envelope.verificationProtocolVersion,
      trustedOrigin: loaded.envelope.trustedOrigin
    };
    try {
      return await action(runtime);
    } finally {
      runtime.apiKey = '';
      loaded.apiKey = '';
    }
  }

  async replaceVerified(config: RuntimeModelConfig): Promise<void> {
    if (config.baseURL.trim().length === 0 || config.apiKey.length === 0 || config.model.trim().length === 0) {
      throw new Error('Verified configuration is incomplete');
    }

    const oldActive: string = await this.store.getString(ACTIVE_SLOT_KEY);
    const nextSlot: ConfigSlot = oldActive === ConfigSlot.A ? ConfigSlot.B : ConfigSlot.A;
    const envelope: StoredConfigEnvelope = {
      schemaVersion: SCHEMA_VERSION,
      verified: true,
      baseURL: config.baseURL,
      model: config.model,
      verifiedAt: config.verifiedAt,
      verificationProtocolVersion: VERIFICATION_PROTOCOL_VERSION,
      trustedOrigin: config.trustedOrigin,
      secret: await this.cipher.encrypt(config.apiKey)
    };

    await this.store.putString(this.slotKey(nextSlot), JSON.stringify(envelope));
    await this.store.flush();

    const stagedRaw: string = await this.store.getString(this.slotKey(nextSlot));
    const staged: StoredConfigEnvelope = this.parseEnvelope(stagedRaw);
    let stagedKey: string = await this.cipher.decrypt(staged.secret);
    if (stagedKey.length === 0) {
      throw new Error('Staged API Key cannot be decrypted');
    }
    stagedKey = '';

    try {
      await this.store.putString(ACTIVE_SLOT_KEY, nextSlot);
      await this.store.flush();
    } catch (error) {
      await this.store.putString(ACTIVE_SLOT_KEY, oldActive);
      await this.store.flush();
      throw error as Error;
    }
  }

  private async loadActive(active: string): Promise<LoadedConfig> {
    if (active !== ConfigSlot.A && active !== ConfigSlot.B) {
      throw new Error('Active configuration slot is invalid');
    }
    const raw: string = await this.store.getString(this.slotKey(active as ConfigSlot));
    const envelope: StoredConfigEnvelope = this.parseEnvelope(raw);
    const apiKey: string = await this.cipher.decrypt(envelope.secret);
    if (apiKey.length === 0) {
      throw new Error('Stored API Key is empty');
    }
    return { envelope: envelope, apiKey: apiKey };
  }

  private parseEnvelope(raw: string): StoredConfigEnvelope {
    if (raw.length === 0) {
      throw new Error('Configuration slot is empty');
    }
    const envelope: StoredConfigEnvelope = JSON.parse(raw) as StoredConfigEnvelope;
    if (envelope.schemaVersion !== SCHEMA_VERSION || envelope.verified !== true ||
      typeof envelope.baseURL !== 'string' || envelope.baseURL.length === 0 ||
      typeof envelope.model !== 'string' || envelope.model.length === 0 ||
      typeof envelope.verifiedAt !== 'number' ||
      envelope.verificationProtocolVersion !== VERIFICATION_PROTOCOL_VERSION ||
      typeof envelope.trustedOrigin !== 'string' || envelope.secret === undefined ||
      envelope.secret.cryptoVersion !== 1 || typeof envelope.secret.nonceBase64 !== 'string' ||
      typeof envelope.secret.cipherBlobBase64 !== 'string') {
      throw new Error('Stored model configuration is invalid');
    }
    return envelope;
  }

  private slotKey(slot: ConfigSlot): string {
    return slot === ConfigSlot.A ? SLOT_A_KEY : SLOT_B_KEY;
  }
}
