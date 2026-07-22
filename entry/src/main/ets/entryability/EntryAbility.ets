import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { extractProbeCardId, ProbeWantParameters } from '../models/CapabilityProbeModels';
import { getCapabilityProbeController } from '../services/CapabilityProbeController';

const LOG_DOMAIN: number = 0x5347;
const LOG_TAG: string = 'ShiguangEntry';

export default class EntryAbility extends UIAbility {
  private launchCardId: string = '';
  private windowStage?: window.WindowStage;

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Entry ability created');
    const controller = getCapabilityProbeController(this.context);
    controller.recordLifecycle('ON_CREATE').catch((): void => {});
    this.launchCardId = extractProbeCardId(want.parameters as ProbeWantParameters | undefined);
    if (this.launchCardId.length > 0) {
      AppStorage.setOrCreate('probeDeepLinkCardId', this.launchCardId);
      controller.recordWant(want).catch((): void => {});
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    const page: string = this.launchCardId.length > 0 ? 'pages/CapabilityProbe' : 'pages/Index';
    windowStage.loadContent(page, (error) => {
      if (error.code !== 0) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Unable to load root page, code=%{public}d', error.code);
      }
    });
  }

  onForeground(): void {
    getCapabilityProbeController(this.context).recordLifecycle('ON_FOREGROUND').catch((): void => {});
  }

  onBackground(): void {
    getCapabilityProbeController(this.context).recordLifecycle('ON_BACKGROUND').catch((): void => {});
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    const controller = getCapabilityProbeController(this.context);
    controller.recordLifecycle('ON_NEW_WANT').catch((): void => {});
    const cardId: string = extractProbeCardId(want.parameters as ProbeWantParameters | undefined);
    if (cardId.length === 0) {
      return;
    }
    AppStorage.setOrCreate('probeDeepLinkCardId', cardId);
    controller.recordWant(want).catch((): void => {});
    this.windowStage?.loadContent('pages/CapabilityProbe', (error): void => {
      if (error.code !== 0) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Unable to load probe page, code=%{public}d', error.code);
      }
    });
  }

  onDestroy(): void {
    getCapabilityProbeController(this.context).recordLifecycle('ON_DESTROY').catch((): void => {});
  }
}

