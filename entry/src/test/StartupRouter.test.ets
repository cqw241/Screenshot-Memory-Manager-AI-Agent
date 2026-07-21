import { describe, expect, it } from '@ohos/hypium';
import { AppPage, StartupRoute } from '../main/ets/models/AppFlow';
import { ConfigState } from '../main/ets/models/ModelConfig';
import { ConfigStateReader } from '../main/ets/services/ConfigStoragePorts';
import { StartupRouter } from '../main/ets/services/StartupRouter';

class FakeStateReader implements ConfigStateReader {
  state: ConfigState = ConfigState.UNCONFIGURED;
  shouldFail: boolean = false;

  async getState(): Promise<ConfigState> {
    if (this.shouldFail) {
      throw new Error('injected read failure');
    }
    return this.state;
  }
}

export default function startupRouterTest() {
  describe('StartupRouter', () => {
    it('routes a complete decryptable verified configuration to home', 0, async () => {
      const reader: FakeStateReader = new FakeStateReader();
      reader.state = ConfigState.VERIFIED;

      const route: StartupRoute = await new StartupRouter(reader).resolve();

      expect(route.page).assertEqual(AppPage.HOME);
      expect(route.recoveryRequired).assertFalse();
    });

    it('routes an unconfigured installation to the wizard', 0, async () => {
      const route: StartupRoute = await new StartupRouter(new FakeStateReader()).resolve();

      expect(route.page).assertEqual(AppPage.WIZARD);
      expect(route.recoveryRequired).assertFalse();
    });

    it('routes corrupted configuration to the recovery wizard', 0, async () => {
      const reader: FakeStateReader = new FakeStateReader();
      reader.state = ConfigState.CORRUPTED;

      const route: StartupRoute = await new StartupRouter(reader).resolve();

      expect(route.page).assertEqual(AppPage.WIZARD);
      expect(route.recoveryRequired).assertTrue();
    });

    it('treats an unexpected state read failure as recoverable corruption', 0, async () => {
      const reader: FakeStateReader = new FakeStateReader();
      reader.shouldFail = true;

      const route: StartupRoute = await new StartupRouter(reader).resolve();

      expect(route.page).assertEqual(AppPage.WIZARD);
      expect(route.recoveryRequired).assertTrue();
    });
  });
}
