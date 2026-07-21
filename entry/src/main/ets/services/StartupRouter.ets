import { AppPage, StartupRoute } from '../models/AppFlow';
import { ConfigState } from '../models/ModelConfig';
import { ConfigStateReader } from './ConfigStoragePorts';

export class StartupRouter {
  private readonly reader: ConfigStateReader;

  constructor(reader: ConfigStateReader) {
    this.reader = reader;
  }

  async resolve(): Promise<StartupRoute> {
    try {
      const state: ConfigState = await this.reader.getState();
      if (state === ConfigState.VERIFIED) {
        return { page: AppPage.HOME, recoveryRequired: false };
      }
      return {
        page: AppPage.WIZARD,
        recoveryRequired: state === ConfigState.CORRUPTED
      };
    } catch (_error) {
      return { page: AppPage.WIZARD, recoveryRequired: true };
    }
  }
}
