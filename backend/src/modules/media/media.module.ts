import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AuthSession } from '../auth/entities/auth-session.entity.js';
import { User } from '../users/entities/user.entity.js';
import { MediaController } from './media.controller.js';
import { MediaService, MEDIA_STORAGE_PROVIDER } from './services/media.service.js';
import { ImageProcessorService } from './services/image-processor.service.js';
import { LocalMediaStorageService } from './storage/local-media-storage.service.js';
import { S3MediaStorageService } from './storage/s3-media-storage.service.js';

@Module({
  imports: [
    ConfigModule,
    AuthModule,
    TypeOrmModule.forFeature([AuthSession, User]),
  ],
  controllers: [MediaController],
  providers: [
    ImageProcessorService,
    LocalMediaStorageService,
    S3MediaStorageService,
    {
      provide: MEDIA_STORAGE_PROVIDER,
      useFactory: (
        configService: ConfigService,
        localService: LocalMediaStorageService,
        s3Service: S3MediaStorageService,
      ) => {
        const storageType = configService.get<string>('MEDIA_STORAGE_TYPE', 'local');
        return storageType === 's3' ? s3Service : localService;
      },
      inject: [ConfigService, LocalMediaStorageService, S3MediaStorageService],
    },
    MediaService,
  ],
  exports: [MediaService, MEDIA_STORAGE_PROVIDER],
})
export class MediaModule {}
