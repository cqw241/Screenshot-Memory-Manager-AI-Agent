import { describe, expect, it } from '@ohos/hypium';
import {
  DirectoryFileSystemPort,
  DirectoryStatPort,
  ensurePrivateDirectory
} from '../main/ets/services/HarmonyPrivateDirectory';

const FILE_EXISTS_ERROR_CODE: number = 13900015;

interface CodedError extends Error {
  code: number;
}

class FakeDirectoryStat implements DirectoryStatPort {
  private readonly directory: boolean;

  constructor(directory: boolean) {
    this.directory = directory;
  }

  isDirectory(): boolean {
    return this.directory;
  }
}

class ExistingDirectoryFileSystem implements DirectoryFileSystemPort {
  private exists: boolean = false;
  existingPathIsDirectory: boolean = true;
  injectedErrorCode: number = FILE_EXISTS_ERROR_CODE;
  mkdirCount: number = 0;
  statCount: number = 0;

  async mkdir(_path: string, _recursion: boolean): Promise<void> {
    this.mkdirCount += 1;
    if (this.exists) {
      const error: CodedError = new Error('File exists') as CodedError;
      error.code = this.injectedErrorCode;
      throw error;
    }
    this.exists = true;
  }

  async stat(_path: string): Promise<DirectoryStatPort> {
    this.statCount += 1;
    return new FakeDirectoryStat(this.existingPathIsDirectory);
  }
}

export default function harmonyPrivateDirectoryTest() {
  describe('HarmonyPrivateDirectory', () => {
    it('allows the same private directory to be ensured repeatedly', 0, async () => {
      const fileSystem: ExistingDirectoryFileSystem = new ExistingDirectoryFileSystem();

      await ensurePrivateDirectory('/private/imports', fileSystem);
      await ensurePrivateDirectory('/private/imports', fileSystem);

      expect(fileSystem.mkdirCount).assertEqual(2);
      expect(fileSystem.statCount).assertEqual(1);
    });

    it('does not hide a non-file-exists error', 0, async () => {
      const fileSystem: ExistingDirectoryFileSystem = new ExistingDirectoryFileSystem();
      fileSystem.injectedErrorCode = 13900012;
      await ensurePrivateDirectory('/private/imports', fileSystem);

      let rejected: boolean = false;
      try {
        await ensurePrivateDirectory('/private/imports', fileSystem);
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(fileSystem.statCount).assertEqual(0);
    });

    it('does not accept a regular file at the directory path', 0, async () => {
      const fileSystem: ExistingDirectoryFileSystem = new ExistingDirectoryFileSystem();
      fileSystem.existingPathIsDirectory = false;
      await ensurePrivateDirectory('/private/imports', fileSystem);

      let rejected: boolean = false;
      try {
        await ensurePrivateDirectory('/private/imports', fileSystem);
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(fileSystem.statCount).assertEqual(1);
    });
  });
}
