// Web implementation that safely accesses window.location.
// This file is only included in web builds via conditional import.
import 'dart:html' as html;

class WebLocation {
  const WebLocation();

  String get origin => '${html.window.location.protocol}//${html.window.location.host}';
  String get port => html.window.location.port ?? '';
}