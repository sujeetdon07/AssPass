import { plainToInstance } from 'class-transformer';
import { IsEnum, IsInt, IsString, IsOptional, validateSync, Min, Max } from 'class-validator';

enum Environment {
  Development = 'development',
  Staging = 'staging',
  Production = 'production',
  Test = 'test',
}

/**
 * Declares and validates all expected environment variables.
 *
 * If a required variable is missing or invalid, the application will
 * refuse to start with a clear error message.
 */
class EnvironmentVariables {
  @IsEnum(Environment)
  NODE_ENV: Environment = Environment.Development;

  @IsInt()
  @Min(1)
  @Max(65535)
  PORT: number = 3000;

  @IsString()
  DATABASE_URL!: string;

  @IsString()
  REDIS_HOST: string = 'localhost';

  @IsInt()
  @Min(1)
  @Max(65535)
  REDIS_PORT: number = 6379;

  @IsString()
  @IsOptional()
  REDIS_PASSWORD?: string;

  @IsString()
  @IsOptional()
  JWT_ACCESS_SECRET?: string;

  @IsString()
  @IsOptional()
  JWT_REFRESH_SECRET?: string;

  @IsString()
  @IsOptional()
  JWT_ACCESS_TTL?: string = '15m';

  @IsString()
  @IsOptional()
  JWT_REFRESH_TTL?: string = '30d';

  @IsInt()
  @IsOptional()
  @Min(30)
  @Max(3600)
  OTP_TTL_SECONDS?: number = 300;

  @IsInt()
  @IsOptional()
  @Min(1)
  @Max(10)
  OTP_MAX_ATTEMPTS?: number = 5;

  @IsInt()
  @IsOptional()
  @Min(10)
  @Max(300)
  OTP_RESEND_COOLDOWN_SECONDS?: number = 60;

  @IsString()
  @IsOptional()
  ALLOWED_ORIGINS?: string;

  @IsString()
  @IsOptional()
  DATABASE_SSL?: string;
}

/**
 * Validates environment variables at startup.
 * Called by ConfigModule.forRoot({ validate }).
 */
export function validateConfig(config: Record<string, unknown>): EnvironmentVariables {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });

  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    throw new Error(
      `[Aaspaas] Environment configuration validation failed:\n${errors
        .map((e) => Object.values(e.constraints ?? {}).join(', '))
        .join('\n')}`,
    );
  }

  return validatedConfig;
}
