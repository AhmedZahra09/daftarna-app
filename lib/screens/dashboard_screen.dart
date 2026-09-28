import 'package:flutter/material.dart';
import '../database.dart';
import '../dialogs.dart';
import '../models.dart';
import '../theme.dart';
import 'customer_profile_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = AppDatabase.instance;
  List<Customer> _customers = [];
  int _owedToMe = 0;
  int _iOwe = 0;
  String _searchQuery = '';
  String _sortBy = 'recent';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final totals = await _db.getTotals();
    final list = await _db.getCustomers(query: _searchQuery);
    setState(() {
      _owedToMe = totals.$1;
      _iOwe = totals.$2;
      _customers = _applySort(list);
    });
  }

  List<Customer> _applySort(List<Customer> list) {
    final sorted = [...list];
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'balance':
        sorted.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
        break;
      default:
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سكولي'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'ترتيب',
            onSelected: (v) => setState(() {
              _sortBy = v;
              _customers = _applySort(_customers);
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'recent', child: Text('الأحدث')),
              PopupMenuItem(value: 'name', child: Text('الاسم (أبجديًا)')),
              PopupMenuItem(value: 'balance', child: Text('الأكثر رصيدًا')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            onPressed: () async {
              final updated = await showVoiceEntryDialog(context);
              if (updated) _refreshData();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('سكولي',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kGreen)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: const Text('التقارير'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('الإعدادات'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          SummaryCard(owedToMe: _owedToMe, iOwe: _iOwe),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث باسم الزبون أو الرقم...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _refreshData();
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _customers.isEmpty
                ? const Center(child: Text('لا يوجد زبائن مسجلين بعد'))
                : ListView.builder(
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final c = _customers[index];
                      final isDebt = c.balance > 0;
                      return ListTile(
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(c.phone ?? 'بدون رقم هاتف'),
                        trailing: Text(
                          '${fmt(c.balance.abs())} د.س',
                          style: TextStyle(
                            color: isDebt ? kGreen : (c.balance < 0 ? kRed : Colors.grey),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerProfileScreen(customerId: c.id),
                            ),
                          );
                          _refreshData();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await showAddCustomerDialog(context);
          if (added) _refreshData();
        },
        label: const Text('زبون جديد'),
        icon: const Icon(Icons.add),
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}
