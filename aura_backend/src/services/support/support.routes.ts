import { Router, Request, Response } from 'express';
import { notificationService } from '../notification/notification.service.js';

export interface SupportTicketRecord {
  ticketId: string;
  userId: string;
  userEmail: string;
  userName: string;
  category: string;
  priority: 'LOW' | 'NORMAL' | 'HIGH' | 'URGENT';
  status: 'OPEN' | 'IN_REVIEW' | 'RESOLVED';
  subject: string;
  description: string;
  createdAt: string;
  updatedAt: string;
  metadata: {
    appVersion: string;
    osVersion: string;
    transactionRefId?: string;
    deviceModel?: string;
  };
  resolutionNotes?: string;
}

// In-memory persistent queue & Firestore sync mirror
const ticketsStore: Map<string, SupportTicketRecord> = new Map();

// Seed initial enterprise tickets for immediate staff queue filtering demonstration
const seedTickets: SupportTicketRecord[] = [
  {
    ticketId: 'tkt_17900101',
    userId: 'user_priya_202',
    userEmail: 'priya.sharma@example.com',
    userName: 'Priya Sharma',
    category: 'Payment / Subscription Issue',
    priority: 'HIGH',
    status: 'OPEN',
    subject: 'VIP Pass renewal charged twice',
    description: 'My UPI transaction processed twice during VIP tier subscription activation.',
    createdAt: new Date(Date.now() - 3600000 * 2).toISOString(),
    updatedAt: new Date(Date.now() - 3600000 * 2).toISOString(),
    metadata: {
      appVersion: '1.0.0+1',
      osVersion: 'Android 17 API 37',
      transactionRefId: 'UPI-REF-994827103',
      deviceModel: 'Pixel 9 Pro',
    },
  },
  {
    ticketId: 'tkt_17900102',
    userId: 'user_rohit_303',
    userEmail: 'rohit.v@example.com',
    userName: 'Rohit Verma',
    category: 'Safety & Harassment',
    priority: 'URGENT',
    status: 'IN_REVIEW',
    subject: 'Suspicious profile impersonation report',
    description: 'Observed duplicate profile using identical photography in radar grid.',
    createdAt: new Date(Date.now() - 3600000 * 5).toISOString(),
    updatedAt: new Date(Date.now() - 3600000 * 1).toISOString(),
    metadata: {
      appVersion: '1.0.0+1',
      osVersion: 'Android 16 API 36',
      deviceModel: 'Samsung Galaxy S24',
    },
  },
  {
    ticketId: 'tkt_17900103',
    userId: 'user_ananya_404',
    userEmail: 'ananya.k@example.com',
    userName: 'Ananya Kapoor',
    category: 'Profile Verification',
    priority: 'NORMAL',
    status: 'RESOLVED',
    subject: '3D biometric liveness retry query',
    description: 'Pitch challenge angle lighting question - resolved successfully with ML Kit check.',
    createdAt: new Date(Date.now() - 3600000 * 24).toISOString(),
    updatedAt: new Date(Date.now() - 3600000 * 12).toISOString(),
    metadata: {
      appVersion: '1.0.0+1',
      osVersion: 'Android 17 API 37',
      deviceModel: 'OnePlus 12',
    },
    resolutionNotes: 'User verified successfully with Euler angles Yaw=-28, Yaw=+27, Pitch=+18.',
  },
];

for (const t of seedTickets) {
  ticketsStore.set(t.ticketId, t);
}

export const supportRouter = Router();

/**
 * POST /api/support/tickets
 * In-app support ticket submission with category pickers, automated metadata, and 24h SLA confirmation email.
 */
