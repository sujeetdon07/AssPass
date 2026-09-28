import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import sharp, { type Metadata } from 'sharp';

export interface ProcessedVariant {
  buffer: Buffer;
  width: number;
  height: number;
  size: number;
  mimeType: string;
}

export interface ProcessedImageResult {
  standard: ProcessedVariant;
  thumbnail: ProcessedVariant;
  medium?: ProcessedVariant;
}

@Injectable()
export class ImageProcessorService {
  private readonly logger = new Logger(ImageProcessorService.name);

  // Maximum allowed dimension for uploads
  private readonly maxDimension = 8192;
  // Maximum long-edge for standard/original variant
  private readonly standardMaxEdge = 2048;
  // Maximum long-edge for medium variant
  private readonly mediumMaxEdge = 1024;
  // Maximum long-edge for thumbnail variant
  private readonly thumbnailMaxEdge = 400;

  /**
   * Verifies file signature / magic bytes to prevent MIME spoofing.
   */
  validateMagicBytes(buffer: Buffer): { isValid: boolean; detectedType?: string } {
    if (!buffer || buffer.length < 12) {
      return { isValid: false };
    }

    // JPEG: FF D8 FF
    if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
      return { isValid: true, detectedType: 'image/jpeg' };
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (
      buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4e &&
      buffer[3] === 0x47 &&
      buffer[4] === 0x0d &&
      buffer[5] === 0x0a &&
      buffer[6] === 0x1a &&
      buffer[7] === 0x0a
    ) {
      return { isValid: true, detectedType: 'image/png' };
    }

    // WebP: RIFF ... WEBP
    if (
      buffer[0] === 0x52 &&
      buffer[1] === 0x49 &&
      buffer[2] === 0x46 &&
      buffer[3] === 0x46 &&
      buffer[8] === 0x57 &&
      buffer[9] === 0x45 &&
      buffer[10] === 0x42 &&
      buffer[11] === 0x50
    ) {
      return { isValid: true, detectedType: 'image/webp' };
    }

    // GIF: GIF87a or GIF89a
    if (
      buffer[0] === 0x47 &&
      buffer[1] === 0x49 &&
      buffer[2] === 0x46 &&
      buffer[3] === 0x38 &&
      (buffer[4] === 0x37 || buffer[4] === 0x39) &&
      buffer[5] === 0x61
    ) {
      return { isValid: true, detectedType: 'image/gif' };
    }

    return { isValid: false };
  }

  /**
   * Validates and processes an uploaded image buffer.
   *
   * @param buffer Raw uploaded file buffer
   * @param isAvatar Whether this image is a profile avatar (forces 1:1 square crop)
   */
  async processImage(buffer: Buffer, isAvatar = false): Promise<ProcessedImageResult> {
    // 1. Validate magic bytes
    const magicCheck = this.validateMagicBytes(buffer);
    if (!magicCheck.isValid) {
      throw new BadRequestException(
        'Invalid image file format. Only JPEG, PNG, WebP, and GIF images are supported.',
      );
    }

    // 2. Inspect with sharp metadata
    let metadata: Metadata;
    try {
      metadata = await sharp(buffer).metadata();
    } catch {
      throw new BadRequestException('Corrupted or unreadable image file.');
    }

    if (!metadata.width || !metadata.height) {
      throw new BadRequestException('Unable to determine image dimensions.');
    }

    if (metadata.width > this.maxDimension || metadata.height > this.maxDimension) {
      throw new BadRequestException(
        `Image dimensions exceed maximum allowed limit of ${this.maxDimension}x${this.maxDimension}px.`,
      );
    }

    // 3. Process variants with orientation normalization and EXIF stripping
    if (isAvatar) {
      return this.processAvatarVariants(buffer);
    }

    return this.processStandardVariants(buffer, metadata);
  }

