import 'package:flutter/material.dart';

import 'lib/widgets/enhanced_loading_indicator.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: EnhancedLoadingIndicator(
            currentMilestone: "Testing milestone animation...",
            progress: 75.0,
            phase: "testing",
          ),
        ),
      ),
    ),
  ));
}
