import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import type {
  MediaStorageProvider,
  StorageFile,
  StoredFileResult,
} from './media-storage.interface.js';

@Injectable()
export class LocalMediaStorageService implements MediaStorageProvider {
  private readonly logger = new Logger(LocalMediaStorageService.name);
  private readonly uploadDir: string;
  private readonly baseUrl: string;

  constructor(private readonly configService: ConfigService) {
    const configuredDir =
      this.configService.get<string>('MEDIA_UPLOAD_DIR') || './uploads/media';
    this.uploadDir = path.resolve(process.cwd(), configuredDir);

    const configuredBaseUrl = this.configService.get<string>('MEDIA_BASE_URL');
    if (configuredBaseUrl) {
      this.baseUrl = configuredBaseUrl.replace(/\/+$/, '');
    } else {
      const port = this.configService.get<number>('PORT', 3000);
      this.baseUrl = `http://localhost:${port}/api/v1/media/files`;
    }

    this.ensureUploadDir();
  }

  private async ensureUploadDir(): Promise<void> {
    try {
      await fs.mkdir(this.uploadDir, { recursive: true });
    } catch (err) {
      this.logger.error(`Failed to create upload directory: ${this.uploadDir}`, err);
    }
  }

  private sanitizeKey(key: string): string {
    // Prevent directory traversal: only allow alphanumeric, underscores, hyphens, and dots
    const basename = path.basename(key);
    return basename.replace(/[^a-zA-Z0-9_\-.]/g, '_');
  }

  async uploadFile(file: StorageFile): Promise<StoredFileResult> {
    await this.ensureUploadDir();
    const safeKey = this.sanitizeKey(file.key);
    const destinationPath = path.join(this.uploadDir, safeKey);

    await fs.writeFile(destinationPath, file.buffer);

    return {
      key: safeKey,
      url: this.getPublicUrl(safeKey),
    };
  }

  async deleteFile(key: string): Promise<void> {
    const safeKey = this.sanitizeKey(key);
    const filePath = path.join(this.uploadDir, safeKey);
    try {
      await fs.unlink(filePath);
    } catch (err: any) {
      if (err.code !== 'ENOENT') {
        this.logger.warn(`Failed to delete file: ${filePath}`, err);
      }
    }
  }

  async getFile(key: string): Promise<{ buffer: Buffer; contentType: string } | null> {
    const safeKey = this.sanitizeKey(key);
    const filePath = path.join(this.uploadDir, safeKey);

    // Verify path is within uploadDir
    if (!filePath.startsWith(this.uploadDir)) {
      this.logger.warn(`Attempted path traversal for key: ${key}`);
      return null;
    }

    try {
      const buffer = await fs.readFile(filePath);
      let contentType = 'application/octet-stream';
      if (safeKey.endsWith('.webp')) contentType = 'image/webp';
      else if (safeKey.endsWith('.jpg') || safeKey.endsWith('.jpeg')) contentType = 'image/jpeg';
      else if (safeKey.endsWith('.png')) contentType = 'image/png';
      else if (safeKey.endsWith('.gif')) contentType = 'image/gif';

      return { buffer, contentType };
    } catch (err: any) {
      if (err.code === 'ENOENT') {
        return null;
      }
      throw err;
    }
  }

  getPublicUrl(key: string): string {
    const safeKey = this.sanitizeKey(key);
    return `${this.baseUrl}/${safeKey}`;
  }
}
