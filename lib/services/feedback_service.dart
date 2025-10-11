import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('feedback').withConverter(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );

  Future<void> submit({
    required String message,
    String? userId,
    String? userEmail,
    Map<String, dynamic>? extra,
  }) async {
    final payload = <String, dynamic>{
      'message': message.trim(),
      if (userId != null) 'userId': userId,
      if (userEmail != null && userEmail.isNotEmpty) 'userEmail': userEmail,
      'createdAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    };
    await _collection.add(payload);
  }
}


