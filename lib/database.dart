import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

/// قاعدة البيانات المحلية (Offline-First).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static const _uuid = Uuid();

  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'ledger.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        final b = db.batch();
        b.execute('''
          CREATE TABLE customers(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            current_balance INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            last_tx_at INTEGER,
            sync_status INTEGER NOT NULL DEFAULT 0
          )''');
        b.execute('''
          CREATE TABLE transactions(
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK(amount > 0),
            type TEXT NOT NULL CHECK(type IN ('GAVE','GOT')),
            note TEXT,
            created_at INTEGER NOT NULL,
            sync_status INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
          )''');
        b.execute('CREATE INDEX idx_tx_customer ON transactions(customer_id, created_at DESC)');
        b.execute('CREATE INDEX idx_customers_last ON customers(last_tx_at DESC)');
        b.execute('CREATE INDEX idx_customers_name ON customers(name)');
        await b.commit(noResult: true);
      },
    );
  }

  // ---------- الزبائن ----------

  Future<String> addCustomer(String name, String? phone) async {
    final db = await database;
    final id = _uuid.v4();
    final p = phone?.trim();
    await db.insert('customers', {
      'id': id,
      'name': name.trim(),
      'phone': (p == null || p.isEmpty) ? null : p,
      'current_balance': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 0,
    });
    return id;
  }

  Future<List<Customer>> getCustomers({String query = ''}) async {
    final db = await database;
    final q = query.trim();
    final rows = await db.query(
      'customers',
      where: q.isEmpty ? null : 'name LIKE ? OR phone LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
      orderBy: 'COALESCE(last_tx_at, created_at) DESC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getCustomer(String id) async {
    final db = await database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<List<Customer>> findCustomersByName(String name) async {
    final db = await database;
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];
    final where = words.map((_) => 'name LIKE ?').join(' AND ');
    final rows = await db.query(
      'customers',
      where: where,
      whereArgs: words.map((w) => '%$w%').toList(),
      orderBy: 'COALESCE(last_tx_at, created_at) DESC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<(int, int)> getTotals() async {
    final db = await database;
    final r = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN current_balance > 0 THEN current_balance END), 0) AS owed_to_me,
        COALESCE(SUM(CASE WHEN current_balance < 0 THEN -current_balance END), 0) AS i_owe
      FROM customers''');
    return (r.first['owed_to_me'] as int, r.first['i_owe'] as int);
  }

  // ---------- المعاملات ----------

  Future<String> addTransaction({
    required String customerId,
    required int amount,
    required String type,
    String note = '',
    DateTime? at,
  }) async {
    if (amount <= 0) throw ArgumentError('amount must be > 0');
    final db = await database;
    final id = _uuid.v4();
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final delta = type == TxType.gave ? amount : -amount;

    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': id,
        'customer_id': customerId,
        'amount': amount,
        'type': type,
        'note': note.trim(),
        'created_at': ts,
        'sync_status': 0,
      });
      final n = await txn.rawUpdate('''
        UPDATE customers
        SET current_balance = current_balance + ?,
            last_tx_at = MAX(COALESCE(last_tx_at, 0), ?),
            sync_status = 0
        WHERE id = ?''', [delta, ts, customerId]);
      if (n == 0) throw StateError('customer not found: $customerId');
    });
    return id;
  }

  Future<List<LedgerTx>> getTransactions(String customerId) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(LedgerTx.fromMap).toList();
  }

  Future<void> deleteTransaction(String txId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('transactions', where: 'id = ?', whereArgs: [txId], limit: 1);
      if (rows.isEmpty) return;
      final t = LedgerTx.fromMap(rows.first);
      final delta = t.type == TxType.gave ? -t.amount : t.amount;
      await txn.delete('transactions', where: 'id = ?', whereArgs: [txId]);
      await txn.rawUpdate(
        'UPDATE customers SET current_balance = current_balance + ?, sync_status = 0 WHERE id = ?',
        [delta, t.customerId],
      );
    });
  }
}
