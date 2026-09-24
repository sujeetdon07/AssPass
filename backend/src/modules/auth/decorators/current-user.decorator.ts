import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { Request } from 'express';

export interface CurrentUserPayload {
  userId: string;
  sessionId: string;
  phoneNumber: string;
  onboarding: boolean;
}

export const CurrentUser = createParamDecorator(
  (data: keyof CurrentUserPayload | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest<Request & { user?: CurrentUserPayload }>();
    const user = request.user;
    if (!user) return null;
    return data ? user[data] : user;
  },
);
