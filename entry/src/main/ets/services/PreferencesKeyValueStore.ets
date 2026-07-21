import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { KeyValueStore } from './ConfigStoragePorts';

const PREFERENCES_NAME: string = 'verified_model_config';

export class PreferencesKeyValueStore implements KeyValueStore {
  private instance?: preferences.Preferences;
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async getString(key: string): Promise<string> {
    const value: preferences.ValueType = await (await this.getInstance()).get(key, '');
    return typeof value === 'string' ? value : '';
  }

  async putString(key: string, value: string): Promise<void> {
    await (await this.getInstance()).put(key, value);
  }

  async flush(): Promise<void> {
    await (await this.getInstance()).flush();
  }

  private async getInstance(): Promise<preferences.Preferences> {
    if (this.instance === undefined) {
      this.instance = await preferences.getPreferences(this.context, PREFERENCES_NAME);
    }
    return this.instance;
  }
}
