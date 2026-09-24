import { Module } from '@nestjs/common';
import { LocalitiesService } from './localities.service.js';
import { LocalitiesController } from './localities.controller.js';

@Module({
  controllers: [LocalitiesController],
  providers: [LocalitiesService],
  exports: [LocalitiesService],
})
export class LocalitiesModule {}
