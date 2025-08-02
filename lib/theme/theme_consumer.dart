import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ThemeConsumer extends StatelessWidget {
  final Widget Function(BuildContext, ThemeData) builder;
  const ThemeConsumer({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return builder(context, themeProvider.themeData);
  }
}
