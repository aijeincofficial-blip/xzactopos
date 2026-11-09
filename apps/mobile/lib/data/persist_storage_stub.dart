/// Not a browser: the phone's app storage is not evicted like browser storage.
Future<bool> requestPersistentStorage() async => true;
