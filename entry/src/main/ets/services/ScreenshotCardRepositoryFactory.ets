import { common } from '@kit.AbilityKit';
import { ScreenshotCardRepository } from './ScreenshotCardRepository';
import { HarmonyCardRowStore } from './HarmonyCardRowStore';

export function createScreenshotCardRepository(context: common.Context): ScreenshotCardRepository {
  return new ScreenshotCardRepository(new HarmonyCardRowStore(context));
}
