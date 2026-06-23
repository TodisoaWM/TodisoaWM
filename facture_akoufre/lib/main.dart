import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'theme.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/invoices/invoices_list_screen.dart';
import 'screens/invoices/invoice_form_screen.dart';
import 'screens/clients/clients_list_screen.dart';
import 'screens/clients/client_form_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const AkoufreApp());
}

class AkoufreApp extends StatelessWidget {
  const AkoufreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..loadAll(),
      child: MaterialApp(
        title: 'Facture Akoufre',
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
        routes: {
          '/client/new': (_) => const ClientFormScreen(),
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    InvoicesListScreen(),
    ClientsListScreen(),
    SettingsScreen(),
  ];

  final _titles = const [
    'Tableau de bord',
    'Factures',
    'Clients',
    'Paramètres',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.receipt_long, size: 22),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Facture Akoufre',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
            Text(_titles[_index],
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white70)),
          ]),
        ]),
        actions: [
          if (_index == 0 || _index == 1)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Nouvelle facture',
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InvoiceFormScreen()));
                if (context.mounted) context.read<AppProvider>().loadAll();
              },
            ),
          if (_index == 2)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Nouveau client',
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ClientFormScreen()));
                if (context.mounted) context.read<AppProvider>().loadClients();
              },
            ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDBEAFE),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view, color: kPrimary),
            label: 'Tableau',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: kPrimary),
            label: 'Factures',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: kPrimary),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: kPrimary),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
