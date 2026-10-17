import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/secret_vault_service.dart';
import '../screens/chat_screen.dart';

/// Glassmorphic container revealed exclusively when the user types the exact Secret Code into Search.
/// Styled with Dark Obsidian (#080A0F) and subtle Sunset Coral accents (#FF4D67).
class SecretVaultRevealCard extends StatefulWidget {
  final List<dynamic> hiddenConversations;
  final VoidCallback onRefresh;

  const SecretVaultRevealCard({
    super.key,
    required this.hiddenConversations,
    required this.onRefresh,
  });

  @override
  State<SecretVaultRevealCard> createState() => _SecretVaultRevealCardState();
}

class _SecretVaultRevealCardState extends State<SecretVaultRevealCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final count = widget.hiddenConversations.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE6080A0F), // Dark Obsidian 90% opacity
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header / Banner tap to expand
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF4D67).withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4D67).withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Color(0xFFFF4D67),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Secret Vault',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFFF8FAFC),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'UNLOCKED',
                                    style: TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count hidden conversation${count == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Color(0xFFFF758C),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              if (_isExpanded) ...[
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x33FF4D67),
                ),
                if (widget.hiddenConversations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No hidden chats currently in vault.',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: widget.hiddenConversations.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: Color(0x1AFFFFFF),
                      indent: 68,
                    ),
                    itemBuilder: (context, index) {
                      final conv = widget.hiddenConversations[index];
                      return _buildVaultConversationTile(context, conv);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaultConversationTile(BuildContext context, dynamic conv) {
    final matchId = conv.matchId as String;
    final name = conv.name as String;
    final avatarUrl = conv.avatarUrl as String;
    final lastMessage = conv.lastMessage as String;
    final time = conv.time as String;
    final treats = (conv.favoriteTreats as List<dynamic>?)?.cast<String>() ?? const <String>[];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              matchId: matchId,
              matchName: name,
              matchAvatarUrl: avatarUrl,
              currentUserId: 'user_me_001',
              recipientTreats: treats,
            ),
          ),
        ).then((_) => widget.onRefresh());
      },
      highlightColor: const Color(0x0AFFFFFF),
      splashColor: const Color(0xFFFF4D67).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF080A0F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 11,
                      color: Color(0xFFFF4D67),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Unhide Action Button
            IconButton(
              tooltip: 'Unhide (Move to Inbox)',
              icon: const Icon(
                Icons.lock_open_rounded,
                color: Color(0xFF38BDF8),
                size: 20,
              ),
              onPressed: () => _confirmUnhide(context, matchId, name),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnhide(BuildContext context, String matchId, String name) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF131924),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E2838)),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: Color(0xFF38BDF8)),
            const SizedBox(width: 10),
            Text(
              'Unhide Chat?',
              style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Move conversation with $name back to your primary inbox?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await SecretVaultService().removeConversationFromVault(matchId);
              widget.onRefresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Chat with $name restored to primary inbox'),
                    backgroundColor: const Color(0xFF131924),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Unhide Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Dialog to create or configure a Secret Code for the vault
class SecretCodeSetupDialog extends StatefulWidget {
  final VoidCallback? onCodeConfigured;

  const SecretCodeSetupDialog({super.key, this.onCodeConfigured});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => const SecretCodeSetupDialog(),
    );
    return result ?? false;
  }

  @override
  State<SecretCodeSetupDialog> createState() => _SecretCodeSetupDialogState();
}

class _SecretCodeSetupDialogState extends State<SecretCodeSetupDialog> {
  final _codeController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCode = true;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void dispose() {
    _codeController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final code = _codeController.text.trim();
    final confirm = _confirmController.text.trim();

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a secret code');
      return;
    }
    if (code.length < 3) {
      setState(() => _errorMessage = 'Secret code must be at least 3 characters');
      return;
    }
    if (code != confirm) {
      setState(() => _errorMessage = 'Secret codes do not match');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      await SecretVaultService().setSecretCode(code);
      widget.onCodeConfigured?.call();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save secret code: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F141C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFF4D67).withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF4D67).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFFF4D67), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Secret Code',
                        style: TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'WhatsApp-Style Stealth Chat Lock',
                        style: TextStyle(color: Color(0xFFFF758C), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Your hidden chats will disappear from your inbox. To reveal them, type this secret code into the inbox search bar.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            // Code Input
            TextField(
              controller: _codeController,
              obscureText: _obscureCode,
              style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Secret Code / Passphrase',
                labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF131924),
                prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFFFF4D67), size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscureCode = !_obscureCode),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF1E2838)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFFF4D67), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Confirm Input
            TextField(
              controller: _confirmController,
              obscureText: _obscureCode,
              style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Confirm Secret Code',
                labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF131924),
                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFFFF4D67), size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF1E2838)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFFF4D67), width: 1.5),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF4D67), fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D67),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Secret Code',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
