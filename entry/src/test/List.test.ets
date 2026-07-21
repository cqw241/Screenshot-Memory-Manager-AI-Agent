import configRepositoryTest from './ConfigRepository.test';
import startupRouterTest from './StartupRouter.test';
import visionVerificationTest from './VisionVerification.test';

export default function testsuite() {
  configRepositoryTest();
  startupRouterTest();
  visionVerificationTest();
}
