import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/invoice.dart';
import '../../models/invoice_item.dart';
import '../../models/client.dart';
import '../../theme.dart';

class InvoiceFormScreen extends StatefulWidget {
  final Invoice? invoice;
  const InvoiceFormScreen({super.key, this.invoice});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  Client? _selectedClient;
  InvoiceStatus _status = InvoiceStatus.brouillon;
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  double _taxRate = 20;
  double _discount = 0;
  final _notesCtrl = TextEditingController();
  final List<_ItemRow> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    if (inv != null) {
      _status = inv.status;
      _issueDate = DateTime.tryParse(inv.issueDate) ?? DateTime.now();
      _dueDate = DateTime.tryParse(inv.dueDate) ?? DateTime.now().add(const Duration(days: 30));
      _taxRate = inv.taxRate;
      _discount = inv.discount;
      _notesCtrl.text = inv.notes;
      for (final item in inv.items) {
        _items.add(_ItemRow(
          description: item.description,
          qty: item.quantity,
          price: item.unitPrice,
        ));
      }
    }
    if (_items.isEmpty) _items.add(_ItemRow());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedClient == null && widget.invoice != null) {
      final clients = context.read<AppProvider>().clients;
      try {
        _selectedClient = clients.firstWhere((c) => c.id == widget.invoice!.clientId);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (s, r) => s + r.total);
  double get _discountAmt => _subtotal * _discount / 100;
  double get _taxAmt => (_subtotal - _discountAmt) * _taxRate / 100;
  double get _total => _subtotal - _discountAmt + _taxAmt;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final clients = p.clients;
    final currency = p.currency;
    final isEdit = widget.invoice != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier la facture' : 'Nouvelle facture'),
        actions: [
          if (_saving)
            const Center(
                child: Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
          else
            TextButton(
              onPressed: _save,
              child: const Text('Enregistrer',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // ── Client ────────────────────────────────────────────────────
            _Section(
              title: 'Client',
              child: Column(children: [
                DropdownButtonFormField<Client>(
                  value: _selectedClient,
                  decoration: const InputDecoration(labelText: 'Sélectionner un client'),
                  items: clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (c) => setState(() => _selectedClient = c),
                  validator: (v) => v == null ? 'Requis' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<InvoiceStatus>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: InvoiceStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (s) => setState(() => _status = s!),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Dates ─────────────────────────────────────────────────────
            _Section(
              title: 'Dates',
              child: Row(children: [
                Expanded(
                  child: _DateField(
                    label: "Date d'émission",
                    date: _issueDate,
                    onChanged: (d) => setState(() => _issueDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: "Échéance",
                    date: _dueDate,
                    onChanged: (d) => setState(() => _dueDate = d),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Articles ──────────────────────────────────────────────────
            _Section(
              title: 'Articles / Prestations',
              child: Column(children: [
                ..._items.asMap().entries.map((e) {
                  final i = e.key;
                  final row = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemRowWidget(
                      row: row,
                      currency: currency,
                      canDelete: _items.length > 1,
                      onDelete: () => setState(() => _items.removeAt(i)),
                      onChanged: () => setState(() {}),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemRow())),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une ligne'),
                  style: OutlinedButton.styleFrom(foregroundColor: kPrimary),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Totaux ────────────────────────────────────────────────────
            _Section(
              title: 'Totaux',
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _discount.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Remise (%)', suffixText: '%'),
                      onChanged: (v) => setState(() => _discount = double.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _taxRate.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'TVA (%)', suffixText: '%'),
                      onChanged: (v) => setState(() => _taxRate = double.tryParse(v) ?? 0),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(left: BorderSide(color: kPrimary, width: 3)),
                  ),
                  child: Column(children: [
                    _TotalRow('Sous-total', _subtotal, currency),
                    if (_discount > 0)
                      _TotalRow('Remise (${_discount.toStringAsFixed(0)}%)', -_discountAmt, currency),
                    _TotalRow('TVA (${_taxRate.toStringAsFixed(0)}%)', _taxAmt, currency),
                    const Divider(),
                    _TotalRow('TOTAL', _total, currency, bold: true, color: kPrimary),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Notes ─────────────────────────────────────────────────────
            _Section(
              title: 'Notes',
              child: TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Conditions de paiement, remarques...'),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Modifier la facture' : 'Créer la facture'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un client')));
      return;
    }
    final validItems = _items.where((r) => r.desc.text.trim().isNotEmpty).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ajoutez au moins un article')));
      return;
    }

    setState(() => _saving = true);
    try {
      final p = context.read<AppProvider>();
      final items = validItems.map((r) => InvoiceItem(
            invoiceId: 0,
            description: r.desc.text.trim(),
            quantity: r.qty,
            unitPrice: r.price,
          )).toList();

      final inv = Invoice(
        id: widget.invoice?.id,
        number: widget.invoice?.number ?? '',
        clientId: _selectedClient!.id!,
        clientName: _selectedClient!.name,
        issueDate: _issueDate.toIso8601String().substring(0, 10),
        dueDate: _dueDate.toIso8601String().substring(0, 10),
        status: _status,
        notes: _notesCtrl.text,
        taxRate: _taxRate,
        discount: _discount,
        items: items,
      );

      if (widget.invoice == null) {
        await p.createInvoice(inv, items);
      } else {
        await p.updateInvoice(inv, items);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Helper classes ─────────────────────────────────────────────────────────

class _ItemRow {
  final TextEditingController desc;
  double qty;
  double price;

  _ItemRow({String description = '', double qty = 1, double price = 0})
      : desc = TextEditingController(text: description),
        qty = qty,
        price = price;

  double get total => qty * price;

  void dispose() => desc.dispose();
}

class _ItemRowWidget extends StatelessWidget {
  final _ItemRow row;
  final String currency;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ItemRowWidget({
    required this.row,
    required this.currency,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: row.desc,
              decoration: const InputDecoration(
                labelText: 'Description',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              onChanged: (_) => onChanged(),
            ),
          ),
          if (canDelete) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kDanger, size: 20),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextFormField(
              initialValue: row.qty.toStringAsFixed(0),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Qté',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                row.qty = double.tryParse(v) ?? 1;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: row.price.toStringAsFixed(0),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Prix unitaire',
                suffixText: currency,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                row.price = double.tryParse(v) ?? 0;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Column(children: [
            const Text('Total', style: TextStyle(fontSize: 10, color: kGray)),
            Text(
              '${row.total.round()}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: kPrimary, fontSize: 13),
            ),
          ]),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const _DateField({required this.label, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: kPrimary),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: kGray),
        ),
        child: Text(
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final bool bold;
  final Color? color;

  const _TotalRow(this.label, this.value, this.currency,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      color: color ?? (bold ? kPrimary : kGray),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: style),
        Text(
          '${value < 0 ? "- " : ""}${value.abs().round()} $currency',
          style: style,
        ),
      ]),
    );
  }
}
