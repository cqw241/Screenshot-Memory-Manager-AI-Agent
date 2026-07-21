export enum ConfigState {
  UNCONFIGURED = 'UNCONFIGURED',
  VERIFIED = 'VERIFIED',
  CORRUPTED = 'CORRUPTED'
}

export interface ModelConfigDraft {
  baseURL: string;
  apiKey: string;
  model: string;
}

export interface VerifiedConfigMetadata {
  baseURL: string;
  model: string;
  verifiedAt: number;
  verificationProtocolVersion: number;
  trustedOrigin: string;
}

export interface RuntimeModelConfig extends VerifiedConfigMetadata {
  apiKey: string;
}

export interface EncryptedSecret {
  cryptoVersion: number;
  nonceBase64: string;
  cipherBlobBase64: string;
}

export interface StoredConfigEnvelope extends VerifiedConfigMetadata {
  schemaVersion: number;
  verified: boolean;
  secret: EncryptedSecret;
}
