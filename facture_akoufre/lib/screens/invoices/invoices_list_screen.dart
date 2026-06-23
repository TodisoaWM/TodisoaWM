import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/invoice.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';
import '../../utils/formatter.dart';
import 'invoice_view_screen.dart';
import 'invoice_form_screen.dart';

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  String _statusFilter = '';
  String _search = '';
  final _searchCtrl = TextEditingController();

  final _tabs = [
    ('', 'Tout'),
    ('brouillon', 'Brouillon'),
    ('envoyée', 'Envoyée'),
    ('payée', 'Payée'),
    ('annulée', 'Annulée'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final currency = p.currency;

    List<Invoice> invoices = p.invoices;
    if (_statusFilter.isNotEmpty) {
      invoices = invoices.where((i) => i.status.value == _statusFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      invoices = invoices
          .where((i) =>
              i.number.toLowerCase().contains(q) ||
              i.clientName.toLowerCase().contains(q))
          .toList();
    }

    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher une facture...',
            prefixIcon: const Icon(Icons.search, color: kGray),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: kGray),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    })
                : null,
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),

      // Status filter chips
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: _tabs.map((t) {
            final selected = _statusFilter == t.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(t.$2,
                    style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : kGray,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                selected: selected,
                selectedColor: kPrimary,
                backgroundColor: Colors.white,
                side: BorderSide(color: selected ? kPrimary : const Color(0xFFE2E8F0)),
                showCheckmark: false,
                onSelected: (_) => setState(() => _statusFilter = t.$1),
              ),
            );
          }).toList(),
        ),
      ),

      // List
      Expanded(
        child: invoices.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.description_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Aucune facture', style: TextStyle(color: kGray, fontSize: 15)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _goCreate(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer une facture'),
                  ),
                ]),
              )
            : RefreshIndicator(
                onRefresh: p.loadAll,
                color: kPrimary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: invoices.length,
                  itemBuilder: (ctx, i) {
                    final inv = invoices[i];
                    return _InvoiceCard(
                      inv: inv,
                      currency: currency,
                      onTap: () async {
                        await Navigator.push(ctx,
                            MaterialPageRoute(
                                builder: (_) => InvoiceViewScreen(invoiceId: inv.id!)));
                        p.loadAll();
                      },
                    );
                  },
                ),
              ),
      ),
    ]);
  }

  void _goCreate(BuildContext context) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const InvoiceFormScreen()));
    context.read<AppProvider>().loadAll();
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice inv;
  final String currency;
  final VoidCallback onTap;

  const _InvoiceCard({required this.inv, required this.currency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  inv.clientName.isNotEmpty ? inv.clientName[0].toUpperCase() : '?',
                  style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(inv.number,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(inv.clientName,
                      style: const TextStyle(color: kGray, fontSize: 12)),
                ]),
              ),
              StatusBadge(status: inv.status, isOverdue: inv.isOverdue),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(children: [
              _info(Icons.calendar_today_outlined, Fmt.date(inv.issueDate)),
              const SizedBox(width: 16),
              _info(
                Icons.schedule,
                Fmt.date(inv.dueDate),
                color: inv.isOverdue ? kDanger : kGray,
              ),
              const Spacer(),
              Text(Fmt.currency(inv.total, currency),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16, color: kPrimary)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text, {Color color = kGray}) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }
}
