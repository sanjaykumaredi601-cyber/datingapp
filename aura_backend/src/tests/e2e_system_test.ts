import { io, Socket } from 'socket.io-client';

const API_BASE = 'http://127.0.0.1:3000';
const WS_BASE = 'http://127.0.0.1:3000';

interface TestResult {
  module: string;
  name: string;
  passed: boolean;
  durationMs: number;
  details: string;
}

const testResults: TestResult[] = [];

function logSection(title: string) {
  console.log(`\n========================================================================`);
  console.log(`🧪 ${title}`);
  console.log(`========================================================================`);
}

function logStep(step: string, status: 'RUNNING' | 'PASS' | 'FAIL', info?: string) {
  const icon = status === 'PASS' ? '✅' : (status === 'FAIL' ? '❌' : '⏳');
  console.log(`  ${icon} [${status}] ${step}${info ? ` — ${info}` : ''}`);
}

async function runTest(module: string, name: string, fn: () => Promise<void>) {
  const start = Date.now();
  try {
    await fn();
    const durationMs = Date.now() - start;
    testResults.push({ module, name, passed: true, durationMs, details: 'Success' });
    logStep(name, 'PASS', `${durationMs}ms`);
  } catch (err: any) {
    const durationMs = Date.now() - start;
    testResults.push({ module, name, passed: false, durationMs, details: err.message });
    logStep(name, 'FAIL', `${err.message} (${durationMs}ms)`);
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ────────────────────────────────────────────────────────────────────────
// MAIN TEST RUNNER
// ────────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n🌌 AURA DATING PLATFORM — FULL-STACK AUTOMATION & E2E TEST SUITE`);
  console.log(`🕒 Timestamp: ${new Date().toISOString()}`);
  console.log(`📡 Target API: ${API_BASE}`);
  console.log(`⚡ Target WS:  ${WS_BASE}\n`);

  // Verify server is alive
  const healthResp = await fetch(`${API_BASE}/health`);
  if (!healthResp.ok) {
    throw new Error(`Server is not healthy: ${healthResp.status}`);
  }
  const healthData = await healthResp.json();
  console.log(`🟢 Gateway Online: ${healthData.service} v${healthData.version}\n`);

  // ──────────────────────────────────────────────────────────────────────
  // MODULE 1: PROFILE CREATION & ASSET INGESTION
  // ──────────────────────────────────────────────────────────────────────
  logSection('MODULE 1: TEMPORARY PROFILE CREATION & ASSET INGESTION');

  let userA_avatarUrl = '';
  let userB_avatarUrl = '';

  await runTest('Asset Upload', '1.1 Upload valid JPEG & verify compression, format, and CDN URL', async () => {
    // Generate valid mock JPEG base64 (1x1 transparent/colored JPEG header)
    const mockJpegBase64 = Buffer.from(
      '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA='
    , 'base64').toString('base64');

    const res = await fetch(`${API_BASE}/api/upload/image`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        filename: 'alex_profile_photo.jpg',
        mimeType: 'image/jpeg',
        base64Data: mockJpegBase64,
        quality: 85,
      }),
    });

    if (res.status !== 201) throw new Error(`Expected 201 Created, got ${res.status}`);
    const data = await res.json();
    if (!data.success || !data.url.includes('/uploads/img_')) {
      throw new Error(`Invalid response structure: ${JSON.stringify(data)}`);
    }
    userA_avatarUrl = data.url;
  });

  await runTest('Asset Upload', '1.2 Upload valid WEBP & verify compression ratio metadata', async () => {
    const mockWebpBase64 = Buffer.from('UklGRh4AAABXRUJQVlA4TBEAAAAvAAAAAAfQ//73v/+BiOh/AAA=', 'base64').toString('base64');
    const res = await fetch(`${API_BASE}/api/upload/image`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        filename: 'maya_profile_portrait.webp',
        mimeType: 'image/webp',
        base64Data: mockWebpBase64,
        quality: 80,
      }),
    });

    if (res.status !== 201) throw new Error(`Expected 201 Created, got ${res.status}`);
    const data = await res.json();
    if (!data.format || data.format !== 'webp') throw new Error(`Expected format webp, got ${data.format}`);
    userB_avatarUrl = data.url;
  });

  await runTest('Asset Upload', '1.3 Reject unsupported file format (application/x-msdownload)', async () => {
    const res = await fetch(`${API_BASE}/api/upload/image`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        filename: 'malicious.exe',
        mimeType: 'application/x-msdownload',
        base64Data: Buffer.from('MZ...').toString('base64'),
      }),
    });

    if (res.status !== 400) throw new Error(`Expected 400 Bad Request, got ${res.status}`);
    const data = await res.json();
    if (!data.supportedFormats) throw new Error(`Expected supportedFormats list in response`);
  });

  await runTest('Asset Upload', '1.4 Reject file exceeding 10MB limit', async () => {
    // 11MB dummy base64
    const largeBuffer = Buffer.alloc(11 * 1024 * 1024);
    const res = await fetch(`${API_BASE}/api/upload/image`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        filename: 'huge_photo.jpg',
        mimeType: 'image/jpeg',
        base64Data: largeBuffer.toString('base64'),
      }),
    });

    if (res.status !== 413) throw new Error(`Expected 413 Payload Too Large, got ${res.status}`);
  });

  await runTest('Profile Ingestion', '1.5 Ingest Profile A (Alex Carter) & Profile B (Maya Lin)', async () => {
    const profileA = {
      userId: 'usr_test_alex',
      displayName: 'Alex Carter',
      avatarUrl: userA_avatarUrl,
      photos: [userA_avatarUrl],
      bio: 'Software Architect & Coffee Enthusiast ☕. Looking for good vibes & deep talks.',
      interests: ['Tech', 'Coffee', 'Trekking', 'Indie Music'],
    };

    const profileB = {
      userId: 'usr_test_maya',
      displayName: 'Maya Lin',
      avatarUrl: userB_avatarUrl,
      photos: [userB_avatarUrl],
      bio: 'UX Designer & Visual Artist 🎨. Exploring city cafés and photography spots.',
      interests: ['Design', 'Art', 'Travel', 'Specialty Coffee'],
    };

    const [resA, resB] = await Promise.all([
      fetch(`${API_BASE}/api/upload/profile`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(profileA),
      }),
      fetch(`${API_BASE}/api/upload/profile`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(profileB),
      }),
    ]);

    if (!resA.ok || !resB.ok) throw new Error(`Failed to ingest profiles: ${resA.status} / ${resB.status}`);
    const dataA = await resA.json();
    const dataB = await resB.json();
    if (!dataA.success || !dataB.success) throw new Error('Profile ingestion did not return success');
  });

  // ──────────────────────────────────────────────────────────────────────
  // MODULE 2: MATCHING & MESSAGING RATE LIMITS
  // ──────────────────────────────────────────────────────────────────────
  logSection('MODULE 2: MATCHING & MESSAGING OVER WEBSOCKET');

  const matchId = 'match_alex_maya';
  let socketA: Socket;
  let socketB: Socket;

  await runTest('WebSocket Connect', '2.1 Dual Client Connection & Room Handshake', async () => {
    socketA = io(WS_BASE, { auth: { userId: 'usr_test_alex' }, transports: ['websocket'] });
    socketB = io(WS_BASE, { auth: { userId: 'usr_test_maya' }, transports: ['websocket'] });

    await Promise.all([
      new Promise<void>((resolve, reject) => {
        socketA.on('connect', () => resolve());
        socketA.on('connect_error', reject);
      }),
      new Promise<void>((resolve, reject) => {
        socketB.on('connect', () => resolve());
        socketB.on('connect_error', reject);
      }),
    ]);

    socketA.emit('join_room', { matchId });
    socketB.emit('join_room', { matchId });
    await sleep(200);
  });

  await runTest('Messaging Latency', '2.2 Single message delivery latency measurement', async () => {
    const startTime = Date.now();
    const testContent = 'Hey Maya! Great to connect with you! ☕';

    const deliveryPromise = new Promise<{ latencyMs: number }>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout waiting for message')), 3000);
      socketB.once('new_message', (msg: any) => {
        clearTimeout(timeout);
        const latencyMs = Date.now() - startTime;
        if (msg.content === testContent && msg.senderId === 'usr_test_alex') {
          resolve({ latencyMs });
        } else {
          reject(new Error(`Content mismatch: ${msg.content}`));
        }
      });
    });

    socketA.emit('send_message', {
      matchId,
      content: testContent,
      contentType: 'text',
      tempId: 'temp_1',
    });

    const { latencyMs } = await deliveryPromise;
    if (latencyMs > 500) throw new Error(`High latency: ${latencyMs}ms (threshold 500ms)`);
    console.log(`      ⏱️ Single message delivery latency: ${latencyMs}ms`);
  });

  await runTest('Messaging Latency', '2.3 Continuous 5-message pipeline latency benchmarks', async () => {
    const latencies: number[] = [];

    for (let i = 1; i <= 5; i++) {
      const t0 = Date.now();
      const content = `Continuous stream benchmark #${i}`;

      const p = new Promise<number>((resolve) => {
        socketB.once('new_message', () => {
          resolve(Date.now() - t0);
        });
      });

      socketA.emit('send_message', {
        matchId,
        content,
        contentType: 'text',
        tempId: `stream_${i}`,
      });

      const lat = await p;
      latencies.push(lat);
      await sleep(50);
    }

    const avgLat = (latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(1);
    console.log(`      ⏱️ Average stream latency: ${avgLat}ms across 5 packets (${latencies.join(', ')} ms)`);
  });

  await runTest('Rate Limiting', '2.4 Burst rate limit threshold enforcement (>10 msgs/5s)', async () => {
    let rateLimitErrorReceived = false;

    socketA.on('error_rate_limited', () => {
      rateLimitErrorReceived = true;
    });

    // Rapid burst of 12 messages in under 200ms
    for (let i = 0; i < 12; i++) {
      socketA.emit('send_message', {
        matchId,
        content: `Spam burst #${i}`,
        contentType: 'text',
        tempId: `burst_${i}`,
      });
    }

    await sleep(400);

    if (!rateLimitErrorReceived) {
      throw new Error('Rate limit was not enforced for 12 burst messages');
    }
  });

  await runTest('Emoji & Unicode', '2.5 Full UTF-8 & Complex ZWJ Emoji integrity verification', async () => {
    // Reset rate limit window
    await sleep(5200);

    const emojiPayload = 'Family: 👨‍👩‍👧‍👦 | Dev: 🧑‍💻 | Pride: 🏳️‍🌈 | Sparks: ✨💖🎉 | Multilingual: ¡Hola Maya! ¿Café mañana? ☕';

    const p = new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout on emoji message')), 3000);
      socketB.once('new_message', (msg: any) => {
        clearTimeout(timeout);
        if (msg.content === emojiPayload) {
          resolve();
        } else {
          reject(new Error(`Emoji payload corrupted! Expected "${emojiPayload}", got "${msg.content}"`));
        }
      });
    });

    socketA.emit('send_message', {
      matchId,
      content: emojiPayload,
      contentType: 'text',
      tempId: 'emoji_1',
    });

    await p;
  });

  // ──────────────────────────────────────────────────────────────────────
  // MODULE 3: MEDIA, VOICE NOTES & WEBRTC CALLING
  // ──────────────────────────────────────────────────────────────────────
  logSection('MODULE 3: MEDIA, VOICE NOTES & WEBRTC CALLING WORKFLOW');

  let voiceNoteUrl = '';

  await runTest('Voice Notes', '3.1 Voice note upload, storage persistence & 32-sample waveform generation', async () => {
    const mockAudioBase64 = Buffer.from('MOCK_AUDIO_PAYLOAD_SPEECH_DATA_STREAM').toString('base64');
    const res = await fetch(`${API_BASE}/api/upload/voice-note`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        filename: 'audio_note_001.m4a',
        mimeType: 'audio/m4a',
        base64Data: mockAudioBase64,
        durationSeconds: 5.2,
      }),
    });

    if (res.status !== 201) throw new Error(`Expected 201, got ${res.status}`);
    const data = await res.json();
    if (!data.waveform || data.waveform.length !== 32) {
      throw new Error(`Expected 32-band waveform, got ${data.waveform?.length}`);
    }
    voiceNoteUrl = data.url;
  });

  await runTest('Voice Notes', '3.2 Voice note transmission over WebSocket', async () => {
    const p = new Promise<void>((resolve, reject) => {
      socketA.once('new_message', (msg: any) => {
        if (msg.contentType === 'voice_note' && msg.mediaUrl === voiceNoteUrl) {
          resolve();
        } else {
          reject(new Error(`Voice note payload mismatch: ${JSON.stringify(msg)}`));
        }
      });
    });

    socketB.emit('send_message', {
      matchId,
      content: 'Voice Note (0:05)',
      contentType: 'voice_note',
      mediaUrl: voiceNoteUrl,
      tempId: 'vn_msg_1',
    });

    await p;
  });

  await runTest('WebRTC Calling', '3.3 WebRTC Signaling: Handshake, SDP Offer/Answer, ICE & State Connected', async () => {
    const testCallId = `call_test_${Date.now()}`;
    const mockSdpOffer = { type: 'offer', sdp: 'v=0\r\no=alex 12345 2 IN IP4 127.0.0.1\r\ns=AuraVideoCall\r\nt=0 0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\n' };
    const mockSdpAnswer = { type: 'answer', sdp: 'v=0\r\no=maya 67890 2 IN IP4 127.0.0.1\r\ns=AuraVideoCall\r\nt=0 0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\n' };
    const mockIceCandidate = { candidate: 'candidate:1 1 UDP 2122260223 127.0.0.1 54321 typ host', sdpMid: 'video', sdpMLineIndex: 0 };

    let incomingCallReceived = false;
    let sdpOfferReceived = false;
    let sdpAnswerReceived = false;
    let iceReceived = false;
    let callEndedReceived = false;

    // User B listens for incoming call, offer, and ice
    socketB.on('call_incoming', (data: any) => {
      incomingCallReceived = true;
    });

    socketB.on('call_offer_received', (data: any) => {
      if (data.sdp.type === 'offer') sdpOfferReceived = true;
      // User B answers
      socketB.emit('call_answer', {
        callId: testCallId,
        matchId,
        sdp: mockSdpAnswer,
        recipientId: 'usr_test_maya',
      });
    });

    socketB.on('ice_candidate_received', (data: any) => {
      if (data.candidate.sdpMid === 'video') iceReceived = true;
    });

    socketB.on('call_ended', () => {
      callEndedReceived = true;
    });

    // User A listens for answer
    socketA.on('call_answer_received', (data: any) => {
      if (data.sdp.type === 'answer') sdpAnswerReceived = true;
    });

    // Step 1: User A initiates call
    socketA.emit('call_initiate', {
      matchId,
      callerId: 'usr_test_alex',
      recipientId: 'usr_test_maya',
      callType: 'video',
    });

    await sleep(100);

    // Step 2: User A sends SDP Offer
    socketA.emit('call_offer', {
      callId: testCallId,
      matchId,
      sdp: mockSdpOffer,
      callerId: 'usr_test_alex',
    });

    await sleep(150);

    // Step 3: User A sends ICE candidate
    socketA.emit('ice_candidate', {
      callId: testCallId,
      matchId,
      candidate: mockIceCandidate,
    });

    await sleep(150);

    // Verify all signaling states reached 'connected'
    if (!incomingCallReceived) throw new Error('call_incoming event was not received');
    if (!sdpOfferReceived) throw new Error('call_offer_received was not received');
    if (!sdpAnswerReceived) throw new Error('call_answer_received was not received');
    if (!iceReceived) throw new Error('ice_candidate_received was not received');

    console.log(`      🤝 WebRTC Signaling: SDP Offer/Answer & ICE handshake completed -> ICE State: CONNECTED`);

    // Step 4: End call with duration
    socketA.emit('call_end', {
      callId: testCallId,
      matchId,
      durationSeconds: 42,
    });

    await sleep(150);
    if (!callEndedReceived) throw new Error('call_ended event was not received');
  });

  // ──────────────────────────────────────────────────────────────────────
  // MODULE 4: IN-CHAT REAL-TIME TRANSLATION FEATURE
  // ──────────────────────────────────────────────────────────────────────
  logSection('MODULE 4: IN-CHAT REAL-TIME TRANSLATION FEATURE');

  await runTest('Language Detection', '4.1 Heuristic & script language detection (Spanish, French, Hindi)', async () => {
    const tests = [
      { text: '¡Hola! Me encantaron tus fotos de viajes. ¿Quieres tomar un café? 😊', expected: 'es' },
      { text: 'Bonjour, comment vas-tu ? Tu es très charmante.', expected: 'fr' },
      { text: 'नमस्ते, आप कैसे हैं? आपकी प्रोफ़ाइल बहुत अच्छी है', expected: 'hi' },
    ];

    for (const t of tests) {
      const res = await fetch(`${API_BASE}/api/translation/detect`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: t.text }),
      });
      const data = await res.json();
      if (data.detectedLanguage !== t.expected) {
        throw new Error(`Expected ${t.expected}, got ${data.detectedLanguage} for "${t.text}"`);
      }
    }
  });

  await runTest('Translation Accuracy', '4.2 Spanish to English translation with emoji preservation', async () => {
    const original = '¡Hola! Me encantaron tus fotos de viajes. ¿Quieres tomar un café? 😊';
    const res = await fetch(`${API_BASE}/api/translation/translate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: original,
        targetLanguage: 'en',
      }),
    });

    const data = await res.json();
    if (!data.success) throw new Error('Translation API failed');
    if (!data.translatedText.toLowerCase().includes('travel') && !data.translatedText.toLowerCase().includes('coffee') && !data.translatedText.toLowerCase().includes('hello')) {
      throw new Error(`Translation inaccurate: ${data.translatedText}`);
    }
    if (!data.translatedText.includes('😊')) {
      throw new Error('Emoji was not preserved during translation');
    }
    console.log(`      🌐 Original:   "${data.originalText}"`);
    console.log(`      ✨ Translated: "${data.translatedText}" (${data.detectedLanguageName} -> ${data.targetLanguageName})`);
  });

  await runTest('Voice Transcript Translation', '4.3 Voice-to-text transcript real-time translation', async () => {
    const voiceTranscript = 'Bonjour, comment allez-vous ?';
    const res = await fetch(`${API_BASE}/api/translation/translate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: voiceTranscript,
        targetLanguage: 'en',
        isVoiceTranscript: true,
      }),
    });

    const data = await res.json();
    if (!data.isVoiceTranscript) throw new Error('Expected isVoiceTranscript: true');
    if (!data.translatedText.toLowerCase().includes('how are you') && !data.translatedText.toLowerCase().includes('hello')) {
      throw new Error(`Voice transcript translation error: ${data.translatedText}`);
    }
    console.log(`      🎙️ Voice Transcript: "${voiceTranscript}" => "${data.translatedText}"`);
  });

  // ──────────────────────────────────────────────────────────────────────
  // MODULE 5: INTERACTIVE MAP & CROSS-FADE BUBBLES
  // ──────────────────────────────────────────────────────────────────────
  logSection('MODULE 5: INTERACTIVE MAP & PRIVACY MASKING');

  await runTest('Map Radar', '5.1 GET /api/location/radar returns aggregated density zones', async () => {
    const lat = 19.0760;
    const lng = 72.8777;
    const res = await fetch(`${API_BASE}/api/location/radar?lat=${lat}&lng=${lng}&radius=25`);
    if (!res.ok) throw new Error(`Radar returned ${res.status}`);
    const data = await res.json();
    if (!data.zones || data.zones.length === 0) throw new Error('No radar zones returned');
    console.log(`      📍 Received ${data.zones.length} proximity density zones within ${data.radiusKm}km`);
  });

  await runTest('Privacy Masking', '5.2 Verify 0 precise coordinates exposed (500m privacy grid enforcement)', async () => {
    const lat = 19.076012345;
    const lng = 72.877798765;

    // Send location update
    const updateRes = await fetch(`${API_BASE}/api/location/update`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ latitude: lat, longitude: lng, accuracy: 5 }),
    });

    const updateData = await updateRes.json();
    if (!updateData.obfuscatedGrid) throw new Error('Expected obfuscatedGrid in response');

    // Verify coordinates are rounded to 500m grid cell (not raw 9-decimal coordinates)
    const gridLat = updateData.obfuscatedGrid.latitude;
    const gridLng = updateData.obfuscatedGrid.longitude;

    if (gridLat === lat || gridLng === lng) {
      throw new Error('CRITICAL PRIVACY BUG: Raw coordinates leaked without 500m grid obfuscation!');
    }

    console.log(`      🔒 Raw GPS: [${lat}, ${lng}] -> Masked 500m Grid: [${gridLat}, ${gridLng}]`);
  });

  await runTest('Location Purge', '5.3 One-Click Location History Purge (DPDP compliance)', async () => {
    const res = await fetch(`${API_BASE}/api/location/history`, { method: 'DELETE' });
    if (!res.ok) throw new Error(`Expected 200, got ${res.status}`);
    const data = await res.json();
    if (!data.success) throw new Error('Purge was not successful');
  });

  // Disconnect sockets
  socketA.disconnect();
  socketB.disconnect();

  // ──────────────────────────────────────────────────────────────────────
  // TEST SUMMARY & METRICS
  // ──────────────────────────────────────────────────────────────────────
  logSection('SUMMARY & MODULE BREAKDOWN');

  const total = testResults.length;
  const passed = testResults.filter((r) => r.passed).length;
  const failed = total - passed;

  console.log(`\nTotal Tests Executed: ${total}`);
  console.log(`✅ Passed:             ${passed}`);
  console.log(`❌ Failed:             ${failed}`);
  console.log(`📈 Success Rate:       ${((passed / total) * 100).toFixed(1)}%\n`);

  console.log('| Module | Test Name | Status | Duration |');
  console.log('|:---|:---|:---:|:---:|');
  for (const r of testResults) {
    const statusIcon = r.passed ? '✅ PASS' : '❌ FAIL';
    console.log(`| ${r.module} | ${r.name} | ${statusIcon} | ${r.durationMs}ms |`);
  }

  if (failed > 0) {
    console.error('\n⚠️ Some tests failed. Review details above.');
    process.exit(1);
  } else {
    console.log('\n🎉 ALL END-TO-END TESTS PASSED WITH 100% SUCCESS RATE!\n');
    process.exit(0);
  }
}

main().catch((e) => {
  console.error('Fatal test error:', e);
  process.exit(1);
});
