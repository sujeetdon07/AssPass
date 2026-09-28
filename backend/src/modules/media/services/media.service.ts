import {
  Injectable,
  Inject,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { MediaStorageProvider } from '../storage/media-storage.interface.js';
import { ImageProcessorService } from './image-processor.service.js';
import { UploadImageResponseDto } from '../dto/upload-image-response.dto.js';
import type { UploadFile } from '../interfaces/upload-file.interface.js';

export const MEDIA_STORAGE_PROVIDER = 'MEDIA_STORAGE_PROVIDER';

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);

  // Maximum allowed file size for uploads (15MB)
  private readonly maxUploadSizeBytes = 15 * 1024 * 1024;

  private readonly allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif',
  ];

  constructor(
    @Inject(MEDIA_STORAGE_PROVIDER)
    private readonly storageProvider: MediaStorageProvider,
    private readonly imageProcessor: ImageProcessorService,
  ) {}

  /**
   * Uploads and optimizes a single image file.
   */
  async uploadImage(
    file: UploadFile,
    imageType = 'content',
    hostHeader?: string,
  ): Promise<UploadImageResponseDto> {
    if (!file || !file.buffer || file.buffer.length === 0) {
      throw new BadRequestException('No image file provided.');
    }

    if (file.size > this.maxUploadSizeBytes) {
      throw new BadRequestException(
        `File size exceeds maximum allowed limit of ${Math.round(
          this.maxUploadSizeBytes / (1024 * 1024),
        )}MB.`,
      );
    }

    const mime = file.mimetype?.toLowerCase();
    if (!this.allowedMimeTypes.includes(mime)) {
      throw new BadRequestException(
        `Unsupported media type "${mime}". Allowed formats: JPEG, PNG, WebP, GIF.`,
      );
    }

    const isAvatar = imageType.toLowerCase() === 'avatar';

    // Process and optimize image variants
    const processed = await this.imageProcessor.processImage(
      file.buffer,
      isAvatar,
    );

    const baseId = randomUUID();
    const standardKey = `${isAvatar ? 'avatar' : 'img'}_${baseId}.webp`;
    const mediumKey = `med_${baseId}.webp`;
    const thumbKey = `thumb_${baseId}.webp`;

    // Upload all variants to storage
    const [standardResult, thumbResult, mediumResult] = await Promise.all([
      this.storageProvider.uploadFile({
        key: standardKey,
        buffer: processed.standard.buffer,
        contentType: processed.standard.mimeType,
      }),
      this.storageProvider.uploadFile({
        key: thumbKey,
        buffer: processed.thumbnail.buffer,
        contentType: processed.thumbnail.mimeType,
      }),
      processed.medium
        ? this.storageProvider.uploadFile({
            key: mediumKey,
            buffer: processed.medium.buffer,
            contentType: processed.medium.mimeType,
          })
        : Promise.resolve(null),
    ]);

    // Adapt URL if host header is given (e.g. mobile device connecting via LAN IP or emulator)
    let standardUrl = standardResult.url;
    let thumbUrl = thumbResult.url;
    let mediumUrl = mediumResult?.url;

    if (hostHeader && standardUrl.includes('localhost:')) {
      const parsedHost = hostHeader.replace(/\/+$/, '');
      standardUrl = standardUrl.replace(/localhost:[0-9]+/, parsedHost);
      thumbUrl = thumbUrl.replace(/localhost:[0-9]+/, parsedHost);
      if (mediumUrl) {
        mediumUrl = mediumUrl.replace(/localhost:[0-9]+/, parsedHost);
      }
    }

    return {
      url: standardUrl,
      thumbnailUrl: thumbUrl,
      mediumUrl,
      width: processed.standard.width,
      height: processed.standard.height,
      size: processed.standard.size,
      mimeType: processed.standard.mimeType,
      type: imageType,
    };
  }

  /**
   * Uploads and optimizes multiple images in batch.
   */
  async uploadImages(
    files: UploadFile[],
    imageType = 'content',
    hostHeader?: string,
  ): Promise<UploadImageResponseDto[]> {
    if (!files || files.length === 0) {
      throw new BadRequestException('No image files provided.');
    }

    if (files.length > 10) {
      throw new BadRequestException('Maximum 10 images can be uploaded simultaneously.');
    }

    const results: UploadImageResponseDto[] = [];
    for (const file of files) {
      const res = await this.uploadImage(file, imageType, hostHeader);
      results.push(res);
    }

    return results;
  }

  /**
   * Retrieves a file for direct streaming.
   */
  async getFile(filename: string): Promise<{ buffer: Buffer; contentType: string } | null> {
    return this.storageProvider.getFile(filename);
  }
}
