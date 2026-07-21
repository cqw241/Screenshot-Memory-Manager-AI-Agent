import configRepositoryTest from './ConfigRepository.test';
import screenshotImportTest from './ScreenshotImport.test';
import screenshotUnderstandingTest from './ScreenshotUnderstanding.test';
import startupRouterTest from './StartupRouter.test';
import visionVerificationTest from './VisionVerification.test';

export default function testsuite() {
  configRepositoryTest();
  screenshotImportTest();
  screenshotUnderstandingTest();
  startupRouterTest();
  visionVerificationTest();
}
