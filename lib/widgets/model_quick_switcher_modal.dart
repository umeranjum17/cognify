import 'package:flutter/material.dart';
import '../models/mode_config.dart';
import '../screens/model_quick_switcher.dart';

/// Shows the Model Quick Switcher as a modal bottom sheet
/// 
/// This is a convenience function that wraps the ModelQuickSwitcher widget
/// in a showModalBottomSheet call with proper styling and configuration.
/// 
/// Usage:
/// ```dart
/// showModelQuickSwitcher(
///   context: context,
///   mode: ChatMode.chat,
///   selectedModel: 'gpt-4',
///   onModelSelected: (modelId) {
///     // Handle model selection
///   },
/// );
/// ```
void showModelQuickSwitcher({
  required BuildContext context,
  required ChatMode mode,
  required String selectedModel,
  required Function(String) onModelSelected,
}) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ModelQuickSwitcher(
      mode: mode,
      selectedModel: selectedModel,
      onModelSelected: onModelSelected,
    ),
  );
} 