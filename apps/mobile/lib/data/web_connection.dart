import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Fallback for browsers where the shared worker cannot load SQLite (some embedded or locked-down browsers
/// block network requests from shared workers). Runs SQLite in the page and stores it in IndexedDB.
/// Only one tab should use it at a time, which is how a tindera uses the app.
QueryExecutor safeWebConnection(String name) => DatabaseConnection.delayed(Future(() async {
      final probe = await WasmDatabase.probe(
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
        databaseName: name,
      );
      final impl = probe.availableStorages.contains(WasmStorageImplementation.unsafeIndexedDb)
          ? WasmStorageImplementation.unsafeIndexedDb
          : WasmStorageImplementation.inMemory;
      return probe.open(impl, name);
    }));
