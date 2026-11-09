/// Search key for product names: lower case, accents removed, spaces collapsed,
/// so "PIÑA" and "pina" match. Kept in a column so the database does the matching.
String searchKey(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    b.write(_fold[c] ?? c);
  }
  return b.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Words of a search query, each matched anywhere in the name.
List<String> searchWords(String q) =>
    searchKey(q).split(' ').where((w) => w.isNotEmpty).take(6).toList();

const _fold = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c',
};
