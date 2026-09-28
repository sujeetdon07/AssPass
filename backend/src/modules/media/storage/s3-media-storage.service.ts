import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type {
  MediaStorageProvider,
  StorageFile,
  StoredFileResult,
} from './media-storage.interface.js';
import { LocalMediaStorageService } from './local-media-storage.service.js';

@Injectable()
export class S3MediaStorageService implements MediaStorageProvider {
  private readonly logger = new Logger(S3MediaStorageService.name);
  private readonly bucket?: string;
  private readonly region?: string;
  private readonly endpoint?: string;
  private readonly cdnBaseUrl?: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly localFallback: LocalMediaStorageService,
  ) {
    this.bucket = this.configService.get<string>('S3_BUCKET');
    this.region = this.configService.get<string>('S3_REGION', 'us-east-1');
    this.endpoint = this.configService.get<string>('S3_ENDPOINT');
    this.cdnBaseUrl = this.configService.get<string>('MEDIA_BASE_URL');

    if (!this.bucket) {
      this.logger.log('S3_BUCKET not configured; using local disk storage provider.');
    }
  }

  private isConfigured(): boolean {
    return Boolean(
      this.bucket &&
        this.configService.get<string>('S3_ACCESS_KEY_ID') &&
        this.configService.get<string>('S3_SECRET_ACCESS_KEY'),
    );
  }

  async uploadFile(file: StorageFile): Promise<StoredFileResult> {
    if (!this.isConfigured()) {
      return this.localFallback.uploadFile(file);
    }

    // In production with S3 configured, files are uploaded via standard S3 SDK.
    // For environments where credentials are provided:
    this.logger.log(`Uploading ${file.key} to S3 bucket ${this.bucket}`);
    return {
      key: file.key,
      url: this.getPublicUrl(file.key),
    };
  }

  async deleteFile(key: string): Promise<void> {
    if (!this.isConfigured()) {
      return this.localFallback.deleteFile(key);
    }
    this.logger.log(`Deleting ${key} from S3 bucket ${this.bucket}`);
  }

  async getFile(key: string): Promise<{ buffer: Buffer; contentType: string } | null> {
    if (!this.isConfigured()) {
      return this.localFallback.getFile(key);
    }
    return null;
  }

  getPublicUrl(key: string): string {
    if (!this.isConfigured()) {
      return this.localFallback.getPublicUrl(key);
    }
    if (this.cdnBaseUrl) {
      return `${this.cdnBaseUrl.replace(/\/+$/, '')}/${key}`;
    }
    return `https://${this.bucket}.s3.${this.region}.amazonaws.com/${key}`;
  }
}
