import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { Request, Response } from 'express';
import { randomUUID } from 'crypto';

/**
 * Logging interceptor.
 *
 * Logs every incoming request with:
 * - Request ID (UUID)
 * - HTTP method
 * - URL path
 * - Response status code
 * - Response time in milliseconds
 *
 * NEVER logs:
 * - Authorization headers
 * - Request bodies containing passwords, OTPs, or tokens
 * - Response bodies
 * - Private messages or personal data
 */
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') {
      return next.handle();
    }

    const request = context.switchToHttp().getRequest<Request>();
    const response = context.switchToHttp().getResponse<Response>();
    if (!request || !response || typeof response.setHeader !== 'function') {
      return next.handle();
    }

    const requestId = randomUUID();
    const { method, url } = request;
    const startTime = Date.now();

    // Attach request ID so it can be used in error filters and services.
    request.headers['x-request-id'] = requestId;
    response.setHeader('x-request-id', requestId);

    return next.handle().pipe(
      tap({
        next: () => {
          const duration = Date.now() - startTime;
          const statusCode = response.statusCode;
          this.logger.log(
            `[${requestId.slice(0, 8)}] ${method} ${url} ${statusCode} +${duration}ms`,
          );
        },
        error: () => {
          const duration = Date.now() - startTime;
          this.logger.warn(
            `[${requestId.slice(0, 8)}] ${method} ${url} ERROR +${duration}ms`,
          );
        },
      }),
    );
  }
}
