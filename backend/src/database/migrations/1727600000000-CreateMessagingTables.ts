import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateMessagingTables1727600000000 implements MigrationInterface {
  name = 'CreateMessagingTables1727600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create Enums
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "message_type_enum" AS ENUM ('TEXT');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "conversation_report_reason_enum" AS ENUM (
          'spam', 'harassment', 'inappropriate', 'fraud', 'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "conversation_report_status_enum" AS ENUM (
          'pending', 'reviewed', 'dismissed'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 2. Create conversations table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "conversations" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user1Id" uuid NOT NULL,
        "user2Id" uuid NOT NULL,
        "lastMessageAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_conversations_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_conversations_user1_user2" UNIQUE ("user1Id", "user2Id"),
        CONSTRAINT "CHK_conversations_user_order" CHECK ("user1Id" < "user2Id"),
        CONSTRAINT "FK_conversations_user1Id" FOREIGN KEY ("user1Id")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_conversations_user2Id" FOREIGN KEY ("user2Id")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_conversations_lastMessageAt" ON "conversations" ("lastMessageAt" DESC);
      CREATE INDEX IF NOT EXISTS "IDX_conversations_user1Id" ON "conversations" ("user1Id");
      CREATE INDEX IF NOT EXISTS "IDX_conversations_user2Id" ON "conversations" ("user2Id");
    `);

    // 3. Create conversation_participants table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "conversation_participants" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "conversationId" uuid NOT NULL,
        "userId" uuid NOT NULL,
        "joinedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "lastReadMessageId" uuid,
        "lastReadAt" TIMESTAMP WITH TIME ZONE,
        "mutedAt" TIMESTAMP WITH TIME ZONE,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_conversation_participants_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_conversation_participants_conv_user" UNIQUE ("conversationId", "userId"),
        CONSTRAINT "FK_conversation_participants_conversationId" FOREIGN KEY ("conversationId")
          REFERENCES "conversations"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_conversation_participants_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_conversation_participants_userId" ON "conversation_participants" ("userId");
      CREATE INDEX IF NOT EXISTS "IDX_conversation_participants_conversationId" ON "conversation_participants" ("conversationId");
    `);

    // 4. Create messages table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "messages" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "conversationId" uuid NOT NULL,
        "senderId" uuid NOT NULL,
        "clientMessageId" character varying(100) NOT NULL,
        "content" text NOT NULL,
        "messageType" "message_type_enum" NOT NULL DEFAULT 'TEXT',
        "readAt" TIMESTAMP WITH TIME ZONE,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_messages_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_messages_sender_clientMessageId" UNIQUE ("senderId", "clientMessageId"),
        CONSTRAINT "FK_messages_conversationId" FOREIGN KEY ("conversationId")
          REFERENCES "conversations"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_messages_senderId" FOREIGN KEY ("senderId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_messages_conv_createdAt" ON "messages" ("conversationId", "createdAt" DESC);
      CREATE INDEX IF NOT EXISTS "IDX_messages_senderId" ON "messages" ("senderId");
    `);

    // 5. Create user_blocks table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "user_blocks" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "blockerId" uuid NOT NULL,
        "blockedId" uuid NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_user_blocks_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_user_blocks_blocker_blocked" UNIQUE ("blockerId", "blockedId"),
        CONSTRAINT "CHK_user_blocks_self" CHECK ("blockerId" != "blockedId"),
        CONSTRAINT "FK_user_blocks_blockerId" FOREIGN KEY ("blockerId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_user_blocks_blockedId" FOREIGN KEY ("blockedId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_user_blocks_blockerId" ON "user_blocks" ("blockerId");
      CREATE INDEX IF NOT EXISTS "IDX_user_blocks_blockedId" ON "user_blocks" ("blockedId");
    `);

    // 6. Create conversation_reports table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "conversation_reports" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "reporterId" uuid NOT NULL,
        "conversationId" uuid NOT NULL,
        "messageId" uuid,
        "reason" "conversation_report_reason_enum" NOT NULL,
        "description" character varying(500),
        "status" "conversation_report_status_enum" NOT NULL DEFAULT 'pending',
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_conversation_reports_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_conversation_reports_reporterId" FOREIGN KEY ("reporterId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_conversation_reports_conversationId" FOREIGN KEY ("conversationId")
          REFERENCES "conversations"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_conversation_reports_messageId" FOREIGN KEY ("messageId")
          REFERENCES "messages"("id") ON DELETE SET NULL ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_conversation_reports_conversationId" ON "conversation_reports" ("conversationId");
      CREATE INDEX IF NOT EXISTS "IDX_conversation_reports_reporterId" ON "conversation_reports" ("reporterId");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "conversation_reports";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "user_blocks";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "messages";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "conversation_participants";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "conversations";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "conversation_report_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "conversation_report_reason_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "message_type_enum";`);
  }
}
