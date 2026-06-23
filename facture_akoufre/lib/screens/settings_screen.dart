import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, TextEditingController> _ctrl;
  bool _saving = false;

  final _fields = [
    ('company_name', "Nom de l'entreprise", Icons.business),
    ('company_address', 'Adresse', Icons.location_on_outlined),
    ('company_city', 'Ville', Icons.location_city_outlined),
    ('company_email', 'Email', Icons.email_outlined),
    ('company_phone', 'Téléphone', Icons.phone_outlined),
    ('currency', r'Devise (ex: Ar, €, $)', Icons.attach_money),
    ('invoice_prefix', 'Préfixe facture (ex: FACT-)', Icons.tag),
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppProvider>().settings;
    _ctrl = {
      for (final f in _fields)
        f.$1: TextEditingController(text: settings[f.$1] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // App header
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
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Facture Akoufre',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('v1.0.0', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ]),
        ),

        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Votre entreprise',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              const SizedBox(height: 16),
              ...(_fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _ctrl[f.$1],
                  decoration: InputDecoration(
                    labelText: f.$2,
                    prefixIcon: Icon(f.$3, size: 20, color: kGray),
                  ),
                ),
              ))),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Enregistrer les paramètres'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final map = {for (final e in _ctrl.entries) e.key: e.value.text.trim()};
      await context.read<AppProvider>().saveAllSettings(map);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Paramètres enregistrés'),
            ]),
            backgroundColor: kSuccess,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
