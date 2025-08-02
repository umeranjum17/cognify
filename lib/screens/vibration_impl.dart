import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
// still a mystery doesn't work
Future<void> onSSEParagraphComplete() async {
  await TypingVibrationManager().onParagraphComplete();
}

Future<void> onSSESentenceComplete() async {
  await TypingVibrationManager().onSentenceComplete();
}

// New SSE-specific API
Future<void> onSSETextReceived(String text) async {
  await TypingVibrationManager().onTextReceived(text);
}

Future<void> startVibration() async {
  await TypingVibrationManager().startTypingVibration();
}

Future<void> stopVibration() async {
  await TypingVibrationManager().stopVibration();
}

Future<void> triggerVibration() async {
  await TypingVibrationManager().triggerSimpleVibration();
}

class TypingVibrationManager {
  static final TypingVibrationManager _instance = TypingVibrationManager._internal();
  Timer? _vibrationTimer;
  Timer? _burstTimer;

  bool _isActive = false;
  int _textLength = 0;
  double _typingSpeed = 1.0; // Characters per 100ms
  DateTime _lastCharTime = DateTime.now();
  DateTime _streamStartTime = DateTime.now();
  int _chunkCount = 0; // Track number of chunks received
  int _totalCharsReceived = 0; // Track total characters for intensity calculation
  final Random _random = Random();
  factory TypingVibrationManager() => _instance;
  TypingVibrationManager._internal();

  /// Get current vibration stats for debugging
  Map<String, dynamic> getStats() {
    return {
      'isActive': _isActive,
      'textLength': _textLength,
      'typingSpeed': _typingSpeed,
      'chunkCount': _chunkCount,
      'totalCharsReceived': _totalCharsReceived,
      'hasBurstTimer': _burstTimer != null,
      'streamDuration': DateTime.now().difference(_streamStartTime).inMilliseconds,
    };
  }

  /// Trigger paragraph completion vibration
  Future<void> onParagraphComplete() async {
    if (!_isActive) return;
    
    // Double pulse for paragraph completion (non-blocking)
    unawaited(HapticFeedback.mediumImpact());
    unawaited(Future.delayed(const Duration(milliseconds: 100)).then((_) => HapticFeedback.lightImpact()));
  }

  /// Trigger sentence completion vibration (for periods, question marks, etc.)
  Future<void> onSentenceComplete() async {
    if (!_isActive) return;
    
    // Slightly stronger feedback for sentence completion (non-blocking)
    unawaited(HapticFeedback.selectionClick());
  }

  /// Update with new text chunk - this triggers typing vibrations immediately
  Future<void> onTextReceived(String newChunk) async {
    if (!_isActive) return;

    final newChars = newChunk.length;

    if (newChars > 0) {
      _textLength += newChars; // Accumulate total text length
      _chunkCount++; // Increment chunk counter
      _totalCharsReceived += newChars; // Track total characters

      // Calculate dynamic typing speed based on text flow
      final now = DateTime.now();
      final timeSinceLastChar = now.difference(_lastCharTime).inMilliseconds;
      _lastCharTime = now;

      // Update typing speed (adaptive to actual text flow)
      if (timeSinceLastChar > 0) {
        _typingSpeed = (newChars / timeSinceLastChar) * 100; // chars per 100ms
      }

      // Immediate chunk vibration for responsiveness (non-blocking)
      _triggerImmediateChunkVibration(newChars);

      // Calculate progressive intensity based on streaming progress
      final streamDuration = DateTime.now().difference(_streamStartTime).inSeconds;
      final intensityMultiplier = _calculateIntensityMultiplier(streamDuration);
      final frequencyMultiplier = _calculateFrequencyMultiplier();

      // Trigger enhanced typing vibration burst immediately for new characters (non-blocking)
      unawaited(_triggerEnhancedTypingBurst(newChars, intensityMultiplier, frequencyMultiplier));
    }
  }

  /// Start typing vibration that syncs with incoming text
  Future<void> startTypingVibration() async {
    if (_isActive) return;

    _isActive = true;
    _textLength = 0;
    _lastCharTime = DateTime.now();
    _streamStartTime = DateTime.now(); // Reset stream start time
    _chunkCount = 0; // Reset chunk counter
    _totalCharsReceived = 0; // Reset total characters

    // Initial gentle pulse to indicate streaming started (non-blocking)
    unawaited(HapticFeedback.selectionClick());
  }

  /// Stop all vibration activity
  Future<void> stopVibration() async {
    _isActive = false;
    _vibrationTimer?.cancel();
    _burstTimer?.cancel();
    _vibrationTimer = null;
    _burstTimer = null;

    // Final completion pulse (non-blocking)
    unawaited(HapticFeedback.selectionClick());
  }

  /// Simple trigger for non-typing events
  Future<void> triggerSimpleVibration() async {
    unawaited(HapticFeedback.selectionClick());
  }

