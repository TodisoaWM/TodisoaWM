import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_provider.dart';
import '../../models/invoice.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';
import '../../utils/formatter.dart';
import '../../utils/pdf_builder.dart';
import 'invoice_form_screen.dart';

class InvoiceViewScreen extends StatefulWidget {
  final int invoiceId;
  const InvoiceViewScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  Invoice? _invoice;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    final inv = await p.getInvoice(widget.invoiceId);
    if (mounted) setState(() { _invoice = inv; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final inv = _invoice;
    if (inv == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facture')),
        body: const Center(child: Text('Facture introuvable')),
      );
    }

    final p = context.read<AppProvider>();
    final currency = p.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.number),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => InvoiceFormScreen(invoice: inv)));
              _load();
              p.loadAll();
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF',
            onPressed: () => _showPdf(inv, p.settings),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _onMenuAction(v, inv),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(Icons.delete_outline, color: kDanger, size: 18),
                SizedBox(width: 8),
                Text('Supprimer', style: TextStyle(color: kDanger)),
              ])),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Alert if overdue
          if (inv.isOverdue)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber, color: kWarning),
                SizedBox(width: 8),
                Expanded(child: Text('Paiement en retard !',
                    style: TextStyle(color: kWarning, fontWeight: FontWeight.w600))),
              ]),
            ),

          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(p.settings['company_name'] ?? 'Mon Entreprise',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: kPrimary, fontSize: 16)),
                  StatusBadge(status: inv.status, isOverdue: inv.isOverdue),
                ]),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('CLIENT', style: TextStyle(fontSize: 10, color: kGray, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(inv.clientName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('DATE', style: TextStyle(fontSize: 10, color: kGray, fontWeight: FontWeight.w600)),
                    Text(Fmt.date(inv.issueDate),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('ÉCHÉANCE', style: TextStyle(fontSize: 10, color: kGray, fontWeight: FontWeight.w600)),
                    Text(Fmt.date(inv.dueDate),
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: inv.isOverdue ? kDanger : null)),
                  ]),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // Items
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: const [
                  Expanded(flex: 4, child: Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kGray))),
                  Expanded(child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kGray))),
                  Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kGray))),
                ]),
                const Divider(),
                ...inv.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text(item.description, style: const TextStyle(fontSize: 13))),
                    Expanded(child: Text('${item.quantity.toInt()}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: kGray))),
                    Expanded(flex: 2, child: Text(
                      '${item.total.round()} $currency',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    )),
                  ]),
                )),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // Totals
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _Row('Sous-total', Fmt.currency(inv.subtotal, currency)),
                if (inv.discount > 0)
                  _Row('Remise (${inv.discount.toStringAsFixed(0)}%)',
                      '- ${Fmt.currency(inv.discountAmount, currency)}',
                      color: kDanger),
                _Row('TVA (${inv.taxRate.toStringAsFixed(0)}%)', Fmt.currency(inv.taxAmount, currency)),
                const Divider(),
                _Row('TOTAL', Fmt.currency(inv.total, currency), bold: true, color: kPrimary),
              ]),
            ),
          ),

          if (inv.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(inv.notes, style: const TextStyle(color: kGray, fontSize: 13)),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Status change
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Changer le statut',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in InvoiceStatus.values)
                    if (s != inv.status)
                      OutlinedButton(
                        onPressed: () => _changeStatus(inv, s),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _statusColor(s),
                          side: BorderSide(color: _statusColor(s)),
                        ),
                        child: Text(s.label, style: const TextStyle(fontSize: 12)),
                      ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showPdf(inv, p.settings),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Télécharger / Partager le PDF'),
          ),
        ),
      ),
    );
  }

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.payee: return kSuccess;
      case InvoiceStatus.envoyee: return kPrimary;
      case InvoiceStatus.annulee: return kDanger;
      case InvoiceStatus.brouillon: return kGray;
    }
  }

  Future<void> _changeStatus(Invoice inv, InvoiceStatus status) async {
    await context.read<AppProvider>().updateStatus(inv.id!, status);
    _load();
  }

  Future<void> _showPdf(Invoice inv, Map<String, String> settings) async {
    final pdfBytes = await PdfBuilder.build(inv, settings);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/facture_${inv.number}.pdf');
    await file.writeAsBytes(pdfBytes);
    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Facture ${inv.number}',
    );
  }

  void _onMenuAction(String action, Invoice inv) async {
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Supprimer la facture ?'),
          content: Text('La facture ${inv.number} sera supprimée définitivement.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: kDanger)),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await context.read<AppProvider>().deleteInvoice(inv.id!);
        if (mounted) Navigator.pop(context);
      }
    }
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _Row(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      color: color ?? (bold ? kPrimary : const Color(0xFF334155)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: style),
        Text(value, style: style),
      ]),
    );
  }
}
