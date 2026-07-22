import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import {
  ProbeEvidenceBuilder,
  ProbeEvidenceEvent,
  ProbeEvidenceInput,
  ProbeEventLog,
  ProbeValueHasher
} from '../models/CapabilityProbeModels';

const PREFERENCES_NAME: string = 's03_capability_probe';
const EVENTS_KEY: string = 'eventsJson';

export class HarmonyProbeValueHasher implements ProbeValueHasher {
  private readonly encoder: util.TextEncoder = new util.TextEncoder();

  async digest(value: string): Promise<string> {
    try {
      const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
      const input: cryptoFramework.DataBlob = { data: this.encoder.encodeInto(value) };
      await md.update(input);
      const output: cryptoFramework.DataBlob = await md.digest();
      return bytesToHex(output.data);
    } catch (error) {
      throw error as Error;
    }
  }
}

export class CapabilityProbeRepository {
  private readonly context: common.Context;
  private readonly builder: ProbeEvidenceBuilder;
  private instance?: preferences.Preferences;
  private writeQueue: Promise<void> = Promise.resolve();

  constructor(context: common.Context, hasher: ProbeValueHasher = new HarmonyProbeValueHasher()) {
    this.context = context;
    this.builder = new ProbeEvidenceBuilder(hasher);
  }

  append(input: ProbeEvidenceInput): Promise<void> {
    const operation: Promise<void> = this.writeQueue.then((): Promise<void> => this.appendNow(input));
    this.writeQueue = operation.catch((_error: Object): void => {});
    return operation;
  }

  private async appendNow(input: ProbeEvidenceInput): Promise<void> {
    try {
      const event: ProbeEvidenceEvent = await this.builder.build(input);
      const store: preferences.Preferences = await this.getInstance();
      const raw: preferences.ValueType = await store.get(EVENTS_KEY, '[]');
      const log: ProbeEventLog = ProbeEventLog.fromJson(typeof raw === 'string' ? raw : '[]');
      log.append(event);
      await store.put(EVENTS_KEY, log.toJson());
      await store.flush();
    } catch (error) {
      throw error as Error;
    }
  }

  async list(): Promise<ProbeEvidenceEvent[]> {
    try {
      const raw: preferences.ValueType = await (await this.getInstance()).get(EVENTS_KEY, '[]');
      return ProbeEventLog.fromJson(typeof raw === 'string' ? raw : '[]').list();
    } catch (error) {
      throw error as Error;
    }
  }

  async clear(): Promise<void> {
    try {
      const store: preferences.Preferences = await this.getInstance();
      await store.put(EVENTS_KEY, '[]');
      await store.flush();
    } catch (error) {
      throw error as Error;
    }
  }

  private async getInstance(): Promise<preferences.Preferences> {
    try {
      if (this.instance === undefined) {
        this.instance = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      }
      return this.instance;
    } catch (error) {
      throw error as Error;
    }
  }
}

function bytesToHex(bytes: Uint8Array): string {
  let result: string = '';
  bytes.forEach((value: number): void => {
    result += value.toString(16).padStart(2, '0');
  });
  return result;
}