  /// Calculate frequency multiplier based on chunk count and text volume
  double _calculateFrequencyMultiplier() {
    // Increase frequency based on chunk count (more chunks = faster typing feel)
    final chunkMultiplier = (_chunkCount / 8.0).clamp(0.0, 2.0); // Max 2.0x from chunks (increased for faster loading)

    // Increase frequency based on total characters (more text = more active feel)
    final textMultiplier = (_totalCharsReceived / 300.0).clamp(0.0, 1.2); // Max 1.2x from text volume (increased)

    // Add a time-based multiplier for escalating intensity during fast loading
    final streamDuration = DateTime.now().difference(_streamStartTime).inSeconds;
    final timeMultiplier = (streamDuration / 15.0).clamp(0.0, 0.8); // Max 0.8x from time

    return 1.0 + chunkMultiplier + textMultiplier + timeMultiplier;
  }

  /// Calculate intensity multiplier based on streaming duration
  double _calculateIntensityMultiplier(int streamDurationSeconds) {
    // Gradually increase intensity over time (1.0x to 2.5x over 30 seconds)
    const maxIntensity = 2.5;
    const rampUpTime = 30; // seconds
    final progress = (streamDurationSeconds / rampUpTime).clamp(0.0, 1.0);
    return 1.0 + (progress * (maxIntensity - 1.0));
  }



  /// Get dynamic typing interval based on current speed
  int _getTypingInterval() {
    // Base interval optimized for faster chunk loading (15-45ms)
    final baseInterval = (35 / _typingSpeed.clamp(0.5, 6.0)).round();

    // Add slight randomness for natural feel
    final variance = (_random.nextDouble() * 8 - 4).round(); // ±4ms

    return (baseInterval + variance).clamp(15, 45);
  }





  /// Enhanced character vibration with intensity scaling
  Future<void> _triggerEnhancedCharacterVibration(int charIndex, int totalChars, double intensityMultiplier) async {
    // Scale vibration intensity based on multiplier
    final shouldUseStrongerVibration = _random.nextDouble() < (intensityMultiplier - 1.0);

    if (charIndex == 0 && totalChars > 1) {
      // First character in burst - stronger with intensity (non-blocking)
      if (shouldUseStrongerVibration) {
        unawaited(HapticFeedback.mediumImpact());
      } else {
        unawaited(HapticFeedback.lightImpact());
      }
    } else if (_random.nextDouble() < (0.1 * intensityMultiplier)) {
      // More frequent "harder" key presses with intensity (non-blocking)
      unawaited(HapticFeedback.selectionClick());
    } else if (_random.nextDouble() < (0.05 * intensityMultiplier)) {
      // More frequent "heavy" keys with intensity (non-blocking)
      unawaited(HapticFeedback.mediumImpact());
    } else {
      // Regular character typing - intensity affects strength (non-blocking)
      if (shouldUseStrongerVibration) {
        unawaited(HapticFeedback.selectionClick());
      } else {
        unawaited(HapticFeedback.lightImpact());
      }
    }

    // Reduced micro-pause with frequency (optimized for fast chunk loading)
    final pauseChance = 0.10 / intensityMultiplier; // Reduced pause frequency
    if (_random.nextDouble() < pauseChance) {
      final pauseDuration = (20 / intensityMultiplier).round().clamp(5, 20); // Shorter pauses
      unawaited(Future.delayed(Duration(milliseconds: pauseDuration)));
    }
  }

  /// Enhanced typing burst with progressive intensity and frequency
  Future<void> _triggerEnhancedTypingBurst(int charCount, double intensityMultiplier, double frequencyMultiplier) async {
    if (!_isActive) return;

    // Cancel any existing burst
    _burstTimer?.cancel();

    // Create realistic typing pattern with enhanced parameters (optimized for fast loading)
    int remainingChars = (charCount * intensityMultiplier).round().clamp(1, 20); // Increased max for faster loading
    int burstIndex = 0;

    // Calculate enhanced typing interval (faster with frequency multiplier, optimized for chunks)
    final baseInterval = _getTypingInterval();
    final enhancedInterval = (baseInterval / frequencyMultiplier).round().clamp(8, 80); // Faster min/max for chunks

    _burstTimer = Timer.periodic(Duration(milliseconds: enhancedInterval), (timer) async {
      if (!_isActive || burstIndex >= remainingChars) {
        timer.cancel();
        return;
      }

      // Enhanced character vibration with intensity multiplier (non-blocking)
      unawaited(_triggerEnhancedCharacterVibration(burstIndex, remainingChars, intensityMultiplier));
      burstIndex++;
    });
  }



  /// Immediate chunk vibration for instant feedback on each chunk
  void _triggerImmediateChunkVibration(int newChars) {
    if (!_isActive) return;

    // Calculate chunk intensity based on current progress
    final streamDuration = DateTime.now().difference(_streamStartTime).inSeconds;
    final progressIntensity = _calculateIntensityMultiplier(streamDuration);
    
    // Vary vibration based on chunk size and progress (non-blocking)
    if (newChars > 10) {
      // Large chunk - stronger vibration
      if (progressIntensity > 1.5) {
        unawaited(HapticFeedback.mediumImpact());
      } else {
        unawaited(HapticFeedback.lightImpact());
      }
    } else if (newChars > 3) {
      // Medium chunk - regular vibration
      unawaited(HapticFeedback.selectionClick());
    } else {
      // Small chunk - light vibration
      unawaited(HapticFeedback.lightImpact());
    }
  }




}