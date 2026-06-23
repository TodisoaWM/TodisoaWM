import 'invoice_item.dart';

enum InvoiceStatus { brouillon, envoyee, payee, annulee }

extension InvoiceStatusExt on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.brouillon:
        return 'Brouillon';
      case InvoiceStatus.envoyee:
        return 'Envoyée';
      case InvoiceStatus.payee:
        return 'Payée';
      case InvoiceStatus.annulee:
        return 'Annulée';
    }
  }

  String get value {
    switch (this) {
      case InvoiceStatus.brouillon:
        return 'brouillon';
      case InvoiceStatus.envoyee:
        return 'envoyée';
      case InvoiceStatus.payee:
        return 'payée';
      case InvoiceStatus.annulee:
        return 'annulée';
    }
  }

  static InvoiceStatus fromString(String s) {
    switch (s) {
      case 'envoyée':
        return InvoiceStatus.envoyee;
      case 'payée':
        return InvoiceStatus.payee;
      case 'annulée':
        return InvoiceStatus.annulee;
      default:
        return InvoiceStatus.brouillon;
    }
  }
}

class Invoice {
  final int? id;
  final String number;
  final int clientId;
  final String clientName;
  final String issueDate;
  final String dueDate;
  final InvoiceStatus status;
  final String notes;
  final double taxRate;
  final double discount;
  final List<InvoiceItem> items;
  final String createdAt;

  Invoice({
    this.id,
    required this.number,
    required this.clientId,
    this.clientName = '',
    required this.issueDate,
    required this.dueDate,
    this.status = InvoiceStatus.brouillon,
    this.notes = '',
    this.taxRate = 20.0,
    this.discount = 0.0,
    this.items = const [],
    this.createdAt = '',
  });

  double get subtotal => items.fold(0, (s, i) => s + i.total);
  double get discountAmount => subtotal * discount / 100;
  double get taxableAmount => subtotal - discountAmount;
  double get taxAmount => taxableAmount * taxRate / 100;
  double get total => taxableAmount + taxAmount;

  bool get isOverdue =>
      status != InvoiceStatus.payee &&
      status != InvoiceStatus.annulee &&
      DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) == true;

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
        id: m['id'],
        number: m['number'] ?? '',
        clientId: m['client_id'] ?? 0,
        clientName: m['client_name'] ?? '',
        issueDate: m['issue_date'] ?? '',
        dueDate: m['due_date'] ?? '',
        status: InvoiceStatusExt.fromString(m['status'] ?? 'brouillon'),
        notes: m['notes'] ?? '',
        taxRate: (m['tax_rate'] ?? 20).toDouble(),
        discount: (m['discount'] ?? 0).toDouble(),
        createdAt: m['created_at'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'number': number,
        'client_id': clientId,
        'issue_date': issueDate,
        'due_date': dueDate,
        'status': status.value,
        'notes': notes,
        'tax_rate': taxRate,
        'discount': discount,
        'created_at': createdAt.isEmpty
            ? DateTime.now().toIso8601String()
            : createdAt,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Invoice copyWith({
    int? clientId,
    String? clientName,
    String? issueDate,
    String? dueDate,
    InvoiceStatus? status,
    String? notes,
    double? taxRate,
    double? discount,
    List<InvoiceItem>? items,
  }) =>
      Invoice(
        id: id,
        number: number,
        clientId: clientId ?? this.clientId,
        clientName: clientName ?? this.clientName,
        issueDate: issueDate ?? this.issueDate,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        taxRate: taxRate ?? this.taxRate,
        discount: discount ?? this.discount,
        items: items ?? this.items,
        createdAt: createdAt,
      );
}
