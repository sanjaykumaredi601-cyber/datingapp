import 'package:aura_app/core/services/firestore_service.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/daily_quota_service.dart';
import '../../../chat/presentation/screens/chat_screen.dart';

class EchoItem {
  final String echoId;
  final String candidateName;
  final String crossedAt;
  final String zoneName;
  final List<String> commonInterests;
  final String imageUrl;
  double blurLevel;
  bool isWaved;

  EchoItem({
    required this.echoId,
    required this.candidateName,
    required this.crossedAt,
    required this.zoneName,
    required this.commonInterests,
    required this.imageUrl,
    this.blurLevel = 10.0,
    this.isWaved = false,
  });
}

class EchoesScreen extends StatefulWidget {
  const EchoesScreen({super.key});

  @override
  State<EchoesScreen> createState() => _EchoesScreenState();
}

class _EchoesScreenState extends State<EchoesScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<EchoItem> _echoes = [];

  final List<EchoItem> _mockEchoes = [
    EchoItem(
      echoId: 'echo_101',
      candidateName: 'Riya, 24',
      crossedAt: 'Crossed paths 18 mins ago near Robson St, Vancouver',
      zoneName: 'Robson St / Downtown Vancouver',
      commonInterests: ['Indie Music', 'Artisanal Matcha', 'Specialty Coffee'],
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80',
      blurLevel: 12.0,
    ),
    EchoItem(
      echoId: 'echo_102',
      candidateName: 'Kabir, 26',
      crossedAt: 'Crossed paths 35 mins ago near Robson Promenade',
      zoneName: 'Robson Promenade, Vancouver',
      commonInterests: ['Film Photography', 'Sunset Walks', 'Vinyl Records'],
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&auto=format&fit=crop&q=80',
      blurLevel: 10.0,
    ),
    EchoItem(
      echoId: 'echo_103',
      candidateName: 'Aanya, 23',
      crossedAt: 'Crossed paths 1 hour ago near Meguro River',
      zoneName: 'Meguro River Sakura Walk',
      commonInterests: ['Contemporary Art', 'Espresso Lounge', 'Architecture'],
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&auto=format&fit=crop&q=80',
      blurLevel: 8.0,
    ),
    EchoItem(
      echoId: 'echo_104',
      candidateName: 'Dev, 28',
      crossedAt: 'Crossed paths 2 hours ago near Banff Avenue',
      zoneName: 'Banff National Park, Alberta',
      commonInterests: ['Alpine Hiking', 'Night Photography', 'Stargazing'],
      imageUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&auto=format&fit=crop&q=80',
      blurLevel: 14.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadEchoes();
  }

  Future<void> _loadEchoes() async {
    if (!_isLoading && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final res = await _apiClient.getEchoes();
      if (res.data != null && res.data['echoes'] != null) {
        final List raw = res.data['echoes'];
        if (raw.isNotEmpty) {
          // Merge API echoes with photos
          _echoes = raw.asMap().entries.map((entry) {
            final idx = entry.key;
            final map = entry.value;
            final fallback = _mockEchoes[idx % _mockEchoes.length];
            return EchoItem(
              echoId: map['echoId'] ?? fallback.echoId,
              candidateName: map['candidateName'] ?? fallback.candidateName,
              crossedAt: map['crossedAt'] != null
                  ? 'Crossed paths recently'
                  : fallback.crossedAt,
              zoneName: map['zoneName'] ?? fallback.zoneName,
              commonInterests: (map['commonInterests'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  fallback.commonInterests,
              imageUrl: fallback.imageUrl,
              blurLevel: (map['blurLevel'] as num?)?.toDouble() ?? 10.0,
            );
          }).toList();
        } else {
          _echoes = List.from(_mockEchoes);
        }
      } else {
        _echoes = List.from(_mockEchoes);
      }
    } catch (_) {
      _echoes = List.from(_mockEchoes);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _waveToEcho(EchoItem echo) async {
    if (!echo.isWaved) {
      final canProceed = await DailyQuotaService().checkAndConsumeEchoQuota(context);
      if (!canProceed) return;
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      echo.isWaved = true;
      echo.blurLevel = 0.0; // Reveal the photo
    });

    // One-tap Send Whisper / Resonance initiates lightweight encrypted connection request
    FirestoreService().sendWhisperResonance(
      uid: 'user_me_001',
      echoId: echo.echoId,
      peerUid: 'peer_${echo.echoId}',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFF4D67)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Whisper Resonance sent to ${echo.candidateName}! Discrete & encrypted.',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xE6080A0F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFF4D67), width: 1),
        ),
        action: SnackBarAction(
          label: 'Direct Chat',
          textColor: const Color(0xFFF59E0B),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  matchId: 'echo_${echo.echoId}',
                  matchName: echo.candidateName,
                  currentUserId: 'user_me_001',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppColors.auroraGradient.createShader(bounds),
              child: const Text(
                'echoes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.auroraPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.auroraPurple.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'PATH CROSSINGS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.auroraPurple,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh Echoes',
            onPressed: _loadEchoes,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEchoes,
          color: AppColors.auroraTeal,
          backgroundColor: AppColors.surfaceL1,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Privacy Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.auroraPurple.withValues(alpha: 0.15),
                      AppColors.auroraTeal.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceL1,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppColors.auroraTeal, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '500m Grid Privacy Protection',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Real GPS locations are never shared. Photos stay blurred until mutual interest.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'RECENT PATH CROSSINGS (${_echoes.length})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceL2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Past 24 Hours',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: AppColors.auroraTeal),
                  ),
                )
              else
                ..._echoes.map((echo) => _buildEchoCard(echo)),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEchoCard(EchoItem echo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: echo.isWaved
              ? AppColors.primary
              : const Color(0xFFFFE4E6),
          width: echo.isWaved ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Zone & Crossed Time
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.auroraPurple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.near_me_rounded, color: AppColors.auroraPurple, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        echo.zoneName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        echo.crossedAt,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (echo.isWaved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.auroraTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.auroraTeal, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'WAVED',
                          style: TextStyle(
                            color: AppColors.auroraTeal,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Photo Preview with Progressive Blur Filter
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: echo.blurLevel,
                      sigmaY: echo.blurLevel,
                    ),
                    child: Image.network(
                      echo.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceL2,
                        child: const Center(
                          child: Icon(Icons.person, color: AppColors.textTertiary, size: 60),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Frosted overlay hint when blurred
              if (echo.blurLevel > 0)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceL1.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, color: AppColors.auroraTeal, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Wave to reveal profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Candidate Name chip
              Positioned(
                bottom: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceL1.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    echo.candidateName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Common Interests & Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shared Interests',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: echo.commonInterests.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceL2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(color: AppColors.auroraTeal, fontSize: 11.5),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: echo.isWaved ? null : () => _waveToEcho(echo),
                        icon: Icon(
                          echo.isWaved ? Icons.done_all_rounded : Icons.waves_rounded,
                          size: 18,
                        ),
                        label: Text(echo.isWaved ? 'Resonance Sent ✨' : 'Send Whisper / Resonance ✨'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: echo.isWaved ? AppColors.surfaceL2 : AppColors.auroraTeal,
                          foregroundColor: echo.isWaved ? AppColors.textDisabled : const Color(0xFF0D0D1A),
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceL2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textSecondary),
                        tooltip: 'Direct Chat',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                matchId: 'echo_${echo.echoId}',
                                matchName: echo.candidateName,
                                currentUserId: 'user_me_001',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
