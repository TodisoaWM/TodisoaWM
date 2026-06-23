import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../theme.dart';

class StatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  final bool isOverdue;

  const StatusBadge({super.key, required this.status, this.isOverdue = false});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  (String, Color, Color) _style() {
    if (isOverdue && status != InvoiceStatus.payee && status != InvoiceStatus.annulee) {
      return ('En retard', const Color(0xFFFEF3C7), kWarning);
    }
    switch (status) {
      case InvoiceStatus.payee:
        return ('Payée', const Color(0xFFDCFCE7), kSuccess);
      case InvoiceStatus.envoyee:
        return ('Envoyée', const Color(0xFFDBEAFE), kPrimary);
      case InvoiceStatus.annulee:
        return ('Annulée', const Color(0xFFFEE2E2), kDanger);
      case InvoiceStatus.brouillon:
        return ('Brouillon', const Color(0xFFF1F5F9), kGray);
    }
  }
}
