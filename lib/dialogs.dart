import 'package:flutter/material.dart';

import 'database.dart';
import 'models.dart';
import 'services/voice_parser.dart';
import 'theme.dart';

int? parseAmount(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final sb = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final d = ar.indexOf(ch);
    sb.write(d >= 0 ? '$d' : ch);
  }
  return int.tryParse(sb.toString().replaceAll(RegExp(r'[^\d]'), ''));
}

void _snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> showAddCustomerDialog(BuildContext context) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('زبون جديد'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
        const SizedBox(height: 10),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isNotEmpty) Navigator.pop(c, true);
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await AppDatabase.instance.addCustomer(name.text, phone.text);
    return true;
  }
  return false;
}

Future<bool> showAddTxSheet(BuildContext context, String customerId, String type) async {
  final amount = TextEditingController();
  final note = TextEditingController();
  final isGave = type == TxType.gave;
  final color = isGave ? kRed : kGreen;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isGave ? 'أعطيته (آجل)' : 'قبضت منه (سداد)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 14),
        TextField(
          controller: amount,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ'),
        ),
        const SizedBox(height: 10),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'البيان (اختياري)')),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.all(14)),
            onPressed: () {
              final v = parseAmount(amount.text);
              if (v == null || v <= 0) return;
              Navigator.pop(c, true);
            },
            child: const Text('حفظ'),
          ),
        ),
      ]),
    ),
  );
  if (saved == true) {
    await AppDatabase.instance.addTransaction(
      customerId: customerId,
      amount: parseAmount(amount.text)!,
      type: type,
      note: note.text,
    );
    return true;
  }
  return false;
}

Future<bool> showVoiceEntryDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('إدخال سريع'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'مثال: عثمان أحمد أخذ اثنين كيلو سكر بـ 5000 آجل',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('تحليل')),
      ],
    ),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return false;

  final e = VoiceLedgerParser.parse(text);
  if (!e.isComplete) {
    _snack(context, 'لم أفهم الجملة كاملة. تأكد من ذكر الاسم والمبلغ و(آجل/سداد).');
    return false;
  }

  final db = AppDatabase.instance;
  final matches = await db.findCustomersByName(e.customerName!);
  if (!context.mounted) return false;
  final existing = matches.isNotEmpty ? matches.first : null;
  final isGave = e.type == TxType.gave;

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('تأكيد المعاملة'),
      content: Text(
        '${isGave ? 'آجل (أعطيته)' : 'سداد (قبضت)'} بمبلغ ${fmt(e.amount!)}\n'
        'الزبون: ${existing?.name ?? '${e.customerName} (جديد)'}\n'
        '${e.note.isEmpty ? '' : 'البيان: ${e.note}'}',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تسجيل')),
      ],
    ),
  );
  if (ok != true) return false;

  final id = existing?.id ?? await db.addCustomer(e.customerName!, null);
  await db.addTransaction(
    customerId: id,
    amount: e.amount!.round(),
    type: e.type!,
    note: e.note,
  );
  return true;
}
