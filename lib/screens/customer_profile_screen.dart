import 'package:flutter/material.dart';

import '../database.dart';
import '../dialogs.dart';
import '../models.dart';
import '../services/statement_service.dart';
import '../theme.dart';

class CustomerProfileScreen extends StatefulWidget {
  final String customerId;
  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _db = AppDatabase.instance;
  Customer? _c;
  List<LedgerTx> _txs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await _db.getCustomer(widget.customerId);
    final t = await _db.getTransactions(widget.customerId);
    if (!mounted) return;
    setState(() {
      _c = c;
      _txs = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isDebt = c.balance > 0;
    final color = isDebt ? kGreen : (c.balance < 0 ? kRed : Colors.grey);
    final label = isDebt ? 'الصافي لك (دين)' : (c.balance < 0 ? 'الصافي عليك' : 'الحساب مسدد');

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pdf') {
                StatementService.sharePdfStatement(c, _txs);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('مشاركة كشف PDF')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(
                  '${fmt(c.balance.abs())} د.س',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
                ),
                if (c.phone != null) Text('رقم الهاتف: ${c.phone}'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _txs.isEmpty
                ? const Center(child: Text('لا توجد معاملات بعد'))
                : ListView.builder(
                    itemCount: _txs.length,
                    itemBuilder: (context, index) {
                      final t = _txs[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: t.isGave ? kRed.withOpacity(0.1) : kGreen.withOpacity(0.1),
                          child: Icon(
                            t.isGave ? Icons.arrow_upward : Icons.arrow_downward,
                            color: t.isGave ? kRed : kGreen,
                          ),
                        ),
                        title: Text(
                          t.isGave ? 'أعطيته (آجل)' : 'قبضت منه (سداد)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${fmtDate(t.createdAt)} ${t.note.isNotEmpty ? "• ${t.note}" : ""}'),
                        trailing: Text(
                          '${fmt(t.amount)} د.س',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: t.isGave ? kRed : kGreen,
                          ),
                        ),
                        onLongPress: () async {
                          await _db.deleteTransaction(t.id);
                          _load();
                        },
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
                    onPressed: () async {
                      final updated = await showAddTxSheet(context, c.id, TxType.gave);
                      if (updated) _load();
                    },
                    child: const Text('أعطيته (آجل)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white),
                    onPressed: () async {
                      final updated = await showAddTxSheet(context, c.id, TxType.got);
                      if (updated) _load();
                    },
                    child: const Text('قبضت منه (سداد)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
