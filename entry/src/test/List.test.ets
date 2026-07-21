import configRepositoryTest from './ConfigRepository.test';
import screenshotImportTest from './ScreenshotImport.test';
import startupRouterTest from './StartupRouter.test';
import visionVerificationTest from './VisionVerification.test';

export default function testsuite() {
  configRepositoryTest();
  screenshotImportTest();
  startupRouterTest();
  visionVerificationTest();
}
