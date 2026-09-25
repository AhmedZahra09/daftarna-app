/// أنواع المعاملات
class TxType {
  static const gave = 'GAVE'; // أعطيته (آجل/دين)
  static const got = 'GOT';   // قبضت منه (سداد)
}

class Customer {
  final String id;
  final String name;
  final String? phone;
  final int balance;
  final int createdAt;
  final int? lastTxAt;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
    required this.createdAt,
    this.lastTxAt,
  });

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        balance: m['current_balance'] as int,
        createdAt: m['created_at'] as int,
        lastTxAt: m['last_tx_at'] as int?,
      );
}

class LedgerTx {
  final String id;
  final String customerId;
  final int amount;
  final String type;
  final String note;
  final int createdAt;

  const LedgerTx({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.type,
    required this.note,
    required this.createdAt,
  });

  bool get isGave => type == TxType.gave;

  factory LedgerTx.fromMap(Map<String, Object?> m) => LedgerTx(
        id: m['id'] as String,
        customerId: m['customer_id'] as String,
        amount: m['amount'] as int,
        type: m['type'] as String,
        note: (m['note'] as String?) ?? '',
        createdAt: m['created_at'] as int,
      );
}

class ParsedVoiceEntry {
  final String? customerName;
  final int? amount;
  final String? type;
  final String note;

  ParsedVoiceEntry({
    this.customerName,
    this.amount,
    this.type,
    this.note = '',
  });

  bool get isComplete => customerName != null && amount != null && type != null;
}

class IncomingTransfer {
  final double amount;
  final String? sender;

  IncomingTransfer({required this.amount, this.sender});
}
