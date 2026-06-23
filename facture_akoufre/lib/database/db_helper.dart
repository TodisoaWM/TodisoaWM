import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._();
  factory DBHelper() => _instance;
  DBHelper._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'akoufre.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        country TEXT DEFAULT 'Madagascar',
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL UNIQUE,
        client_id INTEGER NOT NULL,
        issue_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'brouillon',
        notes TEXT DEFAULT '',
        tax_rate REAL DEFAULT 20.0,
        discount REAL DEFAULT 0.0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (client_id) REFERENCES clients(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        unit_price REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    final defaults = {
      'company_name': 'Mon Entreprise',
      'company_address': '',
      'company_email': '',
      'company_phone': '',
      'company_city': '',
      'currency': 'Ar',
      'invoice_prefix': 'FACT-',
      'next_number': '1',
    };
    for (final e in defaults.entries) {
      await db.insert('settings', {'key': e.key, 'value': e.value},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<String> getSetting(String key, {String def = ''}) async {
    final d = await db;
    final rows = await d.query('settings', where: 'key=?', whereArgs: [key]);
    return rows.isEmpty ? def : (rows.first['value'] as String? ?? def);
  }

  Future<void> setSetting(String key, String value) async {
    final d = await db;
    await d.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllSettings() async {
    final d = await db;
    final rows = await d.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String? ?? ''};
  }

  Future<String> nextInvoiceNumber() async {
    final prefix = await getSetting('invoice_prefix', def: 'FACT-');
    final n = int.parse(await getSetting('next_number', def: '1'));
    final number = '$prefix${n.toString().padLeft(4, '0')}';
    await setSetting('next_number', '${n + 1}');
    return number;
  }

  // ── Clients ───────────────────────────────────────────────────────────────

  Future<List<Client>> getClients({String? search}) async {
    final d = await db;
    List<Map<String, dynamic>> rows;
    if (search != null && search.isNotEmpty) {
      rows = await d.query('clients',
          where: 'name LIKE ? OR email LIKE ?',
          whereArgs: ['%$search%', '%$search%'],
          orderBy: 'name');
    } else {
      rows = await d.query('clients', orderBy: 'name');
    }
    return rows.map(Client.fromMap).toList();
  }

  Future<Client?> getClient(int id) async {
    final d = await db;
    final rows = await d.query('clients', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  Future<int> insertClient(Client c) async {
    final d = await db;
    return d.insert('clients', c.toMap());
  }

  Future<void> updateClient(Client c) async {
    final d = await db;
    await d.update('clients', c.toMap(), where: 'id=?', whereArgs: [c.id]);
  }

  Future<void> deleteClient(int id) async {
    final d = await db;
    await d.delete('clients', where: 'id=?', whereArgs: [id]);
  }

  // ── Invoices ──────────────────────────────────────────────────────────────

  Future<List<Invoice>> getInvoices({String? status, String? search}) async {
    final d = await db;
    String where = '1=1';
    final args = <dynamic>[];
    if (status != null && status.isNotEmpty) {
      where += ' AND i.status=?';
      args.add(status);
    }
    if (search != null && search.isNotEmpty) {
      where += ' AND (c.name LIKE ? OR i.number LIKE ?)';
      args.addAll(['%$search%', '%$search%']);
    }
    final rows = await d.rawQuery('''
      SELECT i.*, c.name as client_name
      FROM invoices i JOIN clients c ON i.client_id=c.id
      WHERE $where ORDER BY i.created_at DESC
    ''', args);
    final invoices = <Invoice>[];
    for (final row in rows) {
      final inv = Invoice.fromMap(row);
      final itemRows = await d.query('invoice_items',
          where: 'invoice_id=?', whereArgs: [inv.id]);
      invoices.add(inv.copyWith(items: itemRows.map(InvoiceItem.fromMap).toList()));
    }
    return invoices;
  }

  Future<Invoice?> getInvoice(int id) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT i.*, c.name as client_name,
        c.email as client_email, c.phone as client_phone,
        c.address as client_address, c.city as client_city,
        c.country as client_country
      FROM invoices i JOIN clients c ON i.client_id=c.id
      WHERE i.id=?
    ''', [id]);
    if (rows.isEmpty) return null;
    final itemRows = await d.query('invoice_items',
        where: 'invoice_id=?', whereArgs: [id]);
    return Invoice.fromMap(rows.first)
        .copyWith(items: itemRows.map(InvoiceItem.fromMap).toList());
  }

  Future<int> insertInvoice(Invoice inv, List<InvoiceItem> items) async {
    final d = await db;
    final invId = await d.insert('invoices', inv.toMap());
    for (final item in items) {
      await d.insert('invoice_items',
          InvoiceItem(invoiceId: invId, description: item.description,
              quantity: item.quantity, unitPrice: item.unitPrice).toMap());
    }
    return invId;
  }

  Future<void> updateInvoice(Invoice inv, List<InvoiceItem> items) async {
    final d = await db;
    await d.update('invoices', inv.toMap(), where: 'id=?', whereArgs: [inv.id]);
    await d.delete('invoice_items', where: 'invoice_id=?', whereArgs: [inv.id]);
    for (final item in items) {
      await d.insert('invoice_items',
          InvoiceItem(invoiceId: inv.id!, description: item.description,
              quantity: item.quantity, unitPrice: item.unitPrice).toMap());
    }
  }

  Future<void> updateInvoiceStatus(int id, String status) async {
    final d = await db;
    await d.update('invoices',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteInvoice(int id) async {
    final d = await db;
    await d.delete('invoice_items', where: 'invoice_id=?', whereArgs: [id]);
    await d.delete('invoices', where: 'id=?', whereArgs: [id]);
  }

  // ── Dashboard stats ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final d = await db;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final total = Sqflite.firstIntValue(
        await d.rawQuery('SELECT COUNT(*) FROM invoices')) ?? 0;
    final paid = Sqflite.firstIntValue(await d.rawQuery(
        "SELECT COUNT(*) FROM invoices WHERE status='payée'")) ?? 0;
    final pending = Sqflite.firstIntValue(await d.rawQuery(
        "SELECT COUNT(*) FROM invoices WHERE status IN ('envoyée','brouillon')")) ?? 0;
    final overdue = Sqflite.firstIntValue(await d.rawQuery(
        "SELECT COUNT(*) FROM invoices WHERE status NOT IN ('payée','annulée') AND due_date < ?",
        [today])) ?? 0;

    // Revenue from paid invoices
    final paidInvoices = await getInvoices(status: 'payée');
    final revenue = paidInvoices.fold(0.0, (s, i) => s + i.total);

    // Monthly counts (last 6 months)
    final monthly = await d.rawQuery('''
      SELECT strftime('%Y-%m', issue_date) as month, COUNT(*) as count
      FROM invoices
      WHERE issue_date >= date('now', '-6 months')
      GROUP BY month ORDER BY month
    ''');

    // Recent invoices
    final recentRows = await d.rawQuery('''
      SELECT i.*, c.name as client_name
      FROM invoices i JOIN clients c ON i.client_id=c.id
      ORDER BY i.created_at DESC LIMIT 5
    ''');
    final recent = <Invoice>[];
    for (final row in recentRows) {
      final inv = Invoice.fromMap(row);
      final itemRows = await d.query('invoice_items',
          where: 'invoice_id=?', whereArgs: [inv.id]);
      recent.add(inv.copyWith(items: itemRows.map(InvoiceItem.fromMap).toList()));
    }

    return {
      'total': total,
      'paid': paid,
      'pending': pending,
      'overdue': overdue,
      'revenue': revenue,
      'monthly': monthly,
      'recent': recent,
    };
  }
}
