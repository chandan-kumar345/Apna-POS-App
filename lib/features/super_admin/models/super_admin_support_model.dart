import 'package:flutter/material.dart';

enum TicketStatus {
  open('Open', Color(0xFF0EA5E9), Color(0xFFE0F2FE)),
  inProgress('In Progress', Color(0xFF6366F1), Color(0xFFEEF2FF)),
  waitingForCustomer('Waiting Customer', Color(0xFFF59E0B), Color(0xFFFFFBEB)),
  resolved('Resolved', Color(0xFF10B981), Color(0xFFECFDF5)),
  closed('Closed', Color(0xFF64748B), Color(0xFFF1F5F9));

  final String label;
  final Color color;
  final Color bg;
  const TicketStatus(this.label, this.color, this.bg);

  static TicketStatus fromString(String str) {
    switch (str.toLowerCase().trim()) {
      case 'open':
        return TicketStatus.open;
      case 'inprogress':
      case 'in_progress':
      case 'in progress':
        return TicketStatus.inProgress;
      case 'waitingforcustomer':
      case 'waiting_for_customer':
      case 'waiting customer':
        return TicketStatus.waitingForCustomer;
      case 'resolved':
        return TicketStatus.resolved;
      case 'closed':
        return TicketStatus.closed;
      default:
        return TicketStatus.open;
    }
  }
}

enum TicketPriority {
  low('Low', Color(0xFF10B981)),
  medium('Medium', Color(0xFF0EA5E9)),
  high('High', Color(0xFFF59E0B)),
  critical('Critical', Color(0xFFEF4444));

  final String label;
  final Color color;
  const TicketPriority(this.label, this.color);

  static TicketPriority fromString(String str) {
    switch (str.toLowerCase().trim()) {
      case 'low':
        return TicketPriority.low;
      case 'medium':
        return TicketPriority.medium;
      case 'high':
        return TicketPriority.high;
      case 'critical':
        return TicketPriority.critical;
      default:
        return TicketPriority.medium;
    }
  }
}

class SupportTicketReply {
  final String id;
  final String senderName;
  final String senderRole; // Admin, Owner, Staff
  final String message;
  final DateTime sentAt;
  final bool isAdmin;

  const SupportTicketReply({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.sentAt,
    required this.isAdmin,
  });
}

class SupportTicket {
  final String id;
  final String ticketCode;
  final String businessId;
  final String businessName;
  final String userName;
  final String userEmail;
  final String category; // Billing, Technical, POS Device, Printing, Sync, Feature Request
  final TicketPriority priority;
  final TicketStatus status;
  final String assignedAdmin;
  final String subject;
  final String initialMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportTicketReply> replies;

  const SupportTicket({
    required this.id,
    required this.ticketCode,
    required this.businessId,
    required this.businessName,
    required this.userName,
    required this.userEmail,
    required this.category,
    required this.priority,
    required this.status,
    required this.assignedAdmin,
    required this.subject,
    required this.initialMessage,
    required this.createdAt,
    required this.updatedAt,
    this.replies = const [],
  });

  SupportTicket copyWith({
    TicketStatus? status,
    TicketPriority? priority,
    String? assignedAdmin,
    DateTime? updatedAt,
    List<SupportTicketReply>? replies,
  }) {
    return SupportTicket(
      id: id,
      ticketCode: ticketCode,
      businessId: businessId,
      businessName: businessName,
      userName: userName,
      userEmail: userEmail,
      category: category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedAdmin: assignedAdmin ?? this.assignedAdmin,
      subject: subject,
      initialMessage: initialMessage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replies: replies ?? this.replies,
    );
  }
}
