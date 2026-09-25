import '../models.dart';

class VoiceLedgerParser {
  static ParsedVoiceEntry parse(String input) {
    String text = input.trim();
    if (text.isEmpty) return ParsedVoiceEntry();

    // استخراج المبلغ
    int? amount;
    final amountMatch = RegExp(r'(\d+)\s*(ألف|الاف|آلاف)?').firstMatch(text);
    if (amountMatch != null) {
      int base = int.parse(amountMatch.group(1)!);
      if (amountMatch.group(2) != null) {
        base *= 1000;
      }
      amount = base;
    }

    // تحديد نوع المعاملة
    String? type;
    if (RegExp(r'(آجل|اجل|دين|أخذ|اخد|شال|سحب|تسجيل)').hasMatch(text)) {
      type = TxType.gave;
    } else if (RegExp(r'(سداد|دفَع|دفع|سلم|جاب|كاش|قبضت)').hasMatch(text)) {
      type = TxType.got;
    }

    // استخراج اسم الزبون (افتراض الكلمات الأولى أو البحث عن النمط)
    String? customerName;
    final words = text.split(RegExp(r'\s+'));
    if (words.isNotEmpty) {
      // يأخذ أول كلمتين كاسم مبدئي للزبون
      customerName = words.take(2).join(' ');
    }

    return ParsedVoiceEntry(
      customerName: customerName,
      amount: amount,
      type: type,
      note: text,
    );
  }
}
