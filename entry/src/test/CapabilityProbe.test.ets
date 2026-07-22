import { describe, expect, it } from '@ohos/hypium';
import {
  CapabilityEvidence,
  CapabilityLevel,
  evaluateCapability,
  extractProbeCardId,
  ProbeEvidenceBuilder,
  ProbeEvidenceInput,
  ProbeEventKind,
  ProbeEventLog,
  ProbeValueHasher,
  ProbeWantParameters
} from '../main/ets/models/CapabilityProbeModels';

class LiteralHasher implements ProbeValueHasher {
  async digest(value: string): Promise<string> {
    if (value === 'file://media/Photo/secret') {
      return 'digest:uri';
    }
    if (value === 'asset-secret') {
      return 'digest:identifier';
    }
    if (value === 'file://media/PhotoAlbum/secret') {
      return 'digest:album';
    }
    return 'digest:name';
  }
}

function completeEvidence(): CapabilityEvidence {
  return {
    deliverySignatureVerified: true,
    permissionGranted: true,
    mediaMatrixComplete: true,
    screenshotRuleVerified: true,
    foregroundTrials: 3,
    foregroundCallbacks: 3,
    backgroundResidentTrials: 3,
    backgroundResidentCallbacks: 0,
    resumeScanTrials: 1,
    resumeScanDiscoveries: 1
  };
}

export default function capabilityProbeTest() {
  describe('CapabilityProbe', () => {
    it('keeps simulator evidence ungraded until a delivery signature is verified', 0, () => {
      const evidence: CapabilityEvidence = completeEvidence();
      evidence.deliverySignatureVerified = false;

      expect(evaluateCapability(evidence)).assertEqual(CapabilityLevel.UNKNOWN);
    });

    it('assigns L0 only from complete delivery evidence with no permission or discriminator', 0, () => {
      const denied: CapabilityEvidence = completeEvidence();
      denied.permissionGranted = false;
      const noRule: CapabilityEvidence = completeEvidence();
      noRule.screenshotRuleVerified = false;
      const incomplete: CapabilityEvidence = completeEvidence();
      incomplete.mediaMatrixComplete = false;

      expect(evaluateCapability(denied)).assertEqual(CapabilityLevel.L0);
      expect(evaluateCapability(noRule)).assertEqual(CapabilityLevel.L0);
      expect(evaluateCapability(incomplete)).assertEqual(CapabilityLevel.UNKNOWN);
    });

    it('assigns L1 when foreground or resume discovery works but resident background callbacks do not', 0, () => {
      expect(evaluateCapability(completeEvidence())).assertEqual(CapabilityLevel.L1);
    });

    it('assigns L2 only when all foreground and resident background trials receive callbacks', 0, () => {
      const evidence: CapabilityEvidence = completeEvidence();
      evidence.backgroundResidentCallbacks = 2;
      expect(evaluateCapability(evidence)).assertEqual(CapabilityLevel.L1);
      evidence.backgroundResidentCallbacks = 3;

      expect(evaluateCapability(evidence)).assertEqual(CapabilityLevel.L2);
    });

    it('hashes every media identity field before evidence enters the persistent log', 0, async () => {
      const input: ProbeEvidenceInput = {
        kind: ProbeEventKind.MEDIA_QUERY,
        recordedAtMs: 1784700000000,
        detail: '最近截图查询成功',
        uri: 'file://media/Photo/secret',
        identifier: 'asset-secret',
        albumUri: 'file://media/PhotoAlbum/secret',
        displayName: 'Screenshot_secret.png',
        mediaType: 'IMAGE',
        byteCount: 4096,
        dateAddedMs: 1784700000000,
        dateTakenMs: 1784699999000
      };

      const event = await new ProbeEvidenceBuilder(new LiteralHasher()).build(input);

      expect(event.uriDigest).assertEqual('digest:uri');
      expect(event.identifierDigest).assertEqual('digest:identifier');
      expect(event.albumDigest).assertEqual('digest:album');
      expect(event.displayNameDigest).assertEqual('digest:name');
      expect(event.dateTakenMs).assertEqual(1784699999000);
      expect(JSON.stringify(event).includes('secret.png')).assertFalse();
    });

    it('persists lifecycle ordering and rejects corrupt stored evidence', 0, () => {
      const log: ProbeEventLog = ProbeEventLog.fromJson('[]');
      log.append({
        kind: ProbeEventKind.LIFECYCLE,
        recordedAtMs: 100,
        detail: 'FOREGROUND'
      });
      log.append({
        kind: ProbeEventKind.LIFECYCLE,
        recordedAtMs: 200,
        detail: 'BACKGROUND'
      });

      const restored: ProbeEventLog = ProbeEventLog.fromJson(log.toJson());
      expect(restored.list().map((event): string => event.detail).join(','))
        .assertEqual('FOREGROUND,BACKGROUND');
      expect(ProbeEventLog.fromJson('{broken').list().length).assertEqual(0);
    });

    it('extracts only a bounded non-empty cardId from Want parameters', 0, () => {
      const valid: ProbeWantParameters = { cardId: ' probe-card-001 ' };
      const empty: ProbeWantParameters = { cardId: '' };
      const wrongType: ProbeWantParameters = { cardId: 123 };
      const tooLong: ProbeWantParameters = { cardId: 'x'.repeat(129) };
      expect(extractProbeCardId(valid)).assertEqual('probe-card-001');
      expect(extractProbeCardId(empty)).assertEqual('');
      expect(extractProbeCardId(wrongType)).assertEqual('');
      expect(extractProbeCardId(tooLong)).assertEqual('');
      expect(extractProbeCardId(undefined)).assertEqual('');
    });
  });
}