  /**
   * Processes profile avatar images:
   * Fixed 1:1 square aspect ratio crop normalized to 1024x1024 max.
   */
  private async processAvatarVariants(buffer: Buffer): Promise<ProcessedImageResult> {
    // Standard avatar: 1024x1024 square, WebP, quality 85, EXIF stripped
    const standardPipeline = sharp(buffer)
      .rotate() // auto-orient based on EXIF before stripping
      .resize(1024, 1024, {
        fit: 'cover',
        position: 'center',
        withoutEnlargement: false,
      })
      .webp({ quality: 85 });

    const standardBuffer = await standardPipeline.toBuffer();
    const standardMeta = await sharp(standardBuffer).metadata();

    // Medium avatar: 512x512 square
    const mediumPipeline = sharp(standardBuffer)
      .resize(512, 512, { fit: 'cover' })
      .webp({ quality: 80 });

    const mediumBuffer = await mediumPipeline.toBuffer();
    const mediumMeta = await sharp(mediumBuffer).metadata();

    // Thumbnail avatar: 256x256 square (for small circular avatars)
    const thumbnailPipeline = sharp(standardBuffer)
      .resize(256, 256, { fit: 'cover' })
      .webp({ quality: 75 });

    const thumbnailBuffer = await thumbnailPipeline.toBuffer();
    const thumbnailMeta = await sharp(thumbnailBuffer).metadata();

    return {
      standard: {
        buffer: standardBuffer,
        width: standardMeta.width ?? 1024,
        height: standardMeta.height ?? 1024,
        size: standardBuffer.length,
        mimeType: 'image/webp',
      },
      medium: {
        buffer: mediumBuffer,
        width: mediumMeta.width ?? 512,
        height: mediumMeta.height ?? 512,
        size: mediumBuffer.length,
        mimeType: 'image/webp',
      },
      thumbnail: {
        buffer: thumbnailBuffer,
        width: thumbnailMeta.width ?? 256,
        height: thumbnailMeta.height ?? 256,
        size: thumbnailBuffer.length,
        mimeType: 'image/webp',
      },
    };
  }

  /**
   * Processes standard content images (posts, marketplace, events, businesses):
   * Preserves natural aspect ratio, resizes oversized dimensions, creates thumbnails.
   */
  private async processStandardVariants(
    buffer: Buffer,
    _metadata: Metadata,
  ): Promise<ProcessedImageResult> {
    // Standard variant: max 2048 long edge, WebP quality 85, EXIF stripped
    const standardPipeline = sharp(buffer)
      .rotate()
      .resize({
        width: this.standardMaxEdge,
        height: this.standardMaxEdge,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 85 });

    const standardBuffer = await standardPipeline.toBuffer();
    const standardMeta = await sharp(standardBuffer).metadata();

    // Medium variant: max 1024 long edge
    const mediumPipeline = sharp(standardBuffer)
      .resize({
        width: this.mediumMaxEdge,
        height: this.mediumMaxEdge,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 80 });

    const mediumBuffer = await mediumPipeline.toBuffer();
    const mediumMeta = await sharp(mediumBuffer).metadata();

    // Thumbnail variant: max 400 long edge (fast preview for list cards)
    const thumbnailPipeline = sharp(standardBuffer)
      .resize({
        width: this.thumbnailMaxEdge,
        height: this.thumbnailMaxEdge,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 75 });

    const thumbnailBuffer = await thumbnailPipeline.toBuffer();
    const thumbnailMeta = await sharp(thumbnailBuffer).metadata();

    return {
      standard: {
        buffer: standardBuffer,
        width: standardMeta.width ?? 0,
        height: standardMeta.height ?? 0,
        size: standardBuffer.length,
        mimeType: 'image/webp',
      },
      medium: {
        buffer: mediumBuffer,
        width: mediumMeta.width ?? 0,
        height: mediumMeta.height ?? 0,
        size: mediumBuffer.length,
        mimeType: 'image/webp',
      },
      thumbnail: {
        buffer: thumbnailBuffer,
        width: thumbnailMeta.width ?? 0,
        height: thumbnailMeta.height ?? 0,
        size: thumbnailBuffer.length,
        mimeType: 'image/webp',
      },
    };
  }
}
