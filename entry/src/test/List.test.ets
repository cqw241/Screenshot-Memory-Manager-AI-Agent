import configRepositoryTest from './ConfigRepository.test';
import screenshotCardRepositoryTest from './ScreenshotCardRepository.test';
import screenshotImportTest from './ScreenshotImport.test';
import screenshotUnderstandingTest from './ScreenshotUnderstanding.test';
import startupRouterTest from './StartupRouter.test';
import visionVerificationTest from './VisionVerification.test';

export default function testsuite() {
  configRepositoryTest();
  screenshotCardRepositoryTest();
  screenshotImportTest();
  screenshotUnderstandingTest();
  startupRouterTest();
  visionVerificationTest();
}
