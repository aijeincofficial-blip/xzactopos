import '../data/sales_models.dart';
import 'money.dart';

/// The words of an utang statement, from the ARB files (en / fil), so this file holds no UI text.
class StatementLabels {
  const StatementLabels({
    required this.title,
    required this.balance,
    required this.dueOn,
    required this.recent,
    required this.charge,
    required this.payment,
    required this.adjust,
  });

  /// Heading before the customer's name, e.g. "Utang statement" -> "Utang statement: Aling Rosa".
  final String title;

  /// "Balance", "Due on" (shown only when a due date is set), "Recent" (heading of the ledger lines).
  final String balance;
  final String dueOn;
  final String recent;

  /// Ledger kinds: charge (took on utang), payment, adjust.
  final String charge;
  final String payment;
  final String adjust;
}

/// Most ledger lines on a statement (the newest ones).
const statementMaxLines = 10;

/// A plain-text utang statement to share by Messenger or SMS (P8-10):
///
///     <store name>
///     <title>: <customer name>
///     <balance>: ₱150.00
///     <dueOn>: 2026-11-15                 (only when a due date is set)
///
///     <recent>:
///     2026-11-08  <charge>  +₱150.00      (newest first, at most [statementMaxLines])
///     2026-11-07  <payment>  -₱50.00
///
/// Dates are YYYY-MM-DD (the same in every language), money via [Money.format] for [locale] with an explicit sign on
/// ledger lines (+ owes more, - owes less). The customer's phone number and ledger notes are NEVER in the text (the
/// phone is only where it is sent; a note may hold anything). The recent block is left out when [ledger] is empty.
String utangStatementText({
  required String storeName,
  required CustomerView customer,
  required List<LedgerEntryView> ledger,
  required String currency,
  required String locale,
  required StatementLabels labels,
}) {
  String money(int amount) {
    final sign = amount < 0 ? '-' : '';
    return '$sign${Money(amount.abs(), currency).format(locale)}';
  }

  String signed(int amount) => amount > 0 ? '+${money(amount)}' : money(amount);

  String kind(String k) => switch (k) {
        'charge' => labels.charge,
        'payment' => labels.payment,
        _ => labels.adjust,
      };

  final out = <String>[
    storeName.trim(),
    '${labels.title}: ${customer.name.trim()}',
    '${labels.balance}: ${money(customer.balance)}',
    if (customer.dueOn != null) '${labels.dueOn}: ${dayKey(customer.dueOn!)}',
  ];
  // newest first; entries at the same moment keep the order they were given in (List.sort alone is not stable)
  final order = [for (var i = 0; i < ledger.length; i++) i]..sort((a, b) {
      final c = ledger[b].at.compareTo(ledger[a].at);
      return c != 0 ? c : a.compareTo(b);
    });
  if (order.isNotEmpty) {
    out
      ..add('')
      ..add('${labels.recent}:');
    for (final e in order.take(statementMaxLines).map((i) => ledger[i])) {
      final ref = e.displayNo == null ? '' : ' (${e.displayNo})';
      out.add('${dayKey(e.at)}  ${kind(e.kind)}$ref  ${signed(e.amount)}');
    }
  }
  return out.join('\n');
}
