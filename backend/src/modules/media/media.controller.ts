import {
  Controller,
  Post,
  Get,
  Param,
  Query,
  UseInterceptors,
  UploadedFile,
  UploadedFiles,
  UseGuards,
  Req,
  Res,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiConsumes,
  ApiBearerAuth,
  ApiResponse,
  ApiQuery,
} from '@nestjs/swagger';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import type { Request, Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { MediaService } from './services/media.service.js';
import { UploadImageResponseDto } from './dto/upload-image-response.dto.js';
import type { UploadFile } from './interfaces/upload-file.interface.js';

@ApiTags('media')
@Controller({ path: 'media', version: '1' })
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  /**
   * Uploads a single image.
   */
  @Post('images')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({
    summary: 'Upload and optimize a single image',
    description:
      'Uploads a single image file, optimizes it to WebP format, strips EXIF, generates thumbnails, and returns public URLs.',
  })
  @ApiConsumes('multipart/form-data')
  @ApiQuery({
    name: 'type',
    required: false,
    description: 'Image role: "avatar" (forces 1:1 square crop) or "content"',
    example: 'avatar',
  })
  @ApiResponse({
    status: 201,
    description: 'Image successfully uploaded and processed',
    type: UploadImageResponseDto,
  })
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 15 * 1024 * 1024, // 15 MB
      },
    }),
  )
  async uploadImage(
    @UploadedFile() file: UploadFile,
    @Query('type') imageType = 'content',
    @Req() req: Request,
  ): Promise<UploadImageResponseDto> {
    if (!file) {
      throw new BadRequestException('No image file uploaded in "file" field.');
    }

    const hostHeader = req.get('host');
    return this.mediaService.uploadImage(file, imageType, hostHeader);
  }

  /**
   * Uploads multiple images in batch.
   */
  @Post('images/batch')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({
    summary: 'Upload and optimize multiple images (up to 10)',
    description:
      'Uploads multiple images, optimizes each to WebP format, strips EXIF, generates thumbnails, and returns public URLs.',
  })
  @ApiConsumes('multipart/form-data')
  @ApiQuery({
    name: 'type',
    required: false,
    description: 'Image role (e.g. "marketplace", "post", "event")',
    example: 'marketplace',
  })
  @ApiResponse({
    status: 201,
    description: 'Images successfully uploaded and processed',
    type: [UploadImageResponseDto],
  })
  @UseInterceptors(
    FilesInterceptor('files', 10, {
      limits: {
        fileSize: 15 * 1024 * 1024,
      },
    }),
  )
  async uploadImages(
    @UploadedFiles() files: UploadFile[],
    @Query('type') imageType = 'content',
    @Req() req: Request,
  ): Promise<UploadImageResponseDto[]> {
    if (!files || files.length === 0) {
      throw new BadRequestException('No image files uploaded in "files" field.');
    }

    const hostHeader = req.get('host');
    return this.mediaService.uploadImages(files, imageType, hostHeader);
  }

  /**
   * Serves an uploaded media file with aggressive caching and path traversal protection.
   */
  @Get('files/:filename')
  @ApiOperation({
    summary: 'Serve a stored media file',
    description:
      'Public endpoint that streams optimized media images with caching headers and strict filename sanitization.',
  })
  @ApiResponse({ status: 200, description: 'Image binary stream' })
  @ApiResponse({ status: 404, description: 'File not found' })
  async getFile(
    @Param('filename') filename: string,
    @Res() res: Response,
  ): Promise<void> {
    // Strict filename validation to prevent directory traversal
    if (!/^[a-zA-Z0-9_\-.]+$/.test(filename)) {
      throw new BadRequestException('Invalid filename format.');
    }

    const file = await this.mediaService.getFile(filename);
    if (!file) {
      throw new NotFoundException('Requested image was not found.');
    }

    res.setHeader('Content-Type', file.contentType);
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.send(file.buffer);
  }
}
