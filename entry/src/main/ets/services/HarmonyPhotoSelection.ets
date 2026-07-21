import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { PhotoSelectionPort } from './ScreenshotImportPorts';

export class HarmonyPhotoSelection implements PhotoSelectionPort {
  async selectSingleImage(): Promise<string | undefined> {
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
    return result.photoUris.length > 0 ? result.photoUris[0] : undefined;
  }
}
