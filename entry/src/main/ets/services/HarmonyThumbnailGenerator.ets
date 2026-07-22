import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { PrivateImageDescriptor } from '../models/ScreenshotImportModels';
import { ThumbnailDescriptor } from '../models/StructuredUnderstandingModels';
import { ensurePrivateDirectory } from './HarmonyPrivateDirectory';
import { ThumbnailGenerator, ThumbnailPayload } from './ScreenshotUnderstandingPorts';

const THUMBNAIL_DIRECTORY: string = 'thumbnails';
const MAX_LONG_EDGE: number = 1024;
const JPEG_QUALITY: number = 85;

export interface ThumbnailSize {
  width: number;
  height: number;
}

export class HarmonyThumbnailGenerator implements ThumbnailGenerator {
  private readonly context: common.Context;
  private readonly base64: util.Base64Helper = new util.Base64Helper();

  constructor(context: common.Context) {
    this.context = context;
  }

  async generate(sourceImage: PrivateImageDescriptor): Promise<ThumbnailPayload> {
    let sourceFile: fileIo.File | undefined;
    let destinationFile: fileIo.File | undefined;
    let source: image.ImageSource | undefined;
    let pixelMap: image.PixelMap | undefined;
    let packer: image.ImagePacker | undefined;
    let destinationPath: string = '';
    try {
      const size: ThumbnailSize = calculateThumbnailSize(sourceImage.width, sourceImage.height);
      sourceFile = await fileIo.open(sourceImage.path, fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(sourceFile.fd);
      pixelMap = await source.createPixelMap({ desiredSize: { width: size.width, height: size.height } });
      packer = image.createImagePacker();
      const encoded: ArrayBuffer = await packer.packToData(pixelMap, {
        format: 'image/jpeg',
        quality: JPEG_QUALITY
      });

      const directory: string = `${this.context.filesDir}/${THUMBNAIL_DIRECTORY}`;
      await ensurePrivateDirectory(directory);
      destinationPath = `${directory}/${sourceImage.id}.jpg`;
      destinationFile = await fileIo.open(destinationPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      const written: number = await fileIo.write(destinationFile.fd, encoded);
      if (written !== encoded.byteLength) {
        throw new Error('Thumbnail file write was incomplete');
      }

      const descriptor: ThumbnailDescriptor = {
        uri: `file://${destinationPath}`,
        path: destinationPath,
        mimeType: 'image/jpeg',
        width: size.width,
        height: size.height,
        byteCount: encoded.byteLength
      };
      const dataURL: string = `data:image/jpeg;base64,${this.base64.encodeToStringSync(new Uint8Array(encoded))}`;
      return { descriptor: descriptor, dataURL: dataURL };
    } catch (error) {
      if (destinationFile !== undefined) {
        try {
          await fileIo.close(destinationFile);
        } catch (_closeError) {
        }
        destinationFile = undefined;
      }
      if (destinationPath.length > 0) {
        try {
          await fileIo.unlink(destinationPath);
        } catch (_cleanupError) {
        }
      }
      throw error as Error;
    } finally {
      if (destinationFile !== undefined) {
        try {
          await fileIo.close(destinationFile);
        } catch (_closeError) {
        }
      }
      if (packer !== undefined) {
        try {
          await packer.release();
        } catch (_releaseError) {
        }
      }
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (_releaseError) {
        }
      }
      if (source !== undefined) {
        try {
          await source.release();
        } catch (_releaseError) {
        }
      }
      if (sourceFile !== undefined) {
        try {
          await fileIo.close(sourceFile);
        } catch (_closeError) {
        }
      }
    }
  }
}

export function calculateThumbnailSize(width: number, height: number): ThumbnailSize {
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
    throw new Error('Image dimensions are invalid');
  }
  if (Math.max(width, height) <= MAX_LONG_EDGE) {
    return { width: Math.round(width), height: Math.round(height) };
  }
  if (width >= height) {
    return {
      width: MAX_LONG_EDGE,
      height: Math.max(1, Math.round(height * MAX_LONG_EDGE / width))
    };
  }
  return {
    width: Math.max(1, Math.round(width * MAX_LONG_EDGE / height)),
    height: MAX_LONG_EDGE
  };
}
