class InvoiceItem {
  final int? id;
  final int invoiceId;
  final String description;
  final double quantity;
  final double unitPrice;

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
        id: m['id'],
        invoiceId: m['invoice_id'] ?? 0,
        description: m['description'] ?? '',
        quantity: (m['quantity'] ?? 1).toDouble(),
        unitPrice: (m['unit_price'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_id': invoiceId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  InvoiceItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
  }) =>
      InvoiceItem(
        id: id,
        invoiceId: invoiceId,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}
