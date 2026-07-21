import configRepositoryTest from './ConfigRepository.test';
import visionVerificationTest from './VisionVerification.test';

export default function testsuite() {
  configRepositoryTest();
  visionVerificationTest();
}
