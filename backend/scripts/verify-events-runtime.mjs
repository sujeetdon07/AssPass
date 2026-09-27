import pg from 'pg';
const { Client } = pg;

const API_BASE = 'http://localhost:3000/api/v1';

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

function generatePhoneNumber() {
  const rand = Math.floor(10000000 + Math.random() * 90000000);
  return `+9197${rand}`;
}

async function loginUser(phoneNumber, name) {
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

async function runEventsVerification() {
  console.log('========================================================================');
  console.log('    AASPAAS — EVENTS RUNTIME END-TO-END VERIFICATION (15 STEPS)        ');
  console.log('========================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✓ ${message}`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: ${message}`);
      failed++;
    }
  }

  // Database verification
  const dbClient = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db',
  });
  await dbClient.connect();
  console.log('✓ Connected to PostgreSQL database.');

  try {
    // 0. Setup Users
    console.log('\n--- Setup Test Users ---');
    const phoneA = generatePhoneNumber();
    const phoneB = generatePhoneNumber();

    const userA = await loginUser(phoneA, 'Arun Organizer');
    const userB = await loginUser(phoneB, 'Bhavna Attendee');
    console.log(`User A (Organizer): ID=${userA.user.id}, Phone=${phoneA}`);
    console.log(`User B (Attendee):  ID=${userB.user.id}, Phone=${phoneB}`);

    const authHeadersA = { Authorization: `Bearer ${userA.accessToken}` };
    const authHeadersB = { Authorization: `Bearer ${userB.accessToken}` };

    let createdEventId = null;

    // STEP 1: Authenticated user creates event
    console.log('\n[Step 1] Authenticated user creates event');
    const tomorrow = new Date(Date.now() + 86400000);
    const tomorrowEnd = new Date(Date.now() + 86400000 + 7200000);

    const createPayload = {
      title: 'Indiranagar Neighborhood Solar Workshop',
      description: 'Learn how to install rooftop solar panels for independent homes and apartments.',
      category: 'workshop',
      startAt: tomorrow.toISOString(),
      endAt: tomorrowEnd.toISOString(),
      timezone: 'Asia/Kolkata',
      venue: 'Indiranagar Club Hall A',
      address: '4th Cross, Indiranagar',
      locality: 'Indiranagar',
      city: 'Bengaluru',
      latitude: 12.9784,
      longitude: 77.6408,
      coverImageUrl: 'https://images.unsplash.com/photo-1509391365360-2e959784a276',
    };

    const createRes = await request('/events', {
      method: 'POST',
      headers: authHeadersA,
      body: JSON.stringify(createPayload),
    });

    assert(createRes.status === 201, `Create event returns 201 (status: ${createRes.status})`);
    assert(createRes.data.data?.id !== undefined, 'Created event has valid ID');
    assert(createRes.data.data?.title === createPayload.title, 'Created event title matches');
    assert(createRes.data.data?.creatorId === userA.user.id, 'Creator ID matches organizer');
    assert(createRes.data.data?.participantCount === 1, 'Organizer is auto-RSVPed as going (count=1)');

    createdEventId = createRes.data.data?.id;

    // STEP 2: Event appears in discovery
    console.log('\n[Step 2] Event appears in discovery');
    const discoveryRes = await request(`/events?locality=Indiranagar&timeframe=upcoming&category=workshop`, {
      method: 'GET',
      headers: authHeadersB,
    });

    assert(discoveryRes.status === 200, `Discovery endpoint returns 200 (status: ${discoveryRes.status})`);
    const foundInDiscovery = discoveryRes.data.data?.items?.some(e => e.id === createdEventId);
    assert(foundInDiscovery === true, 'Created event appears in upcoming discovery list');

    // STEP 3: Event details load
    console.log('\n[Step 3] Event details load');
    const detailRes = await request(`/events/${createdEventId}`, {
      method: 'GET',
      headers: authHeadersA,
    });

    assert(detailRes.status === 200, `Event details return 200 (status: ${detailRes.status})`);
    assert(detailRes.data.data?.id === createdEventId, 'Detail ID matches');
    assert(detailRes.data.data?.isOrganizer === true, 'User A is recognized as organizer');
    assert(detailRes.data.data?.userRsvpStatus === 'going', 'User A RSVP status is going');

    // STEP 4: Second user views event
    console.log('\n[Step 4] Second user views event');
    const detailResB = await request(`/events/${createdEventId}`, {
      method: 'GET',
      headers: authHeadersB,
    });

    assert(detailResB.status === 200, `Second user views event returns 200`);
    assert(detailResB.data.data?.isOrganizer === false, 'User B is NOT recognized as organizer');
    assert(detailResB.data.data?.userRsvpStatus === null, 'User B has not yet RSVPed');

    // STEP 5: Second user RSVPs
    console.log('\n[Step 5] Second user RSVPs');
    const rsvpRes = await request(`/events/${createdEventId}/rsvp`, {
      method: 'POST',
      headers: authHeadersB,
      body: JSON.stringify({ status: 'going' }),
    });

    assert(rsvpRes.status === 200, `RSVP returns 200 (status: ${rsvpRes.status})`);
    const rsvpStatus = rsvpRes.data?.data?.status || rsvpRes.data?.status;
    assert(rsvpStatus === 'going', 'RSVP status is going');

    // STEP 6: Participant count changes
    console.log('\n[Step 6] Participant count changes');
    const updatedDetailB = await request(`/events/${createdEventId}`, {
      method: 'GET',
      headers: authHeadersB,
    });

    assert(updatedDetailB.data.data?.participantCount === 2, `Participant count updated to 2 (got ${updatedDetailB.data.data?.participantCount})`);
    assert(updatedDetailB.data.data?.userRsvpStatus === 'going', 'User B RSVP status is now going');

    // STEP 7: Organizer sees RSVP in participant list
    console.log('\n[Step 7] Organizer sees RSVP in participant list');
    const participantsRes = await request(`/events/${createdEventId}/participants`, {
      method: 'GET',
      headers: authHeadersA,
    });

    assert(participantsRes.status === 200, 'Participants endpoint returns 200');
    const attendeeFound = participantsRes.data.data?.items?.some(p => p.userId === userB.user.id);
    assert(attendeeFound === true, 'User B is listed in event participants');

    // STEP 8: Organizer edits event
    console.log('\n[Step 8] Organizer edits event');
    const editPayload = {
      title: 'Indiranagar Neighborhood Solar Workshop (Updated)',
      venue: 'Indiranagar Club Main Auditorium',
    };

    const editRes = await request(`/events/${createdEventId}`, {
      method: 'PATCH',
      headers: authHeadersA,
      body: JSON.stringify(editPayload),
    });

    assert(editRes.status === 200, `Edit event returns 200 (status: ${editRes.status})`);
    assert(editRes.data.data?.title === editPayload.title, 'Updated title persisted');
    assert(editRes.data.data?.venue === editPayload.venue, 'Updated venue persisted');

    // STEP 9: Event update appears in discovery/detail
    console.log('\n[Step 9] Event update appears in discovery/detail');
    const detailAfterEdit = await request(`/events/${createdEventId}`, {
      method: 'GET',
      headers: authHeadersB,
    });

    assert(detailAfterEdit.data.data?.title === editPayload.title, 'Updated event title visible to attendee');
    assert(detailAfterEdit.data.data?.venue === editPayload.venue, 'Updated venue visible to attendee');

    // STEP 10: Non-organizer cannot edit
    console.log('\n[Step 10] Non-organizer cannot edit');
    const unauthorizedEditRes = await request(`/events/${createdEventId}`, {
      method: 'PATCH',
      headers: authHeadersB,
      body: JSON.stringify({ title: 'Hacked Title' }),
    });

    assert(unauthorizedEditRes.status === 403, `Non-organizer edit rejected with 403 Forbidden (got ${unauthorizedEditRes.status})`);

    // STEP 11: User cancels RSVP
    console.log('\n[Step 11] User cancels RSVP');
    const cancelRsvpRes = await request(`/events/${createdEventId}/rsvp`, {
      method: 'DELETE',
      headers: authHeadersB,
    });

    assert(cancelRsvpRes.status === 200, `Cancel RSVP returns 200 (status: ${cancelRsvpRes.status})`);

    const detailAfterCancelRsvp = await request(`/events/${createdEventId}`, {
      method: 'GET',
      headers: authHeadersB,
    });
    assert(detailAfterCancelRsvp.data.data?.participantCount === 1, 'Participant count decremented back to 1');
    assert(detailAfterCancelRsvp.data.data?.userRsvpStatus === null, 'User B RSVP status cleared to null');

    // STEP 12: Organizer cancels event
    console.log('\n[Step 12] Organizer cancels event');
    const cancelEventRes = await request(`/events/${createdEventId}/cancel`, {
      method: 'POST',
      headers: authHeadersA,
      body: JSON.stringify({ reason: 'Auditorium undergoing emergency maintenance' }),
    });

    assert(cancelEventRes.status === 200, `Cancel event returns 200 (status: ${cancelEventRes.status})`);
    assert(cancelEventRes.data.data?.status === 'cancelled', 'Event status transitioned to cancelled');
    assert(cancelEventRes.data.data?.cancellationReason === 'Auditorium undergoing emergency maintenance', 'Cancellation reason saved');

    // Non-organizer cannot cancel event
    const unauthorizedCancelRes = await request(`/events/${createdEventId}/cancel`, {
      method: 'POST',
      headers: authHeadersB,
      body: JSON.stringify({ reason: 'Malicious cancel' }),
    });
    assert(unauthorizedCancelRes.status === 403, 'Non-organizer cannot cancel event (returns 403)');

    // STEP 13: Cancelled event no longer appears in normal upcoming discovery
    console.log('\n[Step 13] Cancelled event excluded from upcoming discovery');
    const upcomingAfterCancel = await request(`/events?locality=Indiranagar&timeframe=upcoming`, {
      method: 'GET',
      headers: authHeadersB,
    });

    const isCancelledInUpcoming = upcomingAfterCancel.data.data?.items?.some(e => e.id === createdEventId);
    assert(isCancelledInUpcoming === false, 'Cancelled event is excluded from default upcoming discovery');

    // STEP 14: Event reporting works via Trust & Safety
    console.log('\n[Step 14] Event reporting works');
    const reportRes = await request('/safety/reports', {
      method: 'POST',
      headers: authHeadersB,
      body: JSON.stringify({
        targetType: 'event',
        targetId: createdEventId,
        reason: 'spam',
        details: 'Testing trust and safety event reporting',
      }),
    });

    assert(reportRes.status === 200, `Report event returns 200 OK (status: ${reportRes.status})`);
    const isSuccess = reportRes.data?.data?.success ?? reportRes.data?.success;
    assert(isSuccess === true, 'Report response confirms success');
    const reportId = reportRes.data?.data?.reportId || reportRes.data?.reportId;
    assert(reportId !== undefined, 'Report ID returned from safety service');

    // Verify report in database
    const dbReportRes = await dbClient.query(
      `SELECT * FROM safety_reports WHERE "targetId" = $1 AND "targetType" = 'event'`,
      [createdEventId]
    );
    assert(dbReportRes.rows.length >= 1, 'Report record exists in safety_reports table');
    assert(dbReportRes.rows[0].targetType === 'event', 'Report target type is event in DB');

    // STEP 15: Notification integration works
    console.log('\n[Step 15] Notification integration works');
    const notificationsResA = await request('/notifications', {
      method: 'GET',
      headers: authHeadersA,
    });

    assert(notificationsResA.status === 200, 'Notifications endpoint returns 200');
    // Check database notifications for event-related notifications (recipientId = organizer)
    const dbNotifRes = await dbClient.query(
      `SELECT * FROM notifications WHERE type IN ('EVENT_RSVP', 'EVENT_CANCELLED', 'EVENT_UPDATE') AND "recipientId" = $1`,
      [userA.user.id]
    );
    assert(dbNotifRes.rows.length >= 1, `Event notification record created for organizer in DB (${dbNotifRes.rows.length} found)`);

  } finally {
    await dbClient.end();
  }

  console.log('\n========================================================================');
  console.log(`EVENTS RUNTIME E2E SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('========================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runEventsVerification().catch((err) => {
  console.error('Fatal error during Events E2E runtime verification:', err);
  process.exit(1);
});
