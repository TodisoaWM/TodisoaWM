import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/client.dart';
import '../../theme.dart';

class ClientFormScreen extends StatefulWidget {
  final Client? client;
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Madagascar');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    if (c != null) {
      _name.text = c.name;
      _email.text = c.email;
      _phone.text = c.phone;
      _address.text = c.address;
      _city.text = c.city;
      _country.text = c.country;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address, _city, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.client != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier le client' : 'Nouveau client'),
        actions: [
          if (_saving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20,
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
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Avatar preview
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(
                    _name.text.isNotEmpty ? _name.text[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 28, color: kPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 20),

                _field(_name, 'Nom *', required: true, onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_phone, 'Téléphone', keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_address, 'Adresse'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_city, 'Ville')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_country, 'Pays')),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(isEdit ? 'Modifier' : 'Créer le client'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false,
      TextInputType? keyboardType,
      ValueChanged<String>? onChanged}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null : null,
      onChanged: onChanged,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final p = context.read<AppProvider>();
      final client = Client(
        id: widget.client?.id,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        country: _country.text.trim(),
      );
      if (widget.client == null) {
        await p.createClient(client);
      } else {
        await p.updateClient(client);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
