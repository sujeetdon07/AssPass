import { io } from 'socket.io-client';

const API_BASE = 'http://localhost:3000/api/v1';
const WS_BASE = 'http://localhost:3000';

async function request(path, options = {}) {
  const url = `${API_BASE}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, ok: res.ok, data };
}

async function loginUser(phoneNumber, name) {
  // 1. Request OTP
  const otpRes = await request('/auth/otp/request', {
    method: 'POST',
    body: JSON.stringify({ phoneNumber }),
  });
  if (!otpRes.ok) throw new Error(`OTP request failed: ${JSON.stringify(otpRes.data)}`);
  const otp = otpRes.data.data.devOtp || '123456';

  const verifyRes = await request('/auth/otp/verify', {
    method: 'POST',
    body: JSON.stringify({ phoneNumber, otp }),
  });
  if (!verifyRes.ok) throw new Error(`OTP verify failed: ${JSON.stringify(verifyRes.data)}`);

  const { tokens, user } = verifyRes.data.data;
  const accessToken = tokens.accessToken;

  // Complete onboarding if needed
  if (!user.onboardingCompleted) {
    const obRes = await request('/users/me/onboarding', {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify({
        displayName: name,
        locality: 'Indiranagar',
        city: 'Bengaluru',
      }),
    });
    if (obRes.ok) {
      return { accessToken, user: obRes.data.data };
    }
  }

  return { accessToken, user };
}

function generatePhoneNumber() {
  const rand = Math.floor(10000000 + Math.random() * 90000000);
  return `+9198${rand}`;
}

async function main() {
  console.log('=== AASPAAS PHASE 8 MESSAGING RUNTIME VERIFICATION ===\n');

  // 1. Authenticate two test users
  console.log('1. Authenticating test users...');
  const phoneA = generatePhoneNumber();
  const phoneB = generatePhoneNumber();
  const userA = await loginUser(phoneA, 'Aarav Sharma');
  console.log(`   User A: id=${userA.user.id}, phone=${phoneA}`);

  const userB = await loginUser(phoneB, 'Bhavna Patel');
  console.log(`   User B: id=${userB.user.id}, phone=${phoneB}`);

  const authHeaderA = { Authorization: `Bearer ${userA.accessToken}` };
  const authHeaderB = { Authorization: `Bearer ${userB.accessToken}` };

  // 2. Reject self-conversation
  console.log('\n2. Testing self-conversation prevention...');
  const selfConv = await request('/messaging/conversations', {
    method: 'POST',
    headers: authHeaderA,
    body: JSON.stringify({ participantId: userA.user.id }),
  });
  console.log(`   Self-conversation status: ${selfConv.status} (Expected: 400)`);
  if (selfConv.status !== 400) {
    console.log('   Self-conv error response:', JSON.stringify(selfConv.data));
    throw new Error('Self conversation was not rejected with 400!');
  }

  // 3. Create conversation between User A and User B
  console.log('\n3. Creating direct conversation (User A -> User B)...');
  const convRes1 = await request('/messaging/conversations', {
    method: 'POST',
    headers: authHeaderA,
    body: JSON.stringify({ participantId: userB.user.id }),
  });
  console.log(`   Create conversation status: ${convRes1.status} (Expected: 201)`);
  if (!convRes1.ok) throw new Error(`Create conversation failed: ${JSON.stringify(convRes1.data)}`);
  const convId = convRes1.data.data.id;
  console.log(`   Created conversation ID: ${convId}`);

  // 4. Test duplicate prevention (idempotency)
  console.log('\n4. Testing duplicate conversation prevention (User B -> User A)...');
  const convRes2 = await request('/messaging/conversations', {
    method: 'POST',
    headers: authHeaderB,
    body: JSON.stringify({ participantId: userA.user.id }),
  });
  console.log(`   Status: ${convRes2.status}`);
  if (convRes2.data.data.id !== convId) {
    throw new Error(`Duplicate conversation was created! Expected ${convId}, got ${convRes2.data.data.id}`);
  }
  console.log('   Duplicate conversation prevented successfully (exact same conversation ID returned).');

  // 5. Test safe profile projection in conversation list
  console.log('\n5. Testing conversation list & safe profile projection...');
  const listRes = await request('/messaging/conversations', {
    headers: authHeaderA,
  });
  console.log(`   List status: ${listRes.status}`);
  const items = listRes.data.data.items;
  console.log(`   Found ${items.length} conversations for User A.`);
  const participantProj = items[0].participant;
  console.log('   Participant projection:', participantProj);
  if (participantProj.phoneNumber || participantProj.email || participantProj.password) {
    throw new Error('SECURITY VIOLATION: Private credentials exposed in participant projection!');
  }
  console.log('   Security verification passed: No private phone/email/password exposed.');

  // 6. Test REST message sending with idempotency
  console.log('\n6. Testing REST message sending & idempotency...');
  const clientMessageId = `test-cli-${Date.now()}`;
  const sendRes1 = await request(`/messaging/conversations/${convId}/messages`, {
    method: 'POST',
    headers: authHeaderA,
    body: JSON.stringify({
      clientMessageId,
      content: 'Hello Bhavna! Welcome to Aaspaas neighbor chat.',
    }),
  });
  console.log(`   Send message status: ${sendRes1.status} (Expected: 201)`);
  if (!sendRes1.ok) throw new Error(`Send message failed: ${JSON.stringify(sendRes1.data)}`);
  const msg1 = sendRes1.data.data;
  console.log(`   Message ID: ${msg1.id}, clientMessageId: ${msg1.clientMessageId}`);

  // Retrying the exact same message must return the existing message without duplicate insertion
  console.log('   Retrying same clientMessageId (idempotency check)...');
  const sendRes2 = await request(`/messaging/conversations/${convId}/messages`, {
    method: 'POST',
    headers: authHeaderA,
    body: JSON.stringify({
      clientMessageId,
      content: 'Hello Bhavna! Welcome to Aaspaas neighbor chat.',
    }),
  });
  console.log(`   Retry status: ${sendRes2.status}`);
  if (sendRes2.data.data.id !== msg1.id) {
    throw new Error('Duplicate message created for same clientMessageId!');
  }
  console.log('   Idempotency verified: Same message returned, no duplicate created.');

  // 7. Test cursor-based message history
  console.log('\n7. Testing message history pagination...');
  const histRes = await request(`/messaging/conversations/${convId}/messages`, {
    headers: authHeaderB,
  });
  console.log(`   History status: ${histRes.status}, items count: ${histRes.data.data.items.length}`);
  if (histRes.data.data.items.length === 0) throw new Error('Message history is empty!');

  // 8. Test unread count & mark as read
  console.log('\n8. Testing unread count & mark as read...');
  const convListB = await request('/messaging/conversations', { headers: authHeaderB });
  const unreadBefore = convListB.data.data.items.find((c) => c.id === convId)?.unreadCount ?? 0;
  console.log(`   User B unread count before read: ${unreadBefore} (Expected >= 1)`);

  const readRes = await request(`/messaging/conversations/${convId}/read`, {
    method: 'POST',
    headers: authHeaderB,
  });
  console.log(`   Mark as read status: ${readRes.status}`);

  const convListBAfter = await request('/messaging/conversations', { headers: authHeaderB });
  const unreadAfter = convListBAfter.data.data.items.find((c) => c.id === convId)?.unreadCount ?? 0;
  console.log(`   User B unread count after read: ${unreadAfter} (Expected: 0)`);
  if (unreadAfter !== 0) throw new Error('Unread count was not reset to 0 after mark as read!');

  // 9. Test blocking protection
  console.log('\n9. Testing Trust & Safety blocking protection...');
  const blockRes = await request('/messaging/blocks', {
    method: 'POST',
    headers: authHeaderA,
    body: JSON.stringify({ userId: userB.user.id }),
  });
  console.log(`   User A blocked User B, status: ${blockRes.status}`);

  const blockedSendRes = await request(`/messaging/conversations/${convId}/messages`, {
    method: 'POST',
    headers: authHeaderB,
    body: JSON.stringify({
      clientMessageId: `blocked-${Date.now()}`,
      content: 'This should be blocked',
    }),
  });
  console.log(`   User B sends to User A while blocked: status ${blockedSendRes.status} (Expected: 403)`);
  if (blockedSendRes.status !== 403) throw new Error('Blocked user was not rejected with 403!');

  // Unblock
  const unblockRes = await request(`/messaging/blocks/${userB.user.id}`, {
    method: 'DELETE',
    headers: authHeaderA,
  });
  console.log(`   Unblocked User B, status: ${unblockRes.status}`);

  // 10. Test conversation reporting & duplicate prevention
  console.log('\n10. Testing conversation reporting & duplicate report prevention...');
  const reportRes = await request(`/messaging/conversations/${convId}/report`, {
    method: 'POST',
    headers: authHeaderB,
    body: JSON.stringify({
      reason: 'spam',
      description: 'Suspicious commercial solicitation',
    }),
  });
  console.log(`   Report status: ${reportRes.status}`);
  if (reportRes.status === 201) {
    console.log('   Report submitted successfully.');
    // Immediate retry should return 409
    const dupReport = await request(`/messaging/conversations/${convId}/report`, {
      method: 'POST',
      headers: authHeaderB,
      body: JSON.stringify({
        reason: 'spam',
        description: 'Duplicate attempt',
      }),
    });
    console.log(`   Duplicate report status: ${dupReport.status} (Expected: 409)`);
    if (dupReport.status !== 409) throw new Error('Duplicate report was not rejected with 409!');
  } else if (reportRes.status === 409) {
    console.log('   Duplicate report prevention confirmed (409 Conflict).');
  } else {
    throw new Error(`Report failed unexpectedly: ${JSON.stringify(reportRes.data)}`);
  }

  // 11. Test WebSocket / Socket.IO real-time flows
  console.log('\n11. Testing WebSocket / Socket.IO (/messaging)...');

  // Test unauthorized socket connection rejection
  await new Promise((resolve) => {
    const unauthSocket = io(`${WS_BASE}/messaging`, {
      auth: { token: 'invalid-jwt-token' },
      transports: ['websocket'],
      reconnection: false,
    });
    unauthSocket.on('connect_error', (err) => {
      console.log(`   Unauthenticated socket rejected properly: ${err.message}`);
      unauthSocket.close();
      resolve();
    });
    unauthSocket.on('connect', () => {
      unauthSocket.close();
      throw new Error('Unauthenticated socket connected unexpectedly!');
    });
  });

  // Connect authorized sockets for User A and User B
  const socketA = io(`${WS_BASE}/messaging`, {
    auth: { token: userA.accessToken },
    transports: ['websocket'],
  });
  const socketB = io(`${WS_BASE}/messaging`, {
    auth: { token: userB.accessToken },
    transports: ['websocket'],
  });

  await Promise.all([
    new Promise((resolve) => socketA.on('connect', resolve)),
    new Promise((resolve) => socketB.on('connect', resolve)),
  ]);
  console.log('   Both User A and User B connected to Socket.IO gateway with valid JWT.');

  // Check presence
  const presenceRes = await request(`/messaging/presence/${userA.user.id}`, {
    headers: authHeaderA,
  });
  console.log('   User A presence status in Redis:', presenceRes.data.data);

  // Both join conversation room and await acknowledgement
  await Promise.all([
    new Promise((res) => {
      socketA.once('conversation:joined', res);
      socketA.emit('conversation:join', { conversationId: convId });
    }),
    new Promise((res) => {
      socketB.once('conversation:joined', res);
      socketB.emit('conversation:join', { conversationId: convId });
    }),
  ]);
  console.log('   Both sockets joined conversation room.');

  // Test real-time typing indicator
  console.log('\n12. Testing real-time typing indicators...');
  const typingPromise = new Promise((resolve) => {
    socketB.on('typing:start', (data) => {
      console.log('   User B received typing:start event:', data);
      resolve(data);
    });
  });
  socketA.emit('typing:start', { conversationId: convId });
  await typingPromise;

  // Test real-time message sending & receiving
  console.log('\n13. Testing real-time message exchange & ACK...');
  const wsClientMsgId = `ws-${Date.now()}`;
  const receivePromise = new Promise((resolve) => {
    socketB.on('message:new', (data) => {
      console.log('   User B received message:new event in real-time:', {
        id: data.id,
        content: data.content,
        clientMessageId: data.clientMessageId,
      });
      resolve(data);
    });
  });

  const ackPromise = new Promise((resolve) => {
    socketA.on('message:ack', (data) => {
      console.log('   User A received message:ack event:', data);
      resolve(data);
    });
  });

  socketA.emit('message:send', {
    conversationId: convId,
    clientMessageId: wsClientMsgId,
    content: 'Real-time WebSocket message between neighbors!',
  });

  const [receivedMsg, ackMsg] = await Promise.all([receivePromise, ackPromise]);
  if (receivedMsg.clientMessageId !== wsClientMsgId) {
    throw new Error('Mismatch in received clientMessageId!');
  }
  if (ackMsg.clientMessageId !== wsClientMsgId) {
    throw new Error('Mismatch in ACK clientMessageId!');
  }
  console.log('   Real-time message exchange & acknowledgement verified successfully.');

  // Clean up sockets
  socketA.close();
  socketB.close();

  console.log('\n=== ALL PHASE 8 RUNTIME VERIFICATION CHECKS PASSED PERFECTLY ===\n');
}

main().catch((err) => {
  console.error('\n❌ VERIFICATION FAILED:', err);
  process.exit(1);
});
