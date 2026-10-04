import 'package:flutter/material.dart';

enum PaymentStatus {
  successful('Successful', Color(0xFF10B981), Color(0xFFECFDF5)),
  pending('Pending', Color(0xFFF59E0B), Color(0xFFFFFBEB)),
  failed('Failed', Color(0xFFEF4444), Color(0xFFFEF2F2)),
  refunded('Refunded', Color(0xFF6366F1), Color(0xFFEEF2FF)),
  cancelled('Cancelled', Color(0xFF64748B), Color(0xFFF1F5F9));

  final String label;
  final Color color;
  final Color bg;
  const PaymentStatus(this.label, this.color, this.bg);

  static PaymentStatus fromString(String str) {
    switch (str.toLowerCase().trim()) {
      case 'successful':
      case 'completed':
      case 'paid':
        return PaymentStatus.successful;
      case 'pending':
        return PaymentStatus.pending;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'cancelled':
      case 'canceled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.successful;
    }
  }
}

enum PaymentMethod {
  upi('UPI', Icons.qr_code_rounded),
  card('Credit/Debit Card', Icons.credit_card_rounded),
  netBanking('Net Banking', Icons.account_balance_rounded),
  cash('Cash', Icons.payments_rounded),
  gateway('Online Gateway', Icons.account_balance_wallet_rounded);

  final String label;
  final IconData icon;
  const PaymentMethod(this.label, this.icon);

  static PaymentMethod fromString(String str) {
    switch (str.toLowerCase().trim()) {
      case 'upi':
        return PaymentMethod.upi;
      case 'card':
      case 'debit card':
      case 'credit card':
        return PaymentMethod.card;
      case 'netbanking':
      case 'net banking':
        return PaymentMethod.netBanking;
      case 'cash':
        return PaymentMethod.cash;
      default:
        return PaymentMethod.gateway;
    }
  }
}

/// Sales Transaction Record
class PlatformSaleRecord {
  final String id;
  final String transactionId;
  final String invoiceNumber;
  final String businessId;
  final String businessName;
  final String ownerName;
  final String planName;
  final double amount;
  final PaymentStatus status;
  final PaymentMethod method;
  final String saleType; // New, Renewal, Upgrade, Downgrade, Add-on
  final DateTime date;
  final String? notes;

  const PlatformSaleRecord({
    required this.id,
    required this.transactionId,
    required this.invoiceNumber,
    required this.businessId,
    required this.businessName,
    required this.ownerName,
    required this.planName,
    required this.amount,
    required this.status,
    required this.method,
    required this.saleType,
    required this.date,
    this.notes,
  });

  PlatformSaleRecord copyWith({
    PaymentStatus? status,
    String? notes,
  }) {
    return PlatformSaleRecord(
      id: id,
      transactionId: transactionId,
      invoiceNumber: invoiceNumber,
      businessId: businessId,
      businessName: businessName,
      ownerName: ownerName,
      planName: planName,
      amount: amount,
      status: status ?? this.status,
      method: method,
      saleType: saleType,
      date: date,
      notes: notes ?? this.notes,
    );
  }
}

/// Invoice Model with downloadable printable items
class PlatformInvoice {
  final String id;
  final String invoiceNumber;
  final String businessId;
  final String businessName;
  final String businessAddress;
  final String businessGstin;
  final String customerEmail;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final PaymentStatus status;
  final DateTime issueDate;
  final DateTime dueDate;
  final DateTime? paidDate;
  final List<InvoiceItem> items;
  final String? pdfDownloadUrl;

  const PlatformInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.businessId,
    required this.businessName,
    required this.businessAddress,
    required this.businessGstin,
    required this.customerEmail,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.status,
    required this.issueDate,
    required this.dueDate,
    this.paidDate,
    required this.items,
    this.pdfDownloadUrl,
  });
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  const InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}
