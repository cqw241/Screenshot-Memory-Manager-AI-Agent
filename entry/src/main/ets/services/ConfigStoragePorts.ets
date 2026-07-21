import { EncryptedSecret } from '../models/ModelConfig';

export interface SecretCipher {
  encrypt(plainText: string): Promise<EncryptedSecret>;
  decrypt(secret: EncryptedSecret): Promise<string>;
}

export interface KeyValueStore {
  getString(key: string): Promise<string>;
  putString(key: string, value: string): Promise<void>;
  flush(): Promise<void>;
}
