export const MessagingEvents = {
  // Client -> Server
  CLIENT_CONVERSATION_JOIN: 'conversation:join',
  CLIENT_CONVERSATION_LEAVE: 'conversation:leave',
  CLIENT_MESSAGE_SEND: 'message:send',
  CLIENT_MESSAGE_READ: 'message:read',
  CLIENT_TYPING_START: 'typing:start',
  CLIENT_TYPING_STOP: 'typing:stop',
  CLIENT_PRESENCE_SUBSCRIBE: 'presence:subscribe',

  // Server -> Client
  SERVER_CONVERSATION_JOINED: 'conversation:joined',
  SERVER_MESSAGE_NEW: 'message:new',
  SERVER_MESSAGE_ACK: 'message:ack',
  SERVER_MESSAGE_READ: 'message:read',
  SERVER_TYPING_START: 'typing:start',
  SERVER_TYPING_STOP: 'typing:stop',
  SERVER_PRESENCE_UPDATE: 'presence:update',
  SERVER_CONVERSATION_UPDATE: 'conversation:update',
  SERVER_ERROR: 'error',
} as const;

export type MessagingEventName = (typeof MessagingEvents)[keyof typeof MessagingEvents];
