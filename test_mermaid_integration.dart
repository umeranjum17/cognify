import 'package:flutter/material.dart';

import 'lib/widgets/mermaid_widget.dart';

/// Test app to verify the new Mermaid image integration
void main() {
  runApp(const MermaidTestApp());
}

class MermaidTestApp extends StatelessWidget {
  const MermaidTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mermaid Integration Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MermaidTestScreen(),
    );
  }
}

class MermaidTestScreen extends StatelessWidget {
  const MermaidTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const testDiagram = '''
graph TD
    A[Start] --> B{Is it working?}
    B -->|Yes| C[Great! 🎉]
    B -->|No| D[Debug 🔧]
    D --> A
    C --> E[Server-side generation ✅]
    E --> F[Image popup ✅]
    F --> G[Consistent UX ✅]
''';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Mermaid Integration Test'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server-side Mermaid Generation Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'This diagram should:\n'
              '• Generate as a PNG image on the server\n'
              '• Display as a regular image (no special container)\n'
              '• Open in a standard image popup when tapped\n'
              '• Support zoom and pan in the popup\n'
              '• Toggle between 0° and 90° rotation\n'
              '• Automatically use theme-appropriate colors',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            
            // Test PNG format with theme-aware backgrounds
            Text(
              'PNG Format (theme-aware backgrounds):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            MermaidWidget(
              mermaidCode: testDiagram,
              format: 'png', // Explicit PNG format
            ),

            SizedBox(height: 24),

            // Test SVG format for comparison
            Text(
              'SVG Format (natural theme support):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            MermaidWidget(
              mermaidCode: testDiagram,
              format: 'svg', // SVG format
            ),
            
            SizedBox(height: 24),
            Text(
              'Expected behavior:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              '1. Loading state shows while generating\n'
              '2. Diagram appears with theme-appropriate colors\n'
              '3. Tap opens popup with zoom/pan controls\n'
              '4. Rotation button toggles between 0° and 90°\n'
              '5. Current rotation angle is displayed (0° or 90°)\n'
              '6. Dark mode uses dark theme, light mode uses default\n'
              '7. No special Mermaid-specific styling',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
