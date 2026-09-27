import {
  Injectable,
  NotFoundException,
  ConflictException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Report, ReportTargetType, ReportStatus } from '../entities/report.entity.js';
import { Post } from '../entities/post.entity.js';
import { Comment } from '../entities/comment.entity.js';
import { CreateReportDto } from '../dto/create-report.dto.js';
import { RedisService } from '../../../database/redis.service.js';

@Injectable()
export class ReportsService {
  private readonly logger = new Logger(ReportsService.name);
  private readonly maxReportsPerHour = 10;
  private readonly rateLimitWindowSeconds = 3600;

  constructor(
    @InjectRepository(Report)
    private readonly reportRepository: Repository<Report>,
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(Comment)
    private readonly commentRepository: Repository<Comment>,
    private readonly redisService: RedisService,
  ) {}

  /**
   * Report a post for community trust and safety review.
   */
  async reportPost(
    postId: string,
    reporterId: string,
    dto: CreateReportDto,
  ): Promise<{ message: string }> {
    const post = await this.postRepository.findOne({
      where: { id: postId },
    });

    if (!post) {
      throw new NotFoundException('Post not found.');
    }

    await this.checkRateLimit(reporterId);

    const existing = await this.reportRepository.findOne({
      where: {
        reporterId,
        targetType: ReportTargetType.POST,
        targetId: postId,
      },
    });

    if (existing) {
      throw new ConflictException('You have already submitted a report for this post.');
    }

    const report = this.reportRepository.create({
      reporterId,
      targetType: ReportTargetType.POST,
      targetId: postId,
      reason: dto.reason,
      details: dto.details ?? null,
      status: ReportStatus.PENDING,
    });

    await this.reportRepository.save(report);
    await this.incrementRateLimit(reporterId);

    return { message: 'Thank you. Your report has been submitted for review.' };
  }

  /**
   * Report a comment for review.
   */
  async reportComment(
    commentId: string,
    reporterId: string,
    dto: CreateReportDto,
  ): Promise<{ message: string }> {
    const comment = await this.commentRepository.findOne({
      where: { id: commentId },
    });

    if (!comment) {
      throw new NotFoundException('Comment not found.');
    }

    await this.checkRateLimit(reporterId);

    const existing = await this.reportRepository.findOne({
      where: {
        reporterId,
        targetType: ReportTargetType.COMMENT,
        targetId: commentId,
      },
    });

    if (existing) {
      throw new ConflictException('You have already submitted a report for this comment.');
    }

    const report = this.reportRepository.create({
      reporterId,
      targetType: ReportTargetType.COMMENT,
      targetId: commentId,
      reason: dto.reason,
      details: dto.details ?? null,
      status: ReportStatus.PENDING,
    });

    await this.reportRepository.save(report);
    await this.incrementRateLimit(reporterId);

    return { message: 'Thank you. Your report has been submitted for review.' };
  }

  private async checkRateLimit(reporterId: string): Promise<void> {
    const rateKey = `rate:report:${reporterId}`;
    const currentRate = await this.redisService.get(rateKey);
    const count = currentRate ? parseInt(currentRate, 10) : 0;

    if (count >= this.maxReportsPerHour) {
      throw new HttpException(
        {
          code: 'RATE_LIMITED',
          message: 'Too many reports submitted. Please wait before reporting again.',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private async incrementRateLimit(reporterId: string): Promise<void> {
    const rateKey = `rate:report:${reporterId}`;
    if (typeof this.redisService.incrementWithExpire === 'function') {
      await this.redisService.incrementWithExpire(rateKey, this.rateLimitWindowSeconds);
    } else {
      await this.redisService.incr(rateKey);
    }
  }
}
