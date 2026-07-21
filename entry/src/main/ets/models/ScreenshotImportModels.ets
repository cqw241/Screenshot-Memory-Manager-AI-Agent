export enum ImportOutcomeKind {
  CANCELLED = 'CANCELLED',
  READY = 'READY'
}

export enum OcrStatus {
  SUCCESS = 'SUCCESS',
  RETRY_PENDING = 'RETRY_PENDING'
}

export interface PrivateImageDescriptor {
  id: string;
  uri: string;
  path: string;
  mimeType: string;
  width: number;
  height: number;
  byteCount: number;
}

export interface CancelledImportOutcome {
  kind: ImportOutcomeKind.CANCELLED;
}

export interface ReadyImportOutcome {
  kind: ImportOutcomeKind.READY;
  image: PrivateImageDescriptor;
  ocrText: string;
  ocrStatus: OcrStatus;
}

export type ImportOutcome = CancelledImportOutcome | ReadyImportOutcome;
