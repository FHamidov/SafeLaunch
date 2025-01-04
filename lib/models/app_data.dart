import 'dart:typed_data';

class AppData {
  final String name;
  final String packageName;
  final Uint8List icon;

  AppData({
    required this.name,
    required this.packageName,
    required this.icon,
  });
} 