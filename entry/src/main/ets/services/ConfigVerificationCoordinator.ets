import { RuntimeModelConfig } from '../models/ModelConfig';
import {
  VerificationCandidate,
  VerificationConfirmations,
  VerificationSuccess
} from '../models/VerificationModels';
import { VisionVerificationGate } from './VisionVerificationGate';
import { VerifiedConfigWriter } from './ConfigStoragePorts';

export class ConfigVerificationCoordinator {
  private readonly gate: VisionVerificationGate;
  private readonly writer: VerifiedConfigWriter;

  constructor(gate: VisionVerificationGate, writer: VerifiedConfigWriter) {
    this.gate = gate;
    this.writer = writer;
  }

  async verifyAndSave(candidate: VerificationCandidate,
    confirmations: VerificationConfirmations): Promise<VerificationSuccess> {
    let verified: RuntimeModelConfig | undefined;
    try {
      const success: VerificationSuccess = await this.gate.verify(candidate, confirmations);
      verified = {
        baseURL: success.normalizedBaseURL,
        apiKey: candidate.apiKey,
        model: candidate.model.trim(),
        verifiedAt: Date.now(),
        verificationProtocolVersion: 1,
        trustedOrigin: success.trustedOrigin
      };
      await this.writer.replaceVerified(verified);
      return success;
    } finally {
      candidate.apiKey = '';
      if (verified !== undefined) {
        verified.apiKey = '';
      }
    }
  }
}
