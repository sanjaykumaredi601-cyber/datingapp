import 'package:aura_app/core/services/firestore_service.dart';

/// Contract for Enterprise Help Desk Support Ticket Submission Pipeline
abstract class SupportTicketRepository {
  /// Submits a support ticket to Firestore `/support_tickets/{ticketId}`
  Future<void> submitTicket(SupportTicket ticket);

  /// Retrieves support tickets created by a specific user
  Future<List<SupportTicket>> getUserTickets(String userId);

  /// Real-time stream of support tickets for a user
  Stream<List<SupportTicket>> streamUserTickets(String userId);

  /// Filter tickets by status or priority
  Future<List<SupportTicket>> filterTickets({String? status, String? priority});
}
