import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREFERENCES_NAME: string = 'screenshot_import_consent';
const CONSENTED_ORIGIN_KEY: string = 'consentedOrigin';

export class ImportConsentRepository {
  private readonly context: common.Context;
  private instance?: preferences.Preferences;

  constructor(context: common.Context) {
    this.context = context;
  }

  async hasConsent(origin: string): Promise<boolean> {
    if (origin.length === 0) {
      return false;
    }
    const value: preferences.ValueType = await (await this.getInstance()).get(CONSENTED_ORIGIN_KEY, '');
    return typeof value === 'string' && value === origin;
  }

  async grant(origin: string): Promise<void> {
    const store: preferences.Preferences = await this.getInstance();
    await store.put(CONSENTED_ORIGIN_KEY, origin);
    await store.flush();
  }

  private async getInstance(): Promise<preferences.Preferences> {
    if (this.instance === undefined) {
      this.instance = await preferences.getPreferences(this.context, PREFERENCES_NAME);
    }
    return this.instance;
  }
}
