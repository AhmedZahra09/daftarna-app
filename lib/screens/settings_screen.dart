import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportBackup(BuildContext context) async {
    final db = AppDatabase.instance;
    final customers = await db.getCustomers();
    final data = <String, dynamic>{'customers': [], 'transactions': []};

    for (final c in customers) {
      data['customers'].add({
        'id': c.id,
        'name': c.name,
        'phone': c.phone,
        'balance': c.balance,
        'created_at': c.createdAt,
        'last_tx_at': c.lastTxAt,
      });
      final txs = await db.getTransactions(c.id);
      for (final t in txs) {
        data['transactions'].add({
          'id': t.id,
          'customer_id': t.customerId,
          'amount': t.amount,
          'type': t.type,
          'note': t.note,
          'created_at': t.createdAt,
        });
      }
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sekoly_backup.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية من بيانات سكولي');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('الوضع الليلي'),
            trailing: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, mode, _) => Switch(
                value: mode == ThemeMode.dark,
                activeColor: kGreen,
                onChanged: (v) {
                  themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('نسخة احتياطية (تصدير)'),
            subtitle: const Text('مشاركة كل بياناتك كملف JSON'),
            onTap: () => _exportBackup(context),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('عن التطبيق'),
            subtitle: Text('سكولي — إدارة ديون ومبيعات الزبائن'),
          ),
        ],
      ),
    );
  }
}
