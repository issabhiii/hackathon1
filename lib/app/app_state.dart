import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  String? _displayName; // null => logged out

  bool get isDarkMode => _isDarkMode;
  bool get isLoggedIn => _displayName != null;
  String get displayName => _displayName ?? 'User';

  void setThemeMode(bool dark) {
    _isDarkMode = dark;
    notifyListeners();
  }

  void setDisplayName(String? name) {
    _displayName = name;
    notifyListeners();
  }

  void setLoggedOut() {
    _displayName = null;
    notifyListeners();
  }
}
