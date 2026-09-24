import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

interface ErrorResponse {
  success: false;
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
  path: string;
  timestamp: string;
}

/**
 * Global HTTP exception filter.
 *
 * Normalizes all exceptions into a consistent response envelope:
 * {
 *   success: false,
 *   error: { code, message, details },
 *   path,
 *   timestamp
 * }
 *
 * NEVER includes:
 * - Stack traces in production
 * - Internal implementation details
 * - Database error internals
 * - Sensitive configuration values
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const { status, errorCode, message, details } = this.resolveException(exception);

    // Log the error with enough context to debug, but without sensitive data.
    this.logger.error(
      `[${request.method}] ${request.url} → ${status} ${errorCode}: ${message}`,
    );

    const body: ErrorResponse = {
      success: false,
      error: {
        code: errorCode,
        message,
        details,
      },
      path: request.url,
      timestamp: new Date().toISOString(),
    };

    response.status(status).json(body);
  }

  private resolveException(exception: unknown): {
    status: number;
    errorCode: string;
    message: string;
    details?: unknown;
  } {
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'string') {
        return {
          status,
          errorCode: this.statusToCode(status),
          message: exceptionResponse,
        };
      }

      if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
        const responseObj = exceptionResponse as Record<string, unknown>;
        const message =
          typeof responseObj['message'] === 'string'
            ? responseObj['message']
            : Array.isArray(responseObj['message'])
              ? (responseObj['message'] as string[]).join('; ')
              : exception.message;

        return {
          status,
          errorCode: this.statusToCode(status),
          message,
          details: Array.isArray(responseObj['message'])
            ? responseObj['message']
            : undefined,
        };
      }
    }

    // Unknown/unhandled error — do not expose internal details.
    this.logger.error('Unhandled exception:', exception);
    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      errorCode: 'SERVER_ERROR',
      message: 'An unexpected error occurred.',
    };
  }

  private statusToCode(status: number): string {
    const map: Record<number, string> = {
      400: 'VALIDATION_ERROR',
      401: 'UNAUTHORIZED',
      403: 'FORBIDDEN',
      404: 'NOT_FOUND',
      409: 'CONFLICT',
      422: 'UNPROCESSABLE',
      429: 'RATE_LIMITED',
      500: 'SERVER_ERROR',
    };
    return map[status] ?? 'ERROR';
  }
}
