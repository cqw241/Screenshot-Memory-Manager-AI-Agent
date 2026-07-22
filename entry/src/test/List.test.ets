import chatRequestCompatibilityTest from './ChatRequestCompatibility.test';
import configRepositoryTest from './ConfigRepository.test';
import screenshotCardRepositoryTest from './ScreenshotCardRepository.test';
import screenshotCardPresentationTest from './ScreenshotCardPresentation.test';
import screenshotImportTest from './ScreenshotImport.test';
import screenshotUnderstandingTest from './ScreenshotUnderstanding.test';
import startupRouterTest from './StartupRouter.test';
import visionVerificationTest from './VisionVerification.test';

export default function testsuite() {
  chatRequestCompatibilityTest();
  configRepositoryTest();
  screenshotCardRepositoryTest();
  screenshotCardPresentationTest();
  screenshotImportTest();
  screenshotUnderstandingTest();
  startupRouterTest();
  visionVerificationTest();
}
