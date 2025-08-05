import 'dart:async';
import 'dart:collection';

/// A simple semaphore-based pool for controlling concurrent operations
class ConcurrencyPool {
  final int _maxConcurrency;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();
  int _activeCount = 0;

  ConcurrencyPool(this._maxConcurrency);

  /// Execute a function with concurrency control
  Future<T> withResource<T>(Future<T> Function() operation) async {
    await _acquire();
    try {
      return await operation();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_activeCount < _maxConcurrency) {
      _activeCount++;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  void _release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _activeCount--;
    }
  }

  /// Get current pool statistics
  Map<String, int> get stats => {
    'active': _activeCount,
    'waiting': _waitQueue.length,
    'maxConcurrency': _maxConcurrency,
  };
}