supportRouter.post('/tickets', async (req: Request, res: Response) => {
  try {
    const {
      userId = 'user_me_001',
      userEmail = 'alex.morgan.aura@gmail.com',
      userName = 'Alex Morgan',
      category = 'Technical Bug',
      priority = 'NORMAL',
      subject,
      description,
      appVersion = '1.0.0+1',
      osVersion = 'Android 17 API 37',
      transactionRefId,
      deviceModel = 'Android Device',
    } = req.body;

    if (!subject || !description) {
      return res.status(400).json({ error: 'Subject and description are required fields.' });
    }

    const ticketId = `tkt_${Date.now()}`;
    const now = new Date().toISOString();

    const newTicket: SupportTicketRecord = {
      ticketId,
      userId,
      userEmail,
      userName,
      category,
      priority: priority.toUpperCase() as SupportTicketRecord['priority'],
      status: 'OPEN',
      subject,
      description,
      createdAt: now,
      updatedAt: now,
      metadata: {
        appVersion,
        osVersion,
        transactionRefId,
        deviceModel,
      },
    };

    ticketsStore.set(ticketId, newTicket);

    // Automated Ticketing Backend: Dispatch confirmation email with 24h SLA guarantee
    await notificationService.dispatchTicketConfirmation({
      toEmail: userEmail,
      userName,
      ticketId,
      category,
      priority: newTicket.priority,
      subject,
      slaHours: 24,
    });

    return res.status(201).json({
      success: true,
      message: 'Support ticket submitted successfully. A confirmation email has been dispatched with a 24-hour SLA.',
      ticket: newTicket,
    });
  } catch (err: any) {
    console.error('Error submitting support ticket:', err);
    return res.status(500).json({ error: 'Failed to create support ticket', details: err.message });
  }
});

/**
 * GET /api/support/tickets
 * Staff Query Engine enabling agents to filter tickets by status ("OPEN", "IN_REVIEW", "RESOLVED") and priority.
 */
supportRouter.get('/tickets', (req: Request, res: Response) => {
  try {
    const { status, priority, category, userId } = req.query;

    let tickets = Array.from(ticketsStore.values());

    if (status && typeof status === 'string' && status !== 'ALL') {
      tickets = tickets.filter((t) => t.status.toUpperCase() === status.toUpperCase());
    }

    if (priority && typeof priority === 'string' && priority !== 'ALL') {
      tickets = tickets.filter((t) => t.priority.toUpperCase() === priority.toUpperCase());
    }

    if (category && typeof category === 'string' && category !== 'ALL') {
      tickets = tickets.filter((t) => t.category.toLowerCase() === category.toLowerCase());
    }

    if (userId && typeof userId === 'string') {
      tickets = tickets.filter((t) => t.userId === userId);
    }

    // Sort newest first
    tickets.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    // Compute metrics
    const all = Array.from(ticketsStore.values());
    const metrics = {
      total: all.length,
      open: all.filter((t) => t.status === 'OPEN').length,
      inReview: all.filter((t) => t.status === 'IN_REVIEW').length,
      resolved: all.filter((t) => t.status === 'RESOLVED').length,
      urgent: all.filter((t) => t.priority === 'URGENT' && t.status !== 'RESOLVED').length,
    };

    return res.json({
      success: true,
      count: tickets.length,
      metrics,
      tickets,
    });
  } catch (err: any) {
    console.error('Error querying support tickets:', err);
    return res.status(500).json({ error: 'Failed to query support tickets', details: err.message });
  }
});

/**
 * PATCH /api/support/tickets/:ticketId/status
 * Staff agent status update endpoint (OPEN -> IN_REVIEW -> RESOLVED)
 */
supportRouter.patch('/tickets/:ticketId/status', (req: Request, res: Response) => {
  try {
    const ticketId = String(req.params.ticketId);
    const { status, resolutionNotes } = req.body;

    const ticket = ticketsStore.get(ticketId);
    if (!ticket) {
      return res.status(404).json({ error: 'Ticket not found' });
    }

    if (status) {
      ticket.status = status.toUpperCase() as SupportTicketRecord['status'];
    }
    if (resolutionNotes) {
      ticket.resolutionNotes = resolutionNotes;
    }
    ticket.updatedAt = new Date().toISOString();
    ticketsStore.set(ticketId, ticket);

    return res.json({
      success: true,
      message: `Ticket #${ticketId} status updated to ${ticket.status}`,
      ticket,
    });
  } catch (err: any) {
    console.error('Error updating support ticket:', err);
    return res.status(500).json({ error: 'Failed to update ticket', details: err.message });
  }
});
