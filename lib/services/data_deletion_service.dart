// Data deletion service stub
class DataDeletionService {
  Future<void> deleteAllUserData(String userId) async {}

  Future<bool> requestDataDeletion(String userId, List<String> dataTypes) async {
    return true;
  }

  Future<bool> deleteData(String userId, List<String> dataTypes) async {
    return true;
  }

  List<String> getDataTypesToDelete() {
    return ['conversations', 'files', 'settings'];
  }

  Map<String, String> getDataRetentionInfo() {
    return {'conversations': '30 days', 'files': '7 days', 'settings': 'Permanent'};
  }
}
