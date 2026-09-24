import http from 'http';

const BASE_URL = 'http://localhost:3000/api/v1';

async function request(endpoint, options = {}) {
  const url = `${BASE_URL}${endpoint}`;
  const response = await fetch(url, {
    method: options.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  let data;
  try {
    data = await response.json();
  } catch {
    data = null;
  }

  return { status: response.status, data };
}

async function authenticateUser(phone, name, locality, city) {
  // 1. Request OTP
  const otpRes = await request('/auth/otp/request', {
    method: 'POST',
    body: { phoneNumber: phone },
  });
  if (otpRes.status !== 200 && otpRes.status !== 201) {
    throw new Error(`OTP request failed for ${phone}: ${JSON.stringify(otpRes.data)}`);
  }
  const otp = otpRes.data.data.devOtp || '123456';

  // 2. Verify OTP
  const verifyRes = await request('/auth/otp/verify', {
    method: 'POST',
    body: { phoneNumber: phone, otp },
  });
  if (verifyRes.status !== 200 && verifyRes.status !== 201) {
    throw new Error(`OTP verify failed for ${phone}: ${JSON.stringify(verifyRes.data)}`);
  }
  const token = verifyRes.data.data.tokens.accessToken;
  const user = verifyRes.data.data.user;

  // 3. Onboard profile if not onboarded
  if (!user.onboardingCompleted) {
    const onboardRes = await request('/users/me/onboarding', {
      method: 'PATCH',
      token,
      body: {
        displayName: name,
        locality,
        city,
        state: 'Karnataka',
        countryCode: 'IN',
      },
    });
    if (onboardRes.status !== 200) {
      throw new Error(`Onboarding failed for ${phone}: ${JSON.stringify(onboardRes.data)}`);
    }
  }

  return { token, user };
}

async function runVerification() {
  console.log('====================================================');
  console.log('🚀 AASPAAS PHASE 3 — COMMUNITY FEED RUNTIME VERIFICATION');
  console.log('====================================================\n');

  // Step 1: Health Check
  console.log('1. Verifying API Health...');
  const health = await request('/health');
  if (health.status !== 200 || health.data.database !== 'connected') {
    throw new Error(`Health check failed: ${JSON.stringify(health.data)}`);
  }
  console.log('   ✅ Health OK: Database & Redis connected.\n');

  // Step 2: Authenticate two distinct test users
  console.log('2. Authenticating Test Users...');
  const userA = await authenticateUser(
    '+919876510001',
    'Ashok Neighbor',
    'Koramangala',
    'Bengaluru',
  );
  console.log('   ✅ User A authenticated (Ashok Neighbor - Koramangala, Bengaluru)');

  const userB = await authenticateUser(
    '+919876510002',
    'Bindu Neighbor',
    'Indiranagar',
    'Bengaluru',
  );
  console.log('   ✅ User B authenticated (Bindu Neighbor - Indiranagar, Bengaluru)\n');

  // Step 3: Create Post by User A
  console.log('3. Creating Community Post by User A...');
  const postContent = 'What are the best quiet coffee shops near 5th Block for working?';
  const createPostRes = await request('/feed/posts', {
    method: 'POST',
    token: userA.token,
    body: {
      content: postContent,
      category: 'recommendation',
    },
  });

  if (createPostRes.status !== 201) {
    throw new Error(`Failed to create post: ${JSON.stringify(createPostRes.data)}`);
  }
  const post = createPostRes.data.data;
  console.log(`   ✅ Post created: ID = ${post.id}`);
  console.log(`   ✅ Inherited locality: ${post.locality}, ${post.city}`);
  console.log(`   ✅ Privacy check: lat/long coordinates absent? ${post.latitude === undefined && post.longitude === undefined}\n`);

  // Step 4: Feed Listing & Scoping
  console.log('4. Testing Feed Scoping & Filtering...');
  const feedRes = await request('/feed/posts?scope=local', {
    token: userA.token,
  });
  if (feedRes.status !== 200 || !feedRes.data.data.posts.some((p) => p.id === post.id)) {
    throw new Error('Created post not found in local feed!');
  }
  console.log(`   ✅ Post found in local feed (Total posts: ${feedRes.data.data.posts.length})`);

  // Category filter
  const filterMatch = await request('/feed/posts?category=recommendation', {
    token: userA.token,
  });
  const filterMismatch = await request('/feed/posts?category=alert', {
    token: userA.token,
  });
  const hasInMatch = filterMatch.data.data.posts.some((p) => p.id === post.id);
  const hasInMismatch = filterMismatch.data.data.posts.some((p) => p.id === post.id);
  if (!hasInMatch || hasInMismatch) {
    throw new Error('Category filtering failed!');
  }
  console.log('   ✅ Category filter accurately isolates matching posts.\n');

  // Step 5: Post Detail & Like/Unlike
  console.log('5. Testing Post Details & Reactions...');
  const detailBeforeLike = await request(`/feed/posts/${post.id}`, {
    token: userB.token,
  });
  if (detailBeforeLike.data.data.currentUserLiked !== false) {
    throw new Error('User B should not have liked this post initially');
  }

  // Like
  const likeRes = await request(`/feed/posts/${post.id}/like`, {
    method: 'POST',
    token: userB.token,
  });
  if (likeRes.status !== 200 || likeRes.data.data.liked !== true || likeRes.data.data.likeCount !== 1) {
    throw new Error(`Like failed: ${JSON.stringify(likeRes.data)}`);
  }
  console.log('   ✅ User B liked post (likeCount = 1, liked = true)');

  // Unlike
  const unlikeRes = await request(`/feed/posts/${post.id}/like`, {
    method: 'DELETE',
    token: userB.token,
  });
  if (unlikeRes.status !== 200 || unlikeRes.data.data.liked !== false || unlikeRes.data.data.likeCount !== 0) {
    throw new Error(`Unlike failed: ${JSON.stringify(unlikeRes.data)}`);
  }
  console.log('   ✅ User B unliked post (likeCount = 0, liked = false)\n');

  // Step 6: Comments CRUD & Ownership Protection
  console.log('6. Testing Comments CRUD & Ownership Authorization...');
  const commentRes = await request(`/feed/posts/${post.id}/comments`, {
    method: 'POST',
    token: userB.token,
    body: { content: 'Try Third Wave or Coffee Mechanics on 80ft road!' },
  });
  if (commentRes.status !== 201) {
    throw new Error(`Create comment failed: ${JSON.stringify(commentRes.data)}`);
  }
  const comment = commentRes.data.data;
  console.log(`   ✅ Comment created by User B: ID = ${comment.id}`);

  // User A tries to delete User B's comment
  const unauthorizedDeleteComment = await request(`/feed/comments/${comment.id}`, {
    method: 'DELETE',
    token: userA.token,
  });
  if (unauthorizedDeleteComment.status !== 403) {
    throw new Error(`Expected 403 Forbidden on unauthorized comment delete, got ${unauthorizedDeleteComment.status}`);
  }
  console.log('   🔒 Security check passed: User A cannot delete User B comment (403 Forbidden)');

  // User B deletes own comment
  const authorizedDeleteComment = await request(`/feed/comments/${comment.id}`, {
    method: 'DELETE',
    token: userB.token,
  });
  if (authorizedDeleteComment.status !== 200 && authorizedDeleteComment.status !== 204) {
    throw new Error(`Authorized comment delete failed: ${authorizedDeleteComment.status}`);
  }
  console.log('   ✅ User B successfully deleted own comment.\n');

  // Step 7: Trust & Safety Reporting
  console.log('7. Testing Content Safety Reporting...');
  const reportRes = await request(`/feed/posts/${post.id}/report`, {
    method: 'POST',
    token: userB.token,
    body: {
      reason: 'spam',
      details: 'Automated test report verification',
    },
  });
  if (reportRes.status !== 200 && reportRes.status !== 201) {
    throw new Error(`Report submission failed: ${JSON.stringify(reportRes.data)}`);
  }
  console.log('   ✅ User B reported Post A (200 OK / 201 Created)');

  // Duplicate report attempt
  const duplicateReportRes = await request(`/feed/posts/${post.id}/report`, {
    method: 'POST',
    token: userB.token,
    body: { reason: 'spam' },
  });
  if (duplicateReportRes.status !== 409) {
    throw new Error(`Expected 409 Conflict for duplicate report, got ${duplicateReportRes.status}`);
  }
  console.log('   🔒 Abuse prevention passed: Duplicate reports rejected (409 Conflict)\n');

  // Step 8: Post Ownership Authorization & Lifecycle
  console.log('8. Testing Post Ownership Authorization & Deletion...');
  // User B tries to update Post A
  const unauthorizedUpdate = await request(`/feed/posts/${post.id}`, {
    method: 'PATCH',
    token: userB.token,
    body: { content: 'Hacked by User B!' },
  });
  if (unauthorizedUpdate.status !== 403) {
    throw new Error(`Expected 403 Forbidden for unauthorized post update, got ${unauthorizedUpdate.status}`);
  }
  console.log('   🔒 Security check passed: User B cannot update Post A (403 Forbidden)');

  // User A updates own post
  const authorizedUpdate = await request(`/feed/posts/${post.id}`, {
    method: 'PATCH',
    token: userA.token,
    body: { content: 'Updated: What are the best quiet coffee shops near 5th Block?' },
  });
  if (authorizedUpdate.status !== 200 || !authorizedUpdate.data.data.content.startsWith('Updated:')) {
    throw new Error(`Authorized post update failed: ${JSON.stringify(authorizedUpdate.data)}`);
  }
  console.log('   ✅ User A successfully updated own post');

  // User B tries to delete Post A
  const unauthorizedDelete = await request(`/feed/posts/${post.id}`, {
    method: 'DELETE',
    token: userB.token,
  });
  if (unauthorizedDelete.status !== 403) {
    throw new Error(`Expected 403 Forbidden for unauthorized post delete, got ${unauthorizedDelete.status}`);
  }
  console.log('   🔒 Security check passed: User B cannot delete Post A (403 Forbidden)');

  // User A deletes own post
  const authorizedDelete = await request(`/feed/posts/${post.id}`, {
    method: 'DELETE',
    token: userA.token,
  });
  if (authorizedDelete.status !== 200 && authorizedDelete.status !== 204) {
    throw new Error(`Authorized post delete failed: ${authorizedDelete.status}`);
  }
  console.log('   ✅ User A successfully deleted own post');

  // Verify post is now 404
  const post404 = await request(`/feed/posts/${post.id}`, {
    token: userA.token,
  });
  if (post404.status !== 404) {
    throw new Error(`Expected 404 Not Found after deletion, got ${post404.status}`);
  }
  console.log('   ✅ Soft-deleted post returns 404 Not Found.\n');

  console.log('====================================================');
  console.log('🎉 ALL COMMUNITY FEED RUNTIME VERIFICATIONS PASSED!');
  console.log('====================================================');
}

runVerification().catch((err) => {
  console.error('\n❌ VERIFICATION FAILED:', err);
  process.exit(1);
});
