import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../config/app_config.dart';

class CreditsService {
  CreditsService._();
  static final CreditsService instance = CreditsService._();

  Future<int> fetchBalance() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final token = await user.getIdToken();
    final url = Uri.parse('${AppConfig.backendBaseUrl}/api/credits/balance');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    if (res.statusCode != 200) {
      throw StateError('Failed to fetch balance: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return (data['balance'] as num).toInt();
  }

  Future<int> consume({required int amount, required String reason, required String requestId}) async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final token = await user.getIdToken();
    final url = Uri.parse('${AppConfig.backendBaseUrl}/api/credits/consume');
    final res = await http.post(url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'reason': reason,
          'requestId': requestId,
        }));
    if (res.statusCode == 409) {
      throw StateError('INSUFFICIENT_CREDITS');
    }
    if (res.statusCode != 200) {
      throw StateError('Failed to consume: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return (data['balance'] as num).toInt();
  }
}


