import 'package:intl/intl.dart';

class Fmt {
  static String currency(double value, String symbol) {
    final n = NumberFormat('#,##0', 'fr_FR').format(value.round());
    return '$n $symbol';
  }

  static String date(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  static String dateShort(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd MMM', 'fr_FR').format(d);
    } catch (_) {
      return iso;
    }
  }
}
