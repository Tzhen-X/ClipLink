import fs from '@ohos.file.fs';
import Environment from '@ohos.file.environment';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { image } from '@kit.ImageKit';

export class ImageUtil {
  private static downloadPermissionPromise: Promise<boolean> | null = null;

  private static getAbilityContext(): Context {
    const context = AppStorage.get<Context>('abilityContext');
    if (!context) {
      throw new Error('Ability context is not initialized');
    }
    return context as Context;
  }

  static async createPixelMapFromBuffer(buffer: ArrayBuffer): Promise<image.PixelMap> {
    const imageSource = image.createImageSource(buffer.slice(0, buffer.byteLength));
    try {
      return await imageSource.createPixelMap({
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
    } finally {
      await imageSource.release();
    }
  }

  static async saveBufferToDownloadFile(
    buffer: ArrayBuffer,
    baseName: string,
    preferredExtension?: string
  ): Promise<string> {
    const directory = await ImageUtil.resolveDownloadDirectory();
    ImageUtil.ensureDirectory(directory);
    const extension = preferredExtension || ImageUtil.guessImageExtension(buffer);
    const fileName = ImageUtil.createSimpleFileName(baseName, extension, directory);
    const filePath = `${directory}/${fileName}`;
    const file = fs.openSync(
      filePath,
      fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC
    );
    try {
      fs.writeSync(file.fd, buffer);
    } finally {
      fs.closeSync(file);
    }
    return filePath;
  }

  private static async resolveDownloadDirectory(): Promise<string> {
    const context = ImageUtil.getAbilityContext();
    const fallbackDirectory = `${context.filesDir}/downloads/SyncClipboard`;
    try {
      const hasPermission = await ImageUtil.ensureDownloadPermission();
      if (!hasPermission) {
        return fallbackDirectory;
      }
      const publicDownloadDirectory = Environment.getUserDownloadDir();
      return `${publicDownloadDirectory}/SyncClipboard`;
    } catch (error) {
      console.error('[ImageUtil] resolveDownloadDirectory error:', JSON.stringify(error));
      return fallbackDirectory;
    }
  }

  private static async ensureDownloadPermission(): Promise<boolean> {
    if (ImageUtil.downloadPermissionPromise) {
      return await ImageUtil.downloadPermissionPromise;
    }

    ImageUtil.downloadPermissionPromise = (async (): Promise<boolean> => {
      try {
        const atManager = abilityAccessCtrl.createAtManager();
        const result = await atManager.requestPermissionsFromUser(
          ImageUtil.getAbilityContext(),
          ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY']
        );
        return result.authResults.length > 0 && result.authResults[0] === 0;
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        if (message.includes('12100011')) {
          return true;
        }
        console.error('[ImageUtil] ensureDownloadPermission error:', JSON.stringify(error));
        return false;
      }
    })();

    return await ImageUtil.downloadPermissionPromise;
  }

  static guessImageExtension(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    if (bytes.length >= 8 &&
      bytes[0] === 0x89 &&
      bytes[1] === 0x50 &&
      bytes[2] === 0x4E &&
      bytes[3] === 0x47) {
      return '.png';
    }
    if (bytes.length >= 3 &&
      bytes[0] === 0xFF &&
      bytes[1] === 0xD8 &&
      bytes[2] === 0xFF) {
      return '.jpg';
    }
    if (bytes.length >= 4 &&
      bytes[0] === 0x47 &&
      bytes[1] === 0x49 &&
      bytes[2] === 0x46 &&
      bytes[3] === 0x38) {
      return '.gif';
    }
    if (bytes.length >= 12 &&
      bytes[0] === 0x52 &&
      bytes[1] === 0x49 &&
      bytes[2] === 0x46 &&
      bytes[3] === 0x46 &&
      bytes[8] === 0x57 &&
      bytes[9] === 0x45 &&
      bytes[10] === 0x42 &&
      bytes[11] === 0x50) {
      return '.webp';
    }
    if (bytes.length >= 2 &&
      bytes[0] === 0x42 &&
      bytes[1] === 0x4D) {
      return '.bmp';
    }
    return '.img';
  }

  private static sanitizeFileName(name: string): string {
    const sanitized = name.replace(/[^a-zA-Z0-9-_]/g, '_');
    return sanitized.length > 0 ? sanitized : 'history-image';
  }

  private static createSimpleFileName(
    baseName: string,
    extension: string,
    directory: string
  ): string {
    const sanitizedBaseName = ImageUtil.sanitizeFileName(baseName).toLowerCase();
    const prefix = sanitizedBaseName.includes('image') ? 'image' : sanitizedBaseName;
    const now = new Date();
    const timestamp =
      `${now.getFullYear()}` +
      `${(now.getMonth() + 1).toString().padStart(2, '0')}` +
      `${now.getDate().toString().padStart(2, '0')}` +
      `-${now.getHours().toString().padStart(2, '0')}` +
      `${now.getMinutes().toString().padStart(2, '0')}` +
      `${now.getSeconds().toString().padStart(2, '0')}`;
    let candidate = `${prefix}-${timestamp}${extension}`;
    let suffix = 1;
    while (fs.accessSync(`${directory}/${candidate}`)) {
      candidate = `${prefix}-${timestamp}-${suffix}${extension}`;
      suffix += 1;
    }
    return candidate;
  }

  private static ensureDirectory(path: string): void {
    try {
      if (!fs.accessSync(path)) {
        fs.mkdirSync(path, true);
      }
    } catch (error) {
      console.error('[ImageUtil] ensureDirectory error:', JSON.stringify(error));
      throw error instanceof Error ? error : new Error(String(error));
    }
  }
}
