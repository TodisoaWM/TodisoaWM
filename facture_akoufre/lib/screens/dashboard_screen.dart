import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../models/invoice.dart';
import '../theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'invoices/invoice_view_screen.dart';
import '../utils/formatter.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final stats = p.stats;
    final currency = p.currency;

    if (p.loading && stats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final monthly = (stats['monthly'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final recent = (stats['recent'] as List?)?.cast<Invoice>() ?? [];

    return RefreshIndicator(
      onRefresh: p.loadAll,
      color: kPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header greeting
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kPrimaryDeep, kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bonjour !',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(p.companyName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Revenus encaissés',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                  Text(
                    Fmt.currency(stats['revenue'] ?? 0, currency),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ]),
              ),
              const Icon(Icons.receipt_long, color: Colors.white38, size: 56),
            ]),
          ),

          const SizedBox(height: 16),
          const Text('Aperçu',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),

          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: [
              StatCard(
                label: 'Total factures',
                value: '${stats['total'] ?? 0}',
                icon: Icons.description_outlined,
                iconBg: const Color(0xFFDBEAFE),
                iconColor: kPrimary,
              ),
              StatCard(
                label: 'Payées',
                value: '${stats['paid'] ?? 0}',
                icon: Icons.check_circle_outline,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: kSuccess,
              ),
              StatCard(
                label: 'En attente',
                value: '${stats['pending'] ?? 0}',
                icon: Icons.hourglass_empty,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: kWarning,
              ),
              StatCard(
                label: 'En retard',
                value: '${stats['overdue'] ?? 0}',
                icon: Icons.warning_amber_outlined,
                iconBg: const Color(0xFFFEE2E2),
                iconColor: kDanger,
              ),
            ],
          ),

          // Chart
          if (monthly.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Factures par mois',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGray)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: BarChart(BarChartData(
                      barGroups: List.generate(monthly.length, (i) {
                        final count = (monthly[i]['count'] as int).toDouble();
                        return BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                              toY: count,
                              color: kPrimary,
                              width: 18,
                              borderRadius: BorderRadius.circular(6)),
                        ]);
                      }),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= monthly.length) return const SizedBox();
                              final m = monthly[i]['month'] as String;
                              return Text(m.substring(5),
                                  style: const TextStyle(fontSize: 10, color: kGray));
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                    )),
                  ),
                ]),
              ),
            ),
          ],

          // Recent invoices
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Récentes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            TextButton(
              onPressed: () {},
              child: const Text('Voir tout', style: TextStyle(color: kPrimary)),
            ),
          ]),
          if (recent.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  const Text('Aucune facture', style: TextStyle(color: kGray)),
                ]),
              ),
            )
          else
            ...recent.map((inv) => _InvoiceTile(inv: inv, currency: currency)),
        ]),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice inv;
  final String currency;
  const _InvoiceTile({required this.inv, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text(
            inv.clientName.isNotEmpty ? inv.clientName[0].toUpperCase() : '?',
            style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(inv.number,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(inv.clientName,
            style: const TextStyle(color: kGray, fontSize: 12)),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(Fmt.currency(inv.total, currency),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kPrimary)),
            const SizedBox(height: 4),
            StatusBadge(status: inv.status, isOverdue: inv.isOverdue),
          ],
        ),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => InvoiceViewScreen(invoiceId: inv.id!))),
      ),
    );
  }
}
