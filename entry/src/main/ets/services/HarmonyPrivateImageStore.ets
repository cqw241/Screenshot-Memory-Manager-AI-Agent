import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { PrivateImageDescriptor } from '../models/ScreenshotImportModels';
import { ensurePrivateDirectory } from './HarmonyPrivateDirectory';
import { PrivateImageStorePort } from './ScreenshotImportPorts';

const IMPORT_DIRECTORY: string = 'imports';

export class HarmonyPrivateImageStore implements PrivateImageStorePort {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async importImage(sourceUri: string): Promise<PrivateImageDescriptor> {
    let sourceFile: fileIo.File | undefined;
    let source: image.ImageSource | undefined;
    let destinationPath: string = '';
    try {
      sourceFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(sourceFile.fd);
      const info: image.ImageInfo = await source.getImageInfo();
      const directory: string = `${this.context.filesDir}/${IMPORT_DIRECTORY}`;
      await ensurePrivateDirectory(directory);
      const id: string = util.generateRandomUUID(true);
      destinationPath = `${directory}/${id}${extensionForMimeType(info.mimeType)}`;
      await fileIo.copyFile(sourceFile.fd, destinationPath);
      const stat: fileIo.Stat = await fileIo.stat(destinationPath);
      return {
        id: id,
        uri: `file://${destinationPath}`,
        path: destinationPath,
        mimeType: info.mimeType,
        width: info.size.width,
        height: info.size.height,
        byteCount: stat.size
      };
    } catch (error) {
      if (destinationPath.length > 0) {
        try {
          await fileIo.unlink(destinationPath);
        } catch (_cleanupError) {
        }
      }
      throw error as Error;
    } finally {
      try {
        if (sourceFile !== undefined) {
          await fileIo.close(sourceFile);
        }
      } finally {
        if (source !== undefined) {
          await source.release();
        }
      }
    }
  }
}

export function extensionForMimeType(mimeType: string): string {
  switch (mimeType.toLowerCase()) {
    case 'image/jpeg':
      return '.jpg';
    case 'image/png':
      return '.png';
    case 'image/webp':
      return '.webp';
    case 'image/heic':
      return '.heic';
    case 'image/heif':
      return '.heif';
    case 'image/gif':
      return '.gif';
    default:
      return '.img';
  }
}
