import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';

const FILE_EXISTS_ERROR_CODE: number = 13900015;

export interface DirectoryStatPort {
  isDirectory(): boolean;
}

export interface DirectoryFileSystemPort {
  mkdir(path: string, recursion: boolean): Promise<void>;
  stat(path: string): Promise<DirectoryStatPort>;
}

class HarmonyDirectoryFileSystem implements DirectoryFileSystemPort {
  async mkdir(path: string, recursion: boolean): Promise<void> {
    try {
      await fileIo.mkdir(path, recursion);
    } catch (error) {
      throw error as Error;
    }
  }

  async stat(path: string): Promise<DirectoryStatPort> {
    try {
      return await fileIo.stat(path);
    } catch (error) {
      throw error as Error;
    }
  }
}

const HARMONY_DIRECTORY_FILE_SYSTEM: DirectoryFileSystemPort = new HarmonyDirectoryFileSystem();

export async function ensurePrivateDirectory(
  path: string,
  fileSystem: DirectoryFileSystemPort = HARMONY_DIRECTORY_FILE_SYSTEM
): Promise<void> {
  try {
    await fileSystem.mkdir(path, true);
  } catch (error) {
    const businessError: BusinessError = error as BusinessError;
    if (businessError.code !== FILE_EXISTS_ERROR_CODE) {
      throw error as Error;
    }
    const stat: DirectoryStatPort = await fileSystem.stat(path);
    if (!stat.isDirectory()) {
      throw error as Error;
    }
  }
}
