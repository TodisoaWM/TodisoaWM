import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

class AppProvider extends ChangeNotifier {
  final _db = DBHelper();

  List<Invoice> _invoices = [];
  List<Client> _clients = [];
  Map<String, dynamic> _stats = {};
  Map<String, String> _settings = {};
  bool _loading = false;

  List<Invoice> get invoices => _invoices;
  List<Client> get clients => _clients;
  Map<String, dynamic> get stats => _stats;
  Map<String, String> get settings => _settings;
  bool get loading => _loading;

  String get currency => _settings['currency'] ?? 'Ar';
  String get companyName => _settings['company_name'] ?? 'Mon Entreprise';

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    await Future.wait([loadInvoices(), loadClients(), loadStats(), loadSettings()]);
    _loading = false;
    notifyListeners();
  }

  Future<void> loadInvoices({String? status, String? search}) async {
    _invoices = await _db.getInvoices(status: status, search: search);
    notifyListeners();
  }

  Future<void> loadClients({String? search}) async {
    _clients = await _db.getClients(search: search);
    notifyListeners();
  }

  Future<void> loadStats() async {
    _stats = await _db.getDashboardStats();
    notifyListeners();
  }

  Future<void> loadSettings() async {
    _settings = await _db.getAllSettings();
    notifyListeners();
  }

  Future<Invoice?> getInvoice(int id) => _db.getInvoice(id);
  Future<Client?> getClient(int id) => _db.getClient(id);

  Future<int> createInvoice(Invoice inv, List<InvoiceItem> items) async {
    final number = await _db.nextInvoiceNumber();
    final newInv = Invoice(
      number: number,
      clientId: inv.clientId,
      issueDate: inv.issueDate,
      dueDate: inv.dueDate,
      status: inv.status,
      notes: inv.notes,
      taxRate: inv.taxRate,
      discount: inv.discount,
    );
    final id = await _db.insertInvoice(newInv, items);
    await loadAll();
    return id;
  }

  Future<void> updateInvoice(Invoice inv, List<InvoiceItem> items) async {
    await _db.updateInvoice(inv, items);
    await loadAll();
  }

  Future<void> updateStatus(int id, InvoiceStatus status) async {
    await _db.updateInvoiceStatus(id, status.value);
    await loadAll();
  }

  Future<void> deleteInvoice(int id) async {
    await _db.deleteInvoice(id);
    await loadAll();
  }

  Future<int> createClient(Client c) async {
    final id = await _db.insertClient(c);
    await loadClients();
    return id;
  }

  Future<void> updateClient(Client c) async {
    await _db.updateClient(c);
    await loadClients();
  }

  Future<void> deleteClient(int id) async {
    await _db.deleteClient(id);
    await loadClients();
  }

  Future<void> saveSetting(String key, String value) async {
    await _db.setSetting(key, value);
    await loadSettings();
  }

  Future<void> saveAllSettings(Map<String, String> map) async {
    for (final e in map.entries) {
      await _db.setSetting(e.key, e.value);
    }
    await loadSettings();
  }
}
