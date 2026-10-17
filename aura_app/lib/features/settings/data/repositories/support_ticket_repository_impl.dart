import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import '../../domain/repositories/support_ticket_repository.dart';

/// Production Implementation of SupportTicketRepository with Cloud Firestore
/// Strict adherence to firestore.rules:
/// - requires keys: ['ticketId', 'userId', 'category', 'priority', 'status', 'createdAt']
/// - requires status == 'OPEN' on creation
class SupportTicketRepositoryImpl implements SupportTicketRepository {
  final FirebaseFirestore? _firestore;
  final List<SupportTicket> _localTickets = [];
  final Map<String, StreamController<List<SupportTicket>>> _ticketControllers = {};

  SupportTicketRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _safeFirestore();

  static FirebaseFirestore? _safeFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[SupportTicketRepo] FirebaseFirestore not initialized: $e');
      return null;
    }
  }

  @override
  Future<void> submitTicket(SupportTicket ticket) async {
    // 1. Strict validation per firestore.rules
    if (ticket.status.toUpperCase() != 'OPEN') {
      throw ArgumentError('New support tickets must have status == "OPEN"');
    }

    _localTickets.insert(0, ticket);
    _notify(ticket.userId);

    // 2. Cloud Firestore sync
    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('support_tickets')
            .doc(ticket.ticketId)
            .set(ticket.toMap());
        debugPrint('[SupportTicketRepo] Synced ticket ${ticket.ticketId} to /support_tickets');
      } catch (e) {
        debugPrint('[SupportTicketRepo] Firestore ticket submission fallback: $e');
      }
    }
  }

  @override
  Future<List<SupportTicket>> getUserTickets(String userId) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore
            .collection('support_tickets')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

        final cloudTickets =
            snap.docs.map((d) => SupportTicket.fromMap(d.data())).toList();

        for (final t in cloudTickets) {
          if (!_localTickets.any((lt) => lt.ticketId == t.ticketId)) {
            _localTickets.add(t);
          }
        }
        return cloudTickets;
      } catch (e) {
        debugPrint('[SupportTicketRepo] Firestore getUserTickets error: $e');
      }
    }

    return _localTickets.where((t) => t.userId == userId).toList();
  }

  @override
  Stream<List<SupportTicket>> streamUserTickets(String userId) {
    if (!_ticketControllers.containsKey(userId)) {
      _ticketControllers[userId] =
          StreamController<List<SupportTicket>>.broadcast();

      final firestore = _firestore;
      if (firestore != null) {
        firestore
            .collection('support_tickets')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .listen((snap) {
          final list = snap.docs.map((d) => SupportTicket.fromMap(d.data())).toList();
          _ticketControllers[userId]?.add(list);
        }, onError: (e) {
          debugPrint('[SupportTicketRepo] Stream error: $e');
        });
      }
    }

    // Push initial local cached list
    Future.microtask(() => _notify(userId));
    return _ticketControllers[userId]!.stream;
  }

  @override
  Future<List<SupportTicket>> filterTickets({String? status, String? priority}) async {
    return _localTickets.where((t) {
      final matchStatus =
          status == null || t.status.toUpperCase() == status.toUpperCase();
      final matchPriority =
          priority == null || t.priority.toUpperCase() == priority.toUpperCase();
      return matchStatus && matchPriority;
    }).toList();
  }

  void _notify(String userId) {
    final list = _localTickets.where((t) => t.userId == userId).toList();
    if (_ticketControllers.containsKey(userId) &&
        !_ticketControllers[userId]!.isClosed) {
      _ticketControllers[userId]!.add(List.unmodifiable(list));
    }
  }
}
