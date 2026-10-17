import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/firestore_service.dart';
import 'chat_screen.dart';

class MessageRequestItem {
  final String requestId;
  final String matchId;
  final String senderName;
  final String senderAvatarUrl;
  final String messageSnippet;
  final String timeAgo;
  final String crossedLocation;
  final bool isVerified;

  const MessageRequestItem({
    required this.requestId,
    required this.matchId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.messageSnippet,
    required this.timeAgo,
    required this.crossedLocation,
    this.isVerified = true,
  });
}

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  final List<MessageRequestItem> _requests = [];

  void _acceptRequest(MessageRequestItem req) {
    setState(() {
      _requests.removeWhere((r) => r.requestId == req.requestId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accepted message request from ${req.senderName} 🎉'),
        backgroundColor: AppColors.surfaceL2,
        action: SnackBarAction(
          label: 'Chat Now',
          textColor: AppColors.sunsetCoral,
          onPressed: () => _openChat(req, isRequest: false),
        ),
      ),
    );
  }

  void _declineRequest(MessageRequestItem req) {
    setState(() {
      _requests.removeWhere((r) => r.requestId == req.requestId);
    });
    FirestoreService().instantPurge(req.matchId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Declined and purged request from ${req.senderName}'),
        backgroundColor: AppColors.surfaceL2,
      ),
    );
  }

  void _openChat(MessageRequestItem req, {bool isRequest = true}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          matchId: req.matchId,
          matchName: req.senderName,
          matchAvatarUrl: req.senderAvatarUrl,
          currentUserId: 'user_me_001',
          handshakeStatus: isRequest ? HandshakeStatus.pendingReceived : HandshakeStatus.accepted,
          onHandshakeAccepted: () {
            setState(() {
              _requests.removeWhere((r) => r.requestId == req.requestId);
            });
          },
          onHandshakeDeclined: () {
            setState(() {
              _requests.removeWhere((r) => r.requestId == req.requestId);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Row(
          children: [
            const Text(
              'Message Requests',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.sunsetCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.sunsetCoral.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${_requests.length}',
                style: const TextStyle(
                  color: AppColors.sunsetCoral,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _requests.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceL1,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Pending Requests',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Unvetted messages from path-crossings will appear here.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                return _buildRequestCard(req);
              },
            ),
    );
  }

  Widget _buildRequestCard(MessageRequestItem req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceL1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Location
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(req.senderAvatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          req.senderName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (req.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.sunsetCoral, size: 15),
                        ],
                        const Spacer(),
                        Text(
                          req.timeAgo,
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.radar_rounded, color: AppColors.sunsetCoral, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            req.crossedLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Message Quote Box
          InkWell(
            onTap: () => _openChat(req),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceL2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                '“${req.messageSnippet}”',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Dual Action Buttons: [Decline & Purge] and [Accept Connection]
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineRequest(req),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text(
                    'Decline & Purge',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(req),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sunsetCoral,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text(
                    'Accept Connection',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
