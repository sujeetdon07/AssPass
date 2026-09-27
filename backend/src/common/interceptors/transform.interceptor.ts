import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

interface SuccessResponse<T> {
  success: true;
  data: T;
}

/**
 * Transform interceptor.
 *
 * Wraps all successful controller responses in the standard envelope:
 * {
 *   success: true,
 *   data: <original response>
 * }
 *
 * Health endpoint bypasses this wrapper by returning its own
 * structured response directly (it already includes `success`).
 *
 * Error responses are handled by HttpExceptionFilter, not this interceptor.
 */
@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, SuccessResponse<T> | T> {
  intercept(
    context: ExecutionContext,
    next: CallHandler<T>,
  ): Observable<SuccessResponse<T> | T> {
    if (context.getType() !== 'http') {
      return next.handle();
    }
    return next.handle().pipe(
      map((data) => {
        // If the response already has a `success` field (like the health endpoint),
        // pass it through unchanged.
        if (data !== null && typeof data === 'object' && 'success' in (data as object)) {
          return data;
        }

        return {
          success: true,
          data,
        };
      }),
    );
  }
}
