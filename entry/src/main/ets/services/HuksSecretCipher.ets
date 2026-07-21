import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { huks } from '@kit.UniversalKeystoreKit';
import { EncryptedSecret } from '../models/ModelConfig';
import { SecretCipher } from './ConfigStoragePorts';
import { isMissingHuksEntity } from './HuksErrorPolicy';

const KEY_ALIAS: string = 'com.shiguang.memory.model-config.aes-gcm.v1';
const CRYPTO_VERSION: number = 1;
const NONCE_LENGTH: number = 12;
const AUTH_TAG_LENGTH: number = 16;
const ASSOCIATED_DATA: string = 'com.shiguang.memory:model-config:v1';

export class HuksSecretCipher implements SecretCipher {
  private readonly base64: util.Base64Helper = new util.Base64Helper();
  private readonly encoder: util.TextEncoder = new util.TextEncoder();
  private readonly decoder: util.TextDecoder = new util.TextDecoder();

  async encrypt(plainText: string): Promise<EncryptedSecret> {
    await this.ensureKey();
    const nonce: Uint8Array = (await cryptoFramework.createRandom().generateRandom(NONCE_LENGTH)).data;
    const plainBytes: Uint8Array = this.encoder.encodeInto(plainText);
    const options: huks.HuksOptions = {
      properties: this.cryptoProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT, nonce),
      inData: plainBytes
    };

    try {
      const session: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, options);
      const result: huks.HuksReturnResult = await huks.finishSession(session.handle, options);
      if (result.outData === undefined || result.outData.length <= AUTH_TAG_LENGTH) {
        throw new Error('HUKS encryption returned no authenticated cipher text');
      }
      return {
        cryptoVersion: CRYPTO_VERSION,
        nonceBase64: this.base64.encodeToStringSync(nonce),
        cipherBlobBase64: this.base64.encodeToStringSync(result.outData)
      };
    } finally {
      plainBytes.fill(0);
    }
  }

  async decrypt(secret: EncryptedSecret): Promise<string> {
    if (secret.cryptoVersion !== CRYPTO_VERSION) {
      throw new Error('Unsupported encrypted secret version');
    }
    await this.ensureKey();

    const nonce: Uint8Array = this.base64.decodeSync(secret.nonceBase64);
    const cipherBlob: Uint8Array = this.base64.decodeSync(secret.cipherBlobBase64);
    if (nonce.length !== NONCE_LENGTH || cipherBlob.length <= AUTH_TAG_LENGTH) {
      throw new Error('Encrypted secret metadata is invalid');
    }

    const cipherText: Uint8Array = cipherBlob.slice(0, cipherBlob.length - AUTH_TAG_LENGTH);
    const authTag: Uint8Array = cipherBlob.slice(cipherBlob.length - AUTH_TAG_LENGTH);
    const options: huks.HuksOptions = {
      properties: this.cryptoProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT, nonce, authTag),
      inData: cipherText
    };

    try {
      const session: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, options);
      const result: huks.HuksReturnResult = await huks.finishSession(session.handle, options);
      if (result.outData === undefined) {
        throw new Error('HUKS decryption returned no data');
      }
      return this.decoder.decodeToString(result.outData);
    } finally {
      cipherText.fill(0);
      authTag.fill(0);
      cipherBlob.fill(0);
    }
  }

  private async ensureKey(): Promise<void> {
    const emptyOptions: huks.HuksOptions = { properties: [] };
    if (await this.keyExists(emptyOptions)) {
      return;
    }
    const options: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT |
            huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
        }
      ]
    };
    try {
      await huks.generateKeyItem(KEY_ALIAS, options);
    } catch (error) {
      if (!(await this.keyExists(emptyOptions))) {
        throw error as Error;
      }
    }
  }

  private async keyExists(options: huks.HuksOptions): Promise<boolean> {
    try {
      return await huks.isKeyItemExist(KEY_ALIAS, options);
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      if (isMissingHuksEntity(businessError.code)) {
        return false;
      }
      throw error as Error;
    }
  }

  private cryptoProperties(purpose: huks.HuksKeyPurpose, nonce: Uint8Array,
    authTag?: Uint8Array): huks.HuksParam[] {
    const properties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
      { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: this.encoder.encodeInto(ASSOCIATED_DATA) }
    ];
    if (authTag !== undefined) {
      properties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: authTag });
    }
    return properties;
  }
}
