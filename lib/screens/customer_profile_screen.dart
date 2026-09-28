import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _editCustomer(Customer c) async {
    final nameCtrl = TextEditingController(text: c.name);
    final phoneCtrl = TextEditingController(text: c.phone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات الزبون'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 10),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم الهاتف'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await _db.updateCustomer(c.id, name: nameCtrl.text, phone: phoneCtrl.text);
      _load();
    }
  }

  Future<void> _deleteCustomer(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الزبون'),
        content: Text('هل أنت متأكد من حذف "${c.name}"؟ سيتم حذف كل معاملاته أيضًا ولا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _db.deleteCustomer(c.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _sendWhatsAppReminder(Customer c) async {
    if (c.phone == null || c.phone!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رقم هاتف مسجل لهذا الزبون')),
      );
      return;
    }
    final phone = c.phone!.replaceAll(RegExp(r'[^0-9]'), '');
    final message = Uri.encodeComponent(
      'تذكير من سكولي: المبلغ المستحق عليك حاليًا هو ${fmt(c.balance.abs())} د.س. نرجو السداد في أقرب وقت، شكرًا لك.',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب، تأكد من رقم الهاتف')),
      );
    }
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
              } else if (v == 'whatsapp') {
                _sendWhatsAppReminder(c);
              } else if (v == 'edit') {
                _editCustomer(c);
              } else if (v == 'delete') {
                _deleteCustomer(c);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('مشاركة كشف PDF')),
              PopupMenuItem(value: 'whatsapp', child: Text('تذكير عبر واتساب')),
              PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
              PopupMenuItem(value: 'delete', child: Text('حذف الزبون')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
