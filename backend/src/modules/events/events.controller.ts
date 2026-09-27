import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  ParseUUIDPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import {
  CurrentUser,
  type CurrentUserPayload,
} from '../auth/decorators/current-user.decorator.js';
import { EventsService } from './events.service.js';
import { CreateEventDto } from './dto/create-event.dto.js';
import { UpdateEventDto } from './dto/update-event.dto.js';
import { CancelEventDto } from './dto/cancel-event.dto.js';
import { RsvpEventDto } from './dto/rsvp-event.dto.js';
import { GetEventsQueryDto } from './dto/get-events-query.dto.js';

@ApiTags('events')
@Controller({ path: 'events', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new local community event' })
  @ApiResponse({ status: 201, description: 'Event created successfully' })
  @ApiResponse({ status: 400, description: 'Validation failed or invalid dates' })
  @ApiResponse({ status: 403, description: 'Forbidden (not a member of private community)' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded' })
  async createEvent(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateEventDto,
  ) {
    return this.eventsService.createEvent(user.userId, dto);
  }

  @Get()
  @ApiOperation({
    summary: 'Discover upcoming local events with locality, category, community, radius, and pagination',
  })
  @ApiResponse({ status: 200, description: 'Paginated events discovery list' })
  async getEvents(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetEventsQueryDto,
  ) {
    return this.eventsService.getEvents(user.userId, query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get event details by ID' })
  @ApiParam({ name: 'id', description: 'Event UUID' })
  @ApiResponse({ status: 200, description: 'Event details' })
  @ApiResponse({ status: 403, description: 'Forbidden (private community event not joined)' })
  @ApiResponse({ status: 404, description: 'Event not found' })
  async getEventById(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.eventsService.getEventById(id, user.userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update event details (Organizer only)' })
  @ApiParam({ name: 'id', description: 'Event UUID' })
  @ApiResponse({ status: 200, description: 'Event updated successfully' })
  @ApiResponse({ status: 400, description: 'Invalid dates or cancelled event' })
  @ApiResponse({ status: 403, description: 'Forbidden - not organizer' })
  @ApiResponse({ status: 404, description: 'Event not found' })
  async updateEvent(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateEventDto,
  ) {
    return this.eventsService.updateEvent(id, user.userId, dto);
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cancel event and notify participants (Organizer only)' })
  @ApiParam({ name: 'id', description: 'Event UUID' })
  @ApiResponse({ status: 200, description: 'Event cancelled successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not organizer' })
  @ApiResponse({ status: 404, description: 'Event not found' })
  async cancelEvent(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CancelEventDto,
  ) {
    return this.eventsService.cancelEvent(id, user.userId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Soft delete event (Organizer only)' })
  @ApiParam({ name: 'id', description: 'Event UUID' })
  @ApiResponse({ status: 200, description: 'Event deleted successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not organizer' })
  @ApiResponse({ status: 404, description: 'Event not found' })
  async deleteEvent(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.eventsService.deleteEvent(id, user.userId);
  }

  @Post(':id/rsvp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'RSVP to attend an event' })
  @ApiParam({ name: 'id', description: 'Event UUID' })
  @ApiResponse({ status: 200, description: 'RSVP confirmed' })
  @ApiResponse({ status: 400, description: 'Cannot RSVP to cancelled or past event' })
  @ApiResponse({ status: 403, description: 'Forbidden - private community event' })
  @ApiResponse({ status: 404, description: 'Event not found' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded' })
  async rsvpEvent(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: RsvpEventDto,
  ) {
    return this.eventsService.rsvpEvent(id, user.userId, dto);
  }

  @Delete(':id/rsvp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cancel RSVP to an event' })
  @ApiParam({ name: 'id', description: 'Event UUID' })
  @ApiResponse({ status: 200, description: 'RSVP cancelled' })
  @ApiResponse({ status: 404, description: 'Event not found' })
  async cancelRsvp(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.eventsService.cancelRsvp(id, user.userId);
  }

  @Get(':id/participants')
  @ApiOperation({ summary: 'Get paginated list of participants for an event' })
  @ApiParam({ name: 'id', description: 'Event UUID' })
  @ApiResponse({ status: 200, description: 'Paginated participants list' })
  @ApiResponse({ status: 403, description: 'Forbidden - private community event' })
  @ApiResponse({ status: 404, description: 'Event not found' })
  async getEventParticipants(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Query('limit') limit?: number,
    @Query('cursor') cursor?: string,
  ) {
    return this.eventsService.getEventParticipants(id, user.userId, limit, cursor);
  }
}
