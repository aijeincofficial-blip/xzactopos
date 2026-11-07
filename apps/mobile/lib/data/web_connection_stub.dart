import 'package:drift/drift.dart';

/// Native platforms never need the browser fallback.
QueryExecutor safeWebConnection(String name) =>
    throw UnsupportedError('safeWebConnection is only available on the web');
