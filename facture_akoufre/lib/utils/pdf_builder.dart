import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/invoice.dart';

class PdfBuilder {
  static Future<List<int>> build(Invoice inv, Map<String, String> settings) async {
    final pdf = pw.Document();
    final currency = settings['currency'] ?? 'Ar';
    final companyName = settings['company_name'] ?? 'Mon Entreprise';
    final companyAddress = settings['company_address'] ?? '';
    final companyCity = settings['company_city'] ?? '';
    final companyEmail = settings['company_email'] ?? '';
    final companyPhone = settings['company_phone'] ?? '';

    final blue = PdfColor.fromHex('#2563EB');
    final deepBlue = PdfColor.fromHex('#1E3A8A');
    final gray = PdfColor.fromHex('#64748B');
    final lightGray = PdfColor.fromHex('#F1F5F9');

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: [deepBlue, blue]),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(companyName,
                      style: pw.TextStyle(
                          color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  if (companyAddress.isNotEmpty)
                    pw.Text(companyAddress, style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                  if (companyCity.isNotEmpty)
                    pw.Text(companyCity, style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                  if (companyEmail.isNotEmpty)
                    pw.Text(companyEmail, style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                  if (companyPhone.isNotEmpty)
                    pw.Text(companyPhone, style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('FACTURE',
                      style: pw.TextStyle(
                          color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('N° ${inv.number}',
                      style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 11)),
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 6),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(inv.status.label.toUpperCase(),
                        style: pw.TextStyle(color: deepBlue, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                ]),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Client + Dates
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('FACTURER À',
                      style: pw.TextStyle(fontSize: 9, color: gray, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(inv.clientName,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Date : ${_fmtDate(inv.issueDate)}',
                    style: pw.TextStyle(fontSize: 10, color: gray)),
                pw.SizedBox(height: 4),
                pw.Text('Échéance : ${_fmtDate(inv.dueDate)}',
                    style: pw.TextStyle(fontSize: 10, color: gray)),
              ]),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
          pw.SizedBox(height: 12),

          // Items table header
          pw.Container(
            color: blue,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Text('Description',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 60, child: pw.Text('Qté',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 80, child: pw.Text('Prix unit.',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 80, child: pw.Text('Total',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold))),
            ]),
          ),

          // Items rows
          ...inv.items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final bg = i % 2 == 0 ? lightGray : PdfColors.white;
            return pw.Container(
              color: bg,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: pw.Row(children: [
                pw.Expanded(flex: 5, child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 10))),
                pw.SizedBox(width: 60, child: pw.Text('${item.quantity.toInt()}',
                    textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
                pw.SizedBox(width: 80, child: pw.Text('${_fmt(item.unitPrice)} $currency',
                    textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                pw.SizedBox(width: 80, child: pw.Text('${_fmt(item.total)} $currency',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
              ]),
            );
          }),

          pw.SizedBox(height: 16),

          // Totals (right-aligned)
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.SizedBox(
              width: 220,
              child: pw.Column(children: [
                _totRow('Sous-total', '${_fmt(inv.subtotal)} $currency', gray: gray),
                if (inv.discount > 0)
                  _totRow('Remise (${inv.discount.toStringAsFixed(0)}%)',
                      '- ${_fmt(inv.discountAmount)} $currency', gray: gray),
                _totRow('TVA (${inv.taxRate.toStringAsFixed(0)}%)',
                    '${_fmt(inv.taxAmount)} $currency', gray: gray),
                pw.Divider(color: blue),
                pw.Container(
                  color: blue,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('${_fmt(inv.total)} $currency',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
          ]),

          if (inv.notes.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text(inv.notes, style: const pw.TextStyle(fontSize: 10)),
              ]),
            ),
          ],

          pw.Spacer(),

          // Footer
          pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
          pw.Text('Facture Akoufre — $companyName',
              style: pw.TextStyle(fontSize: 8, color: gray)),
        ],
      ),
    ));

    return pdf.save();
  }

  static pw.Widget _totRow(String label, String value, {required PdfColor gray}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: gray)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ]),
    );
  }

  static String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  static String _fmt(double v) {
    final n = v.round();
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
