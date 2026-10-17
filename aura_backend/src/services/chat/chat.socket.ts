import { Server as SocketIOServer, Socket } from 'socket.io';
import { pool, isDatabaseLive } from '../../config/db.js';

interface ChatStoreMessage {
  messageId: string;
  matchId: string;
  senderId: string;
  content: string;
  contentType: string;
  mediaUrl?: string;
  sentAt: string;
  tempId?: string;
  isDeletedForEveryone?: boolean;
  deletedForUsers?: Set<string>;
}

// In-memory message store for development/instant synchronization
const messageStore = new Map<string, ChatStoreMessage>();

// Rate limiter state: socketId -> { count, resetTime }
const socketRateLimits = new Map<string, { count: number; resetTime: number }>();

function checkRateLimit(socketId: string, limit = 10, windowMs = 5000): boolean {
  const now = Date.now();
  const state = socketRateLimits.get(socketId);

  if (!state || now > state.resetTime) {
    socketRateLimits.set(socketId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  if (state.count >= limit) {
    return false;
  }

  state.count++;
  return true;
}

export function setupChatSocket(io: SocketIOServer) {
  const activeRooms = new Map<string, Set<string>>();

  io.on('connection', (socket: Socket) => {
    const userId = (socket.handshake.auth?.userId as string) || (socket.handshake.query?.userId as string) || socket.id;
    console.log(`⚡ [Socket.io] Client connected: ${socket.id} (User: ${userId})`);

    // 1. Join Match Chat Room
    socket.on('join_room', (data: { matchId: string }) => {
      const { matchId } = data;
      if (!matchId) return;

      socket.join(matchId);
      if (!activeRooms.has(matchId)) {
        activeRooms.set(matchId, new Set());
      }
      activeRooms.get(matchId)!.add(socket.id);
      console.log(`💬 User ${userId} joined match room: ${matchId}`);
    });

    // 2. Leave Room
    socket.on('leave_room', (data: { matchId: string }) => {
      const { matchId } = data;
      if (!matchId) return;

      socket.leave(matchId);
      activeRooms.get(matchId)?.delete(socket.id);
      console.log(`👋 User ${userId} left match room: ${matchId}`);
    });

    // 3. Send Message (with Anti-Spam Rate Limiting)
    socket.on('send_message', async (payload: {
      matchId: string;
      content: string;
      contentType?: string;
      tempId?: string;
      mediaUrl?: string;
    }) => {
      // Apply rate limiting
      if (!checkRateLimit(socket.id, 10, 5000)) {
        socket.emit('error_rate_limited', {
          message: 'Rate limit exceeded: Please wait before sending more messages.',
        });
        return;
      }

      const { matchId, content, contentType = 'text', tempId, mediaUrl } = payload;
      if (!matchId || !content) return;

      const messageId = `msg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const sentAt = new Date().toISOString();

      const messageData: ChatStoreMessage = {
        messageId,
        matchId,
        senderId: userId,
        content,
        contentType,
        mediaUrl,
        sentAt,
        tempId,
        isDeletedForEveryone: false,
        deletedForUsers: new Set(),
      };

      // Persist to in-memory store
      messageStore.set(messageId, messageData);

      // Persist to PostGIS/PostgreSQL if database is active
      if (isDatabaseLive()) {
        try {
          await pool.query(
            `INSERT INTO messages (message_id, match_id, sender_id, content_type, content_encrypted, media_url, sent_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [messageId, matchId, userId, contentType, content, mediaUrl || null, sentAt]
          );
        } catch (dbErr: any) {
          console.warn('DB message insert error (falling back to memory):', dbErr.message);
        }
      }

      // Broadcast to everyone else in the match room
      socket.to(matchId).emit('new_message', {
        messageId,
        matchId,
        senderId: userId,
        content,
        contentType,
        mediaUrl,
        sentAt,
        tempId,
      });

      // Confirm delivery back to sender
      socket.emit('message_delivered', {
        messageId,
        tempId,
        deliveredAt: sentAt,
      });

      console.log(`✉️ [${matchId}] Message delivered from ${userId}: "${content.substring(0, 30)}..."`);
    });

    // 4. Instagram-Style Chat Deletion
    // Handles "Unsend for Everyone" and "Delete for Me"
    socket.on('delete_message', async (data: {
      matchId: string;
      messageId: string;
      deleteType: 'for_everyone' | 'for_me';
    }) => {
      const { matchId, messageId, deleteType } = data;
      if (!matchId || !messageId) return;

      const storedMsg = messageStore.get(messageId);

      if (deleteType === 'for_everyone') {
        // Mark as deleted for everyone in memory
        if (storedMsg) {
          storedMsg.isDeletedForEveryone = true;
          storedMsg.content = '[This message was unsent]';
        }

        // Update database if live
        if (isDatabaseLive()) {
          try {
            await pool.query(
              `UPDATE messages 
               SET content_encrypted = '[This message was unsent]',
                   is_deleted_by_sender = TRUE,
                   is_deleted_by_receiver = TRUE 
               WHERE message_id = $1`,
              [messageId]
            );
          } catch (dbErr: any) {
            console.warn('DB delete error:', dbErr.message);
          }
        }

        // Broadcast to both peers in room (zero screen reload on both sides)
        io.to(matchId).emit('message_deleted', {
          matchId,
          messageId,
          deleteType: 'for_everyone',
          deletedBy: userId,
          timestamp: new Date().toISOString(),
        });

        console.log(`🗑️ [${matchId}] Message ${messageId} unsent for everyone by ${userId}`);
      } else if (deleteType === 'for_me') {
        // Mark as deleted only for the requester
        if (storedMsg) {
          storedMsg.deletedForUsers?.add(userId);
        }

        // Update database if live
        if (isDatabaseLive()) {
          try {
            await pool.query(
              `UPDATE messages 
               SET is_deleted_by_sender = CASE WHEN sender_id = $1 THEN TRUE ELSE is_deleted_by_sender END,
                   is_deleted_by_receiver = CASE WHEN sender_id != $1 THEN TRUE ELSE is_deleted_by_receiver END
               WHERE message_id = $2`,
              [userId, messageId]
            );
          } catch (dbErr: any) {
            console.warn('DB delete for me error:', dbErr.message);
          }
        }

        // Emit back only to the requesting socket
        socket.emit('message_deleted', {
          matchId,
          messageId,
          deleteType: 'for_me',
          userId,
          timestamp: new Date().toISOString(),
        });

        console.log(`👤 [${matchId}] Message ${messageId} deleted for me by ${userId}`);
      }
    });

    // 5. Typing Indicators
    socket.on('typing_start', (data: { matchId: string }) => {
      socket.to(data.matchId).emit('typing_indicator', {
        matchId: data.matchId,
        userId,
        isTyping: true,
      });
    });

    socket.on('typing_stop', (data: { matchId: string }) => {
      socket.to(data.matchId).emit('typing_indicator', {
        matchId: data.matchId,
        userId,
        isTyping: false,
      });
    });

    // 6. Read Receipts
    socket.on('message_read', (data: { matchId: string; messageId: string }) => {
      const readAt = new Date().toISOString();
      socket.to(data.matchId).emit('message_read_ack', {
        matchId: data.matchId,
        messageId: data.messageId,
        readAt,
      });
    });

    // 7. Message Request Handshake (Accept / Decline)
    socket.on('handshake_action', (data: { matchId: string; action: 'accept' | 'decline' }) => {
      const { matchId, action } = data;
      if (!matchId || !action) return;

      io.to(matchId).emit('handshake_updated', {
        matchId,
        action,
        updatedBy: userId,
        timestamp: new Date().toISOString(),
      });
      console.log(`🤝 [${matchId}] Handshake action: ${action} by user: ${userId}`);
    });

    // 8. Instant Purge (Two-Way Wipe)
    socket.on('instant_purge', async (data: { matchId: string }) => {
      const { matchId } = data;
      if (!matchId) return;

      // Purge all messages from in-memory store for this match
      for (const [msgId, msg] of messageStore.entries()) {
        if (msg.matchId === matchId) {
          messageStore.delete(msgId);
        }
      }

      // Purge from PostGIS / PostgreSQL database if active
      if (isDatabaseLive()) {
        try {
          await pool.query('DELETE FROM messages WHERE match_id = $1', [matchId]);
          console.log(`🧹 [DB] Purged messages for match: ${matchId}`);
        } catch (dbErr: any) {
          console.warn('DB purge error:', dbErr.message);
        }
      }

      // Broadcast two-way wipe to all participants in room
      io.to(matchId).emit('chat_purged', {
        matchId,
        purgedBy: userId,
        timestamp: new Date().toISOString(),
      });
      console.log(`🔥 [${matchId}] Instant Purge executed by ${userId}`);
    });

    // 9. In-Chat Auto-Purge TTL Config
    socket.on('set_auto_purge', (data: { matchId: string; ttl: 'off' | '24h' | '7d' }) => {
      const { matchId, ttl } = data;
      if (!matchId || !ttl) return;

      io.to(matchId).emit('auto_purge_updated', {
        matchId,
        ttl,
        setBy: userId,
        timestamp: new Date().toISOString(),
      });
      console.log(`⏱️ [${matchId}] Auto-Purge TTL set to ${ttl} by ${userId}`);
    });

    // 10. WebRTC Audio & Video Calling Signaling
    socket.on('call_initiate', (data: { matchId: string; callerId: string; recipientId: string; callType: 'audio' | 'video' }) => {
      const { matchId, callerId, recipientId, callType } = data;
      if (!matchId) return;

      const callId = `call_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      console.log(`📞 [WebRTC] Call initiated: ${callId} (${callType}) from ${callerId || userId} to ${recipientId} in match ${matchId}`);

      socket.to(matchId).emit('call_incoming', {
        callId,
        matchId,
        callerId: callerId || userId,
        recipientId,
        callType,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('call_offer', (data: { callId: string; matchId: string; sdp: any; callerId?: string }) => {
      const { callId, matchId, sdp } = data;
      if (!matchId || !sdp) return;

      console.log(`📡 [WebRTC] SDP Offer received for call ${callId} in room ${matchId}`);
      socket.to(matchId).emit('call_offer_received', {
        callId,
        matchId,
        sdp,
        callerId: data.callerId || userId,
      });
    });

    socket.on('call_answer', (data: { callId: string; matchId: string; sdp: any; recipientId?: string }) => {
      const { callId, matchId, sdp } = data;
      if (!matchId || !sdp) return;

      console.log(`📡 [WebRTC] SDP Answer received for call ${callId} in room ${matchId}`);
      socket.to(matchId).emit('call_answer_received', {
        callId,
        matchId,
        sdp,
        recipientId: data.recipientId || userId,
      });
    });

    socket.on('ice_candidate', (data: { callId: string; matchId: string; candidate: any }) => {
      const { callId, matchId, candidate } = data;
      if (!matchId || !candidate) return;

      socket.to(matchId).emit('ice_candidate_received', {
        callId,
        matchId,
        candidate,
        senderId: userId,
      });
    });

    socket.on('call_reject', (data: { callId: string; matchId: string; reason?: string }) => {
      const { callId, matchId, reason } = data;
      if (!matchId) return;

      console.log(`🚫 [WebRTC] Call ${callId} rejected in room ${matchId}. Reason: ${reason || 'declined'}`);
      socket.to(matchId).emit('call_rejected', {
        callId,
        matchId,
        rejectedBy: userId,
        reason: reason || 'declined',
      });
    });

    socket.on('call_end', (data: { callId: string; matchId: string; durationSeconds?: number }) => {
      const { callId, matchId, durationSeconds = 0 } = data;
      if (!matchId) return;

      console.log(`📴 [WebRTC] Call ${callId} ended in room ${matchId}. Duration: ${durationSeconds}s`);

      // Relays call ended to peer
      socket.to(matchId).emit('call_ended', {
        callId,
        matchId,
        endedBy: userId,
        durationSeconds,
      });

      // Automatically persist a call_pill status message in chat history
      const messageId = `msg_call_${Date.now()}`;
      const sentAt = new Date().toISOString();
      const pillContent = durationSeconds < 60
        ? `Call Ended · ${durationSeconds}s`
        : `Call Ended · ${Math.floor(durationSeconds / 60)}m ${durationSeconds % 60}s`;

      const messageData: ChatStoreMessage = {
        messageId,
        matchId,
        senderId: userId,
        content: pillContent,
        contentType: 'call_pill',
        sentAt,
        isDeletedForEveryone: false,
        deletedForUsers: new Set(),
      };

      messageStore.set(messageId, messageData);

      io.to(matchId).emit('new_message', {
        messageId,
        matchId,
        senderId: userId,
        content: pillContent,
        contentType: 'call_pill',
        sentAt,
      });
    });

    socket.on('disconnect', () => {
      socketRateLimits.delete(socket.id);
      console.log(`❌ [Socket.io] Client disconnected: ${socket.id}`);
    });
  });
}
