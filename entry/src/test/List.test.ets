import chatRequestCompatibilityTest from './ChatRequestCompatibility.test';
import configRepositoryTest from './ConfigRepository.test';
import harmonyPrivateDirectoryTest from './HarmonyPrivateDirectory.test';
import screenshotCardRepositoryTest from './ScreenshotCardRepository.test';
import screenshotCardPresentationTest from './ScreenshotCardPresentation.test';
import screenshotImportTest from './ScreenshotImport.test';
import screenshotIngestionCoordinatorTest from './ScreenshotIngestionCoordinator.test';
import screenshotUnderstandingTest from './ScreenshotUnderstanding.test';
import startupRouterTest from './StartupRouter.test';
import visionVerificationTest from './VisionVerification.test';
import capabilityProbeTest from './CapabilityProbe.test';

export default function testsuite() {
  chatRequestCompatibilityTest();
  configRepositoryTest();
  harmonyPrivateDirectoryTest();
  screenshotCardRepositoryTest();
  screenshotCardPresentationTest();
  screenshotImportTest();
  screenshotIngestionCoordinatorTest();
  screenshotUnderstandingTest();
  startupRouterTest();
  visionVerificationTest();
  capabilityProbeTest();
}
