/// Lightweight singleton that mirrors the latest access state for token usage.
class AccessService {
  AccessService._();

  static final AccessService instance = AccessService._();

  bool _hasPremium = false;
  bool _isTester = false;

  bool get hasPremiumAccess => _hasPremium;
  bool get isTester => _isTester;

  void update({required bool hasPremium, required bool isTester}) {
    _hasPremium = hasPremium;
    _isTester = isTester;
  }
}
