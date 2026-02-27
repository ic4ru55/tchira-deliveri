import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// THEME PROVIDER — Gère le mode sombre globalement
// Usage : context.read<ThemeProvider>().basculer()
//         context.watch<ThemeProvider>().estSombre
// ═══════════════════════════════════════════════════════════════════════════════

class ThemeProvider extends ChangeNotifier {
  bool _estSombre = false;

  bool get estSombre => _estSombre;
  ThemeMode get themeMode => _estSombre ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    _estSombre = prefs.getBool('pref_mode_sombre') ?? false;
    notifyListeners();
  }

  Future<void> basculer(bool valeur) async {
    _estSombre = valeur;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_mode_sombre', valeur);
    notifyListeners();
  }
}