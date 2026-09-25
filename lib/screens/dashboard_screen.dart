import 'package:flutter/material.dart';
import '../database.dart';
import '../dialogs.dart';
import '../models.dart';
import '../theme.dart';
import 'customer_profile_screen.dart';
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
      _customers = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دفترنا'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            onPressed: () async {
              final updated = await showVoiceEntryDialog(context);
              if (updated) _refreshData();
            },
          ),
        ],
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
