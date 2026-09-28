import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import sharp from 'sharp';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import { ConfigService } from '@nestjs/config';
import { BadRequestException } from '@nestjs/common';
import { ImageProcessorService } from '../../src/modules/media/services/image-processor.service.js';
import { LocalMediaStorageService } from '../../src/modules/media/storage/local-media-storage.service.js';
import { MediaService } from '../../src/modules/media/services/media.service.js';

describe('Media Subsystem', () => {
  let imageProcessor: ImageProcessorService;
  let storageService: LocalMediaStorageService;
  let mediaService: MediaService;
  const testUploadDir = path.resolve(process.cwd(), './tmp-test-uploads');

  beforeEach(async () => {
    imageProcessor = new ImageProcessorService();

    const mockConfigService = {
      get: vi.fn((key: string, defaultVal?: any) => {
        if (key === 'MEDIA_UPLOAD_DIR') return './tmp-test-uploads';
        if (key === 'PORT') return 3000;
        return defaultVal;
      }),
    } as unknown as ConfigService;

    storageService = new LocalMediaStorageService(mockConfigService);
    mediaService = new MediaService(storageService, imageProcessor);
  });

  afterEach(async () => {
    try {
      await fs.rm(testUploadDir, { recursive: true, force: true });
    } catch {}
  });

  describe('ImageProcessorService', () => {
    it('detects magic bytes correctly for supported formats', async () => {
      const jpegBuffer = await sharp({
        create: { width: 50, height: 50, channels: 3, background: { r: 255, g: 0, b: 0 } },
      })
        .jpeg()
        .toBuffer();

      const pngBuffer = await sharp({
        create: { width: 50, height: 50, channels: 4, background: { r: 0, g: 255, b: 0, alpha: 1 } },
      })
        .png()
        .toBuffer();

      const webpBuffer = await sharp({
        create: { width: 50, height: 50, channels: 3, background: { r: 0, g: 0, b: 255 } },
      })
        .webp()
        .toBuffer();

      expect(imageProcessor.validateMagicBytes(jpegBuffer).isValid).toBe(true);
      expect(imageProcessor.validateMagicBytes(jpegBuffer).detectedType).toBe('image/jpeg');

      expect(imageProcessor.validateMagicBytes(pngBuffer).isValid).toBe(true);
      expect(imageProcessor.validateMagicBytes(pngBuffer).detectedType).toBe('image/png');

      expect(imageProcessor.validateMagicBytes(webpBuffer).isValid).toBe(true);
      expect(imageProcessor.validateMagicBytes(webpBuffer).detectedType).toBe('image/webp');
    });

    it('rejects invalid or non-image buffers', async () => {
      const textBuffer = Buffer.from('console.log("malicious code");');
      expect(imageProcessor.validateMagicBytes(textBuffer).isValid).toBe(false);

      await expect(imageProcessor.processImage(textBuffer)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('processes standard image into standard, medium, and thumbnail WebP variants', async () => {
      const testBuffer = await sharp({
        create: { width: 800, height: 600, channels: 3, background: { r: 100, g: 150, b: 200 } },
      })
        .jpeg()
        .toBuffer();

      const result = await imageProcessor.processImage(testBuffer, false);

      expect(result.standard).toBeDefined();
      expect(result.standard.mimeType).toBe('image/webp');
      expect(result.standard.width).toBe(800);
      expect(result.standard.height).toBe(600);

      expect(result.thumbnail).toBeDefined();
      expect(result.thumbnail.mimeType).toBe('image/webp');
      expect(result.thumbnail.width).toBeLessThanOrEqual(400);

      expect(result.medium).toBeDefined();
    });

    it('forces 1:1 square crop and standard 1024x1024 for profile avatars', async () => {
      // 800x400 landscape image
      const landscapeBuffer = await sharp({
        create: { width: 800, height: 400, channels: 3, background: { r: 255, g: 100, b: 50 } },
      })
        .jpeg()
        .toBuffer();

      const result = await imageProcessor.processImage(landscapeBuffer, true);

      // Standard avatar must be a perfect 1:1 square
      expect(result.standard.width).toBe(1024);
      expect(result.standard.height).toBe(1024);
      expect(result.standard.mimeType).toBe('image/webp');

      // Thumbnail avatar must be a square
      expect(result.thumbnail.width).toBe(256);
      expect(result.thumbnail.height).toBe(256);
    });
  });

  describe('LocalMediaStorageService', () => {
    it('stores file and prevents directory traversal in keys', async () => {
      const sampleBuffer = Buffer.from('test image binary');
      const uploaded = await storageService.uploadFile({
        key: '../../../etc/passwd.webp',
        buffer: sampleBuffer,
        contentType: 'image/webp',
      });

      // Traversal stripped
      expect(uploaded.key).not.toContain('..');
      expect(uploaded.key).toBe('passwd.webp');
      expect(uploaded.url).toContain('/api/v1/media/files/passwd.webp');

      const retrieved = await storageService.getFile('passwd.webp');
      expect(retrieved).not.toBeNull();
      expect(retrieved!.buffer.toString()).toBe('test image binary');
    });

    it('returns null for non-existent files', async () => {
      const result = await storageService.getFile('non-existent.webp');
      expect(result).toBeNull();
    });
  });

  describe('MediaService', () => {
    it('uploads single image and returns metadata with thumbnailUrl and standard URL', async () => {
      const testBuffer = await sharp({
        create: { width: 600, height: 400, channels: 3, background: { r: 50, g: 120, b: 200 } },
      })
        .jpeg()
        .toBuffer();

      const mockFile = {
        fieldname: 'file',
        originalname: 'photo.jpg',
        encoding: '7bit',
        mimetype: 'image/jpeg',
        buffer: testBuffer,
        size: testBuffer.length,
      } as Express.Multer.File;

      const response = await mediaService.uploadImage(mockFile, 'post', '192.168.1.100:3000');

      expect(response.url).toContain('http://192.168.1.100:3000/api/v1/media/files/img_');
      expect(response.thumbnailUrl).toContain('http://192.168.1.100:3000/api/v1/media/files/thumb_');
      expect(response.width).toBe(600);
      expect(response.height).toBe(400);
      expect(response.mimeType).toBe('image/webp');
      expect(response.type).toBe('post');
    });

    it('rejects unsupported mime types', async () => {
      const mockFile = {
        fieldname: 'file',
        originalname: 'script.sh',
        encoding: '7bit',
        mimetype: 'application/x-sh',
        buffer: Buffer.from('echo hello'),
        size: 10,
      } as Express.Multer.File;

      await expect(mediaService.uploadImage(mockFile)).rejects.toThrow(BadRequestException);
    });

    it('rejects oversized files', async () => {
      const mockFile = {
        fieldname: 'file',
        originalname: 'huge.jpg',
        encoding: '7bit',
        mimetype: 'image/jpeg',
        buffer: Buffer.alloc(10),
        size: 20 * 1024 * 1024, // 20 MB
      } as Express.Multer.File;

      await expect(mediaService.uploadImage(mockFile)).rejects.toThrow(BadRequestException);
    });

    it('uploads multiple images in batch', async () => {
      const testBuffer = await sharp({
        create: { width: 200, height: 200, channels: 3, background: { r: 10, g: 20, b: 30 } },
      })
        .png()
        .toBuffer();

      const files = [
        {
          fieldname: 'files',
          originalname: 'one.png',
          mimetype: 'image/png',
          buffer: testBuffer,
          size: testBuffer.length,
        },
        {
          fieldname: 'files',
          originalname: 'two.png',
          mimetype: 'image/png',
          buffer: testBuffer,
          size: testBuffer.length,
        },
      ] as Express.Multer.File[];

      const responses = await mediaService.uploadImages(files, 'marketplace');

      expect(responses).toHaveLength(2);
      expect(responses[0].url).toBeDefined();
      expect(responses[1].url).toBeDefined();
    });
  });
});
