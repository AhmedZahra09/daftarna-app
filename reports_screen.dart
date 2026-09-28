import 'package:flutter/material.dart';
import '../database.dart';
import '../models.dart';
import '../theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = AppDatabase.instance;
  List<Customer> _customers = [];
  int _owedToMe = 0;
  int _iOwe = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final totals = await _db.getTotals();
    final list = await _db.getCustomers();
    if (!mounted) return;
    setState(() {
      _owedToMe = totals.$1;
      _iOwe = totals.$2;
      _customers = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final debtors = _customers.where((c) => c.balance > 0).toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    final creditors = _customers.where((c) => c.balance < 0).toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));
    final net = _owedToMe - _iOwe;

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _statCard('عدد الزبائن', '${_customers.length}', Colors.blueGrey)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('الصافي', '${fmt(net.abs())} د.س', net >= 0 ? kGreen : kRed)),
            ],
          ),
          const SizedBox(height: 20),
          Text('الأكثر مديونية لك', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (debtors.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('لا يوجد زبائن عليهم دين حاليًا'))
          else
            ...debtors.take(10).map((c) => _debtRow(c, kGreen)),
          const SizedBox(height: 20),
          Text('المستحق عليك لهم', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (creditors.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('لا يوجد مبالغ مستحقة عليك حاليًا'))
          else
            ...creditors.take(10).map((c) => _debtRow(c, kRed)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _debtRow(Customer c, Color color) {
    return ListTile(
      title: Text(c.name),
      trailing: Text('${fmt(c.balance.abs())} د.س',
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
