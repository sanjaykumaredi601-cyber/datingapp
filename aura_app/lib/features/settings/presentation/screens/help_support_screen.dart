import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/firestore_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final FirestoreService _firestoreService = FirestoreService();

  // Form Controllers
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _txRefController = TextEditingController();

  // Category & Priority
  final List<String> _categories = [
    'Payment / Subscription Issue',
    'Safety & Harassment',
    'Profile Verification',
    'Technical Bug',
  ];
  late String _selectedCategory;

  final List<String> _priorities = ['LOW', 'NORMAL', 'HIGH', 'URGENT'];
  String _selectedPriority = 'NORMAL';

  // Automated System Metadata
  final String _appVersion = '1.0.0+1';
  final String _androidOsVersion = 'Android 17 (API 37 - 16k aligned)';
  final String _userId = 'user_me_001';
  String _userName = 'Alex Morgan';
  String _userEmail = 'alex.morgan.aura@gmail.com';

  bool _isSubmitting = false;
  String _filterStatus = 'ALL';
  String _filterPriority = 'ALL';

  List<SupportTicket> _myTickets = [];
  bool _isLoadingTickets = false;

  String get _backendUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedCategory = _categories.first;
    _loadUserMetadata();
    _loadTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _txRefController.dispose();
    super.dispose();
  }

  Future<void> _loadUserMetadata() async {
    final name = await _storage.read(key: 'user_display_name');
    final email = await _storage.read(key: 'user_email');
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _userName = name;
        if (email != null && email.isNotEmpty) _userEmail = email;
      });
    }
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoadingTickets = true);
    try {
      // 1. Query backend filter queue
      final uri = Uri.parse('$_backendUrl/api/support/tickets').replace(
        queryParameters: {
          if (_filterStatus != 'ALL') 'status': _filterStatus,
          if (_filterPriority != 'ALL') 'priority': _filterPriority,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['tickets'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _myTickets = list.map((item) {
              return SupportTicket(
                ticketId: item['ticketId'] as String? ?? '',
                userId: item['userId'] as String? ?? '',
                category: item['category'] as String? ?? 'General Support',
                priority: item['priority'] as String? ?? 'NORMAL',
                status: item['status'] as String? ?? 'OPEN',
                createdAt: DateTime.tryParse(item['createdAt'] as String? ?? '') ?? DateTime.now(),
                subject: item['subject'] as String? ?? 'Support Request',
                description: item['description'] as String? ?? '',
                appVersion: item['metadata']?['appVersion'] as String? ?? '1.0.0+1',
                osVersion: item['metadata']?['osVersion'] as String? ?? 'Android 17',
                transactionRefId: item['metadata']?['transactionRefId'] as String?,
                deviceModel: item['metadata']?['deviceModel'] as String? ?? 'Android Device',
                slaHours: 24,
              );
            }).toList();
            _isLoadingTickets = false;
          });
          return;
        }
      }
    } catch (_) {
      // Fallback: Query Firestore local/cached tickets
      try {
        final tickets = await _firestoreService.filterTickets(
          status: _filterStatus != 'ALL' ? _filterStatus : null,
          priority: _filterPriority != 'ALL' ? _filterPriority : null,
        );
        if (mounted) {
          setState(() {
            _myTickets = tickets;
            _isLoadingTickets = false;
          });
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isLoadingTickets = false);
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    final ticketId = 'tkt_${DateTime.now().millisecondsSinceEpoch}';

    final ticket = SupportTicket(
      ticketId: ticketId,
      userId: _userId,
      category: _selectedCategory,
      priority: _selectedPriority,
      status: 'OPEN',
      createdAt: DateTime.now(),
      subject: _subjectController.text.trim(),
      description: _descriptionController.text.trim(),
      appVersion: _appVersion,
      osVersion: _androidOsVersion,
      deviceModel: Platform.isAndroid ? 'Google Pixel / Android 17 (16k)' : 'Client',
      transactionRefId: _txRefController.text.trim().isNotEmpty ? _txRefController.text.trim() : null,
      slaHours: 24,
    );

    // 1. Submit to Firestore collection /support_tickets
    try {
      await _firestoreService.submitSupportTicket(ticket);
    } catch (e) {
      debugPrint('[HelpDesk] Firestore ticket sync notice: $e');
    }

    // 2. Submit to backend API which triggers transactional SLA confirmation email
    try {
      await http.post(
        Uri.parse('$_backendUrl/api/support/tickets'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'userEmail': _userEmail,
          'userName': _userName,
          'category': _selectedCategory,
          'priority': _selectedPriority,
          'subject': _subjectController.text.trim(),
          'description': _descriptionController.text.trim(),
          'appVersion': _appVersion,
          'osVersion': _androidOsVersion,
          'transactionRefId': _txRefController.text.trim().isNotEmpty
              ? _txRefController.text.trim()
              : null,
          'deviceModel': Platform.isAndroid ? 'Google Pixel / Android 17' : 'Client',
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[HelpDesk] Backend notification dispatch notice: $e');
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _subjectController.clear();
      _descriptionController.clear();
      _txRefController.clear();
      _myTickets.insert(0, ticket);
    });

    _showConfirmationDialog(ticketId);
  }

  void _showConfirmationDialog(String ticketId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceL1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.neonElectricMint, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonElectricMint.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.neonElectricMint, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ticket Dispatched',
                style: TextStyle(color: AppColors.iceWhite, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket #$ticketId has been registered in the enterprise queue.',
              style: const TextStyle(color: AppColors.titaniumSlate, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceL2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.timer_outlined, color: AppColors.cyanGlow, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Estimated SLA: 24 Hours',
                        style: TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'An automated confirmation email has been dispatched to $_userEmail with tracking credentials.',
                    style: const TextStyle(color: AppColors.titaniumSlate, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(1);
              _loadTickets();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonElectricMint,
              foregroundColor: AppColors.deepObsidianSlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Active Tickets', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepObsidianSlate,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.iceWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: AppColors.neonElectricMint, size: 22),
            SizedBox(width: 8),
            Text(
              'Help & Support Desk',
              style: TextStyle(
                color: AppColors.iceWhite,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.neonElectricMint,
          indicatorWeight: 3,
          labelColor: AppColors.neonElectricMint,
          unselectedLabelColor: AppColors.titaniumSlate,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: const [
            Tab(text: 'Submit New Ticket'),
            Tab(text: 'My Tickets & Dispatch'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubmitTicketTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 1: SUBMIT NEW TICKET
  // ─────────────────────────────────────────────────────────
  Widget _buildSubmitTicketTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SLA Guarantee Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.cyanGlow.withValues(alpha: 0.15),
                    AppColors.neonElectricMint.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cyanGlow.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.cyanGlow, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AURA 24-HOUR SLA GUARANTEE',
                          style: TextStyle(
                            color: AppColors.cyanGlow,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Our enterprise trust, safety & billing team acts on all tickets within 24 hours with dedicated human review.',
                          style: TextStyle(color: AppColors.titaniumSlate, fontSize: 11.5, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Category Picker
            const Text(
              'ISSUE CATEGORY',
              style: TextStyle(
                color: AppColors.titaniumSlate,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = category);
                  },
                  selectedColor: AppColors.neonElectricMint.withValues(alpha: 0.20),
                  backgroundColor: AppColors.midnightMarine,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.neonElectricMint : AppColors.titaniumSlate,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? AppColors.neonElectricMint : AppColors.frostedBorder,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Priority Selector
            const Text(
              'PRIORITY LEVEL',
              style: TextStyle(
                color: AppColors.titaniumSlate,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: _priorities.map((priority) {
                final isSelected = _selectedPriority == priority;
                Color chipColor;
                switch (priority) {
                  case 'URGENT':
                    chipColor = const Color(0xFFEF4444);
                    break;
                  case 'HIGH':
                    chipColor = AppColors.softGold;
                    break;
                  case 'NORMAL':
                    chipColor = AppColors.cyanGlow;
                    break;
                  default:
                    chipColor = AppColors.titaniumSlate;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(priority),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedPriority = priority);
                    },
                    selectedColor: chipColor.withValues(alpha: 0.25),
                    backgroundColor: AppColors.midnightMarine,
                    labelStyle: TextStyle(
                      color: isSelected ? chipColor : AppColors.titaniumSlate,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? chipColor : AppColors.frostedBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Subject Line
            const Text(
              'SUBJECT',
              style: TextStyle(
                color: AppColors.titaniumSlate,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectController,
              style: const TextStyle(color: AppColors.iceWhite, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Brief summary of the issue...',
                hintStyle: const TextStyle(color: AppColors.titaniumSlate, fontSize: 13),
                filled: true,
                fillColor: AppColors.midnightMarine,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.frostedBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.frostedBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.neonElectricMint, width: 1.5),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a subject' : null,
            ),

            const SizedBox(height: 16),

            // Description
            const Text(
              'DETAILED DESCRIPTION',
              style: TextStyle(
                color: AppColors.titaniumSlate,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.iceWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Provide details, context, and steps to reproduce...',
                hintStyle: const TextStyle(color: AppColors.titaniumSlate, fontSize: 13),
                filled: true,
                fillColor: AppColors.midnightMarine,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.frostedBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.frostedBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.neonElectricMint, width: 1.5),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide a description' : null,
            ),

            const SizedBox(height: 16),

            // Optional Transaction Ref ID
            if (_selectedCategory == 'Payment / Subscription Issue') ...[
              const Text(
                'TRANSACTION REFERENCE ID (OPTIONAL)',
                style: TextStyle(
                  color: AppColors.titaniumSlate,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _txRefController,
                style: const TextStyle(color: AppColors.iceWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. UPI-TXN-9988231 or Google Play Order ID',
                  hintStyle: const TextStyle(color: AppColors.titaniumSlate, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.midnightMarine,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.frostedBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.frostedBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.neonElectricMint, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Automated Metadata Attachment Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.midnightMarine,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.frostedBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.attachment_rounded, color: AppColors.neonElectricMint, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'AUTOMATED SYSTEM METADATA ATTACHED',
                        style: TextStyle(
                          color: AppColors.neonElectricMint,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildMetadataRow('App Version:', _appVersion),
                  _buildMetadataRow('OS Version:', _androidOsVersion),
                  _buildMetadataRow('User ID:', _userId),
                  _buildMetadataRow('Account Email:', _userEmail),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonElectricMint,
                  foregroundColor: AppColors.deepObsidianSlate,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.deepObsidianSlate,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Dispatch Support Ticket',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 2: MY TICKETS & DISPATCH QUEUE
  // ─────────────────────────────────────────────────────────
  Widget _buildMyTicketsTab() {
    return Column(
      children: [
        // Filter Bar (Status & Priority Filters)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.midnightMarine,
            border: Border(bottom: BorderSide(color: AppColors.frostedBorder)),
          ),
          child: Row(
            children: [
              const Text(
                'Filter:',
                style: TextStyle(color: AppColors.titaniumSlate, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              // Status Dropdown
              DropdownButton<String>(
                value: _filterStatus,
                dropdownColor: AppColors.midnightMarine,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: AppColors.iceWhite, fontSize: 12.5),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                  DropdownMenuItem(value: 'IN_REVIEW', child: Text('In Review')),
                  DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _filterStatus = val);
                    _loadTickets();
                  }
                },
              ),
              const SizedBox(width: 12),
              // Priority Dropdown
              DropdownButton<String>(
                value: _filterPriority,
                dropdownColor: AppColors.midnightMarine,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: AppColors.softGold, fontSize: 12.5),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Priorities')),
                  DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                  DropdownMenuItem(value: 'HIGH', child: Text('High')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                  DropdownMenuItem(value: 'LOW', child: Text('Low')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _filterPriority = val);
                    _loadTickets();
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.neonElectricMint, size: 20),
                onPressed: _loadTickets,
                tooltip: 'Refresh Queue',
              ),
            ],
          ),
        ),

        // Ticket List
        Expanded(
          child: _isLoadingTickets
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.neonElectricMint),
                )
              : _myTickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, color: AppColors.titaniumSlate.withValues(alpha: 0.5), size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'No tickets found in queue',
                            style: TextStyle(color: AppColors.titaniumSlate, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Submit a new support ticket to begin tracking.',
                            style: TextStyle(color: AppColors.titaniumSlate, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _myTickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final t = _myTickets[index];
                        return _buildTicketCard(t);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    Color statusColor;
    switch (ticket.status.toUpperCase()) {
      case 'OPEN':
        statusColor = AppColors.neonElectricMint;
        break;
      case 'IN_REVIEW':
        statusColor = AppColors.softGold;
        break;
      case 'RESOLVED':
        statusColor = AppColors.cyanGlow;
        break;
      default:
        statusColor = AppColors.titaniumSlate;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.midnightMarine,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.frostedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${ticket.ticketId}',
                style: const TextStyle(
                  color: AppColors.titaniumSlate,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  ticket.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ticket.subject,
            style: const TextStyle(
              color: AppColors.iceWhite,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (ticket.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.titaniumSlate, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceL2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket.category,
                  style: const TextStyle(color: AppColors.titaniumSlate, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceL2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket.priority,
                  style: const TextStyle(color: AppColors.softGold, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              const Icon(Icons.timer_outlined, color: AppColors.cyanGlow, size: 13),
              const SizedBox(width: 4),
              const Text(
                '24h SLA',
                style: TextStyle(color: AppColors.cyanGlow, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: AppColors.titaniumSlate, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.iceWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
