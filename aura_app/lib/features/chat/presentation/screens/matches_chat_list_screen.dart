import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/secret_vault_service.dart';
import '../widgets/secret_vault_widgets.dart';
import 'chat_screen.dart';
import 'message_requests_screen.dart';

/// Interoperability typedef matching Principal Mobile Architecture
typedef MessagesListScreen = MatchesChatListScreen;

class MatchConversation {
  final String matchId;
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final bool isVerified;
  final List<String> favoriteTreats;

  const MatchConversation({
    required this.matchId,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isVerified = true,
    this.favoriteTreats = const ['Dark Chocolate', 'Coffee'],
  });
}

class MatchesChatListScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final bool initialVaultUnlocked;

  const MatchesChatListScreen({
    super.key,
    this.initialSearchQuery,
    this.initialVaultUnlocked = false,
  });

  @override
  State<MatchesChatListScreen> createState() => _MatchesChatListScreenState();
}

class _MatchesChatListScreenState extends State<MatchesChatListScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isVaultUnlocked = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedMatchIds = <String>{};
  String _searchQuery = '';

  final List<MatchConversation> _conversations = [];
  bool _isLoadingChats = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsSubscription;

  @override
  void initState() {
    super.initState();
    _isVaultUnlocked = widget.initialVaultUnlocked;
    if (widget.initialSearchQuery != null) {
      _searchQuery = widget.initialSearchQuery!;
      _searchController.text = widget.initialSearchQuery!;
    }
    WidgetsBinding.instance.addObserver(this);
    SecretVaultService().initialize();
    SecretVaultService().addListener(_onVaultChanged);
    _subscribeToLiveChats();
  }

  void _subscribeToLiveChats() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        setState(() => _isLoadingChats = false);
        return;
      }

      // Bind strictly to live Cloud Firestore subcollection: /users/{currentUserId}/chats
      _chatsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chats')
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          final matchId = doc.id;
          final name = (data['peerName'] ?? data['name'] ?? 'Match').toString();
          final avatarUrl = (data['peerAvatarUrl'] ?? data['avatarUrl'] ?? '').toString();
          final lastMsg = (data['lastMessage'] ?? data['snippet'] ?? '').toString();
          final unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
          final isOnline = data['isOnline'] == true;
          final isVerified = data['isVerified'] != false;

          String time = 'Just now';
          if (data['lastMessageTimestamp'] is Timestamp) {
            final dt = (data['lastMessageTimestamp'] as Timestamp).toDate();
            final diff = DateTime.now().difference(dt);
            if (diff.inMinutes < 60) {
              time = '${diff.inMinutes}m ago';
            } else if (diff.inHours < 24) {
              time = '${diff.inHours}h ago';
            } else {
              time = '${diff.inDays}d ago';
            }
          } else if (data['time'] != null) {
            time = data['time'].toString();
          }

          final treats = (data['favoriteTreats'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const ['Dark Chocolate', 'Coffee'];

          return MatchConversation(
            matchId: matchId,
            name: name,
            avatarUrl: avatarUrl,
            lastMessage: lastMsg,
            time: time,
            unreadCount: unreadCount,
            isOnline: isOnline,
            isVerified: isVerified,
            favoriteTreats: treats,
          );
        }).toList();

        setState(() {
          _conversations.clear();
          _conversations.addAll(list);
          _isLoadingChats = false;
        });
      }, onError: (err) {
        debugPrint('[MatchesChatList] Live Firestore chats notice: $err');
        if (mounted) setState(() => _isLoadingChats = false);
      });
    } catch (e) {
      debugPrint('[MatchesChatList] Setup error: $e');
      if (mounted) setState(() => _isLoadingChats = false);
    }
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SecretVaultService().removeListener(_onVaultChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onVaultChanged() {
    if (mounted) setState(() {});
  }

  // --- Auto-Purge from Memory on Inactive / Paused Lifecycle ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      SecretVaultService().purgeMemoryUnlockState();
      if (mounted) {
        setState(() {
          _isVaultUnlocked = false;
          _searchController.clear();
          _searchQuery = '';
          _isSelectionMode = false;
          _selectedMatchIds.clear();
        });
      }
    }
  }

  Future<void> _onSearchChanged(String query) async {
    _searchQuery = query;
    final trimmed = query.trim();

    if (trimmed.isNotEmpty) {
      final matches = await SecretVaultService().verifySecretCode(trimmed);
      if (mounted) {
        setState(() {
          _isVaultUnlocked = matches;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isVaultUnlocked = false;
        });
      }
    }
  }

  void _onTileLongPress(MatchConversation conv) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedMatchIds.add(conv.matchId);
    });
  }

  void _onTileTap(MatchConversation conv) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedMatchIds.contains(conv.matchId)) {
          _selectedMatchIds.remove(conv.matchId);
          if (_selectedMatchIds.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedMatchIds.add(conv.matchId);
        }
      });
    } else {
      _openChat(conv);
    }
  }

  Future<void> _confirmMoveSelectedToVault() async {
    debugPrint('[_confirmMoveSelectedToVault] CALLED with count: ${_selectedMatchIds.length}');
    if (_selectedMatchIds.isEmpty) return;

    final hasCode = await SecretVaultService().hasSecretCodeConfigured();
    debugPrint('[_confirmMoveSelectedToVault] hasCode: $hasCode');
    if (!mounted) return;

    if (!hasCode) {
      final created = await SecretCodeSetupDialog.show(context);
      debugPrint('[_confirmMoveSelectedToVault] code setup result: $created');
      if (!created || !mounted) return;
    }

    final count = _selectedMatchIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F141C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFFF4D67), size: 22),
            const SizedBox(width: 10),
            Text(
              'Hide $count Chat${count == 1 ? '' : 's'} in Vault?',
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Selected $count conversation${count == 1 ? '' : 's'} will vanish from your inbox and can only be accessed by entering your Secret Code in Search.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D67),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Lock in Vault', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await SecretVaultService().addConversationsToVault(_selectedMatchIds.toList());
      if (!mounted) return;
      setState(() {
        _isSelectionMode = false;
        _selectedMatchIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count conversation${count == 1 ? '' : 's'} moved to Secret Vault'),
          backgroundColor: const Color(0xFF0F141C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultService = SecretVaultService();
    final hiddenIds = vaultService.hiddenConversationIds;

    // Filter conversations: Hidden conversations are completely filtered out from primary inbox
    final visibleConversations =
        _conversations.where((c) => !hiddenIds.contains(c.matchId)).toList();
    final hiddenConversations =
        _conversations.where((c) => hiddenIds.contains(c.matchId)).toList();

    // Regular search filter when query is entered and vault code is NOT matched
    final searchFilteredList = (_searchQuery.isNotEmpty && !_isVaultUnlocked)
        ? visibleConversations.where((c) {
            final query = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(query) ||
                c.lastMessage.toLowerCase().contains(query);
          }).toList()
        : visibleConversations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : _buildStandardAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Inbox Search Bar with Real-Time Stealth Secret Code Trigger
            _buildSearchBar(),

            // Stealth Secret Vault Reveal (Exclusively displayed when query matches Secret Code)
            if (_isVaultUnlocked)
              SecretVaultRevealCard(
                hiddenConversations: hiddenConversations,
                onRefresh: () => setState(() {}),
              ),

            // Message Requests Banner / Tray (Only visible when not actively searching)
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 14),
              _buildMessageRequestsBanner(),
              const SizedBox(height: 20),
            ],

            // New Matches Carousel (Filtered: Zero hidden profiles visible)
            if (_searchQuery.isEmpty && visibleConversations.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'NEW MATCHES',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildMatchesCarousel(visibleConversations),
              const SizedBox(height: 16),
              const Divider(color: AppColors.surfaceL2, height: 1),
              const SizedBox(height: 14),
            ],

            // Conversations Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _searchQuery.isNotEmpty ? 'SEARCH RESULTS' : 'CONVERSATIONS',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (_isSelectionMode)
                    Text(
                      '${_selectedMatchIds.length} SELECTED',
                      style: const TextStyle(
                        color: Color(0xFFFF4D67),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Filtered Conversations List
            if (_isLoadingChats)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.sunsetCoral, strokeWidth: 2.5),
                ),
              )
            else if (searchFilteredList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceL2,
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            color: AppColors.sunsetCoral, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ? 'No Results' : 'No matches yet',
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No matches or messages found for "$_searchQuery"'
                            : 'Start exploring profiles nearby to spark a connection!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...searchFilteredList.map((conv) => _buildConversationTile(conv)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildStandardAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          const Text(
            'messages',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Color(0xFFF8FAFC),
              shadows: [
                Shadow(
                  color: Color(0x40FF4D67),
                  blurRadius: 16,
                ),
                Shadow(
                  color: Color(0x4D7928CA),
                  blurRadius: 24,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF7928CA).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF7928CA).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: const Text(
              'ENCRYPTED',
              style: TextStyle(
                color: Color(0xFFC084FC),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F141C),
      elevation: 4,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Color(0xFFF8FAFC)),
        onPressed: () {
          setState(() {
            _isSelectionMode = false;
            _selectedMatchIds.clear();
          });
        },
      ),
      title: Text(
        '${_selectedMatchIds.length} Selected',
        style: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Move to Secret Vault',
          icon: const Icon(Icons.lock_rounded, color: Color(0xFFFF4D67), size: 24),
          onPressed: () {
            debugPrint('[_confirmMoveSelectedToVault] PRESSED!');
            _confirmMoveSelectedToVault();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceL1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isVaultUnlocked
                ? const Color(0xFFFF4D67).withValues(alpha: 0.5)
                : AppColors.glassBorder,
          ),
          boxShadow: _isVaultUnlocked
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF4D67).withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _isVaultUnlocked ? Icons.lock_open_rounded : Icons.search_rounded,
              color: _isVaultUnlocked ? const Color(0xFFFF4D67) : AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Search matches & messages...',
                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13.5),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary, size: 18),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRequestsBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MessageRequestsScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceL1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF4D67).withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_rounded, color: Color(0xFFFF4D67), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message Requests',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '3 unvetted requests waiting for review',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D67), Color(0xFFF472B6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Text(
                  '3 NEW',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textTertiary, size: 13),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchesCarousel(List<MatchConversation> visibleConversations) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: visibleConversations.length,
        itemBuilder: (context, index) {
          final match = visibleConversations[index];
          return GestureDetector(
            onTap: () => _onTileTap(match),
            child: Container(
              width: 76,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF4D67), Color(0xFF7928CA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: match.unreadCount > 0
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF4D67).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(match.avatarUrl),
                        ),
                      ),
                      if (match.isOnline)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F5A0),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F5A0).withValues(alpha: 0.7),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    match.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationTile(MatchConversation conv) {
    final isSelected = _selectedMatchIds.contains(conv.matchId);

    return InkWell(
      onTap: () => _onTileTap(conv),
      onLongPress: () => _onTileLongPress(conv),
      highlightColor: const Color(0x0AFFFFFF),
      splashColor: const Color(0xFFFF4D67).withValues(alpha: 0.12),
      child: Container(
        color: isSelected ? const Color(0x1FFF4D67) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Checkmark or Selection Indicator in Selection Mode
            if (_isSelectionMode) ...[
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFFFF4D67) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF4D67) : const Color(0xFF64748B),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],

            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: NetworkImage(conv.avatarUrl),
                ),
                if (conv.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5A0),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00F5A0).withValues(alpha: 0.7),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                conv.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (conv.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Color(0xFF00D2FF), size: 16),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        conv.time,
                        style: TextStyle(
                          color: conv.unreadCount > 0 ? const Color(0xFFFF4D67) : AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: conv.unreadCount > 0 ? AppColors.textPrimary : AppColors.textTertiary,
                            fontSize: 13,
                            fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4D67), Color(0xFFE11D48)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4D67).withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(MatchConversation conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          matchId: conv.matchId,
          matchName: conv.name,
          matchAvatarUrl: conv.avatarUrl,
          currentUserId: 'user_me_001',
          recipientTreats: conv.favoriteTreats,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}
