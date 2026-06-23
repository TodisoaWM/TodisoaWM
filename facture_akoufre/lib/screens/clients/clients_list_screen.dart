import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/client.dart';
import '../../theme.dart';
import 'client_form_screen.dart';

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  String _search = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    List<Client> clients = p.clients;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      clients = clients.where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q)).toList();
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Rechercher un client...',
            prefixIcon: const Icon(Icons.search, color: kGray),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: kGray),
                    onPressed: () { _ctrl.clear(); setState(() => _search = ''); })
                : null,
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      Expanded(
        child: clients.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Aucun client', style: TextStyle(color: kGray, fontSize: 15)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _goCreate(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un client'),
                  ),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: clients.length,
                itemBuilder: (ctx, i) => _ClientCard(
                  client: clients[i],
                  onEdit: () async {
                    await Navigator.push(ctx,
                        MaterialPageRoute(
                            builder: (_) => ClientFormScreen(client: clients[i])));
                    p.loadClients();
                  },
                  onDelete: () => _delete(ctx, clients[i]),
                ),
              ),
      ),
    ]);
  }

  void _goCreate(BuildContext context) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ClientFormScreen()));
    context.read<AppProvider>().loadClients();
  }

  Future<void> _delete(BuildContext context, Client client) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce client ?'),
        content: Text('${client.name} sera supprimé définitivement.'),
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
      await context.read<AppProvider>().deleteClient(client.id!);
    }
  }
}

class _ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientCard({required this.client, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text(
            client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
            style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        title: Text(client.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (client.email.isNotEmpty)
              Row(children: [
                const Icon(Icons.email_outlined, size: 12, color: kGray),
                const SizedBox(width: 4),
                Text(client.email, style: const TextStyle(fontSize: 12, color: kGray)),
              ]),
            if (client.phone.isNotEmpty)
              Row(children: [
                const Icon(Icons.phone_outlined, size: 12, color: kGray),
                const SizedBox(width: 4),
                Text(client.phone, style: const TextStyle(fontSize: 12, color: kGray)),
              ]),
            if (client.city.isNotEmpty)
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: kGray),
                const SizedBox(width: 4),
                Text(client.city, style: const TextStyle(fontSize: 12, color: kGray)),
              ]),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: kGray),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_outlined, size: 18, color: kPrimary),
              SizedBox(width: 8),
              Text('Modifier'),
            ])),
            const PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: kDanger),
              SizedBox(width: 8),
              Text('Supprimer', style: TextStyle(color: kDanger)),
            ])),
          ],
        ),
      ),
    );
  }
}
