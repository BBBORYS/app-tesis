import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = lightTheme;
  bool _isDarkMode = false;

  ThemeData get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference(); // Cargar la preferencia del tema al inicio
  }

  // Cargar la preferencia del tema desde SharedPreferences
  Future<void> _loadThemePreference() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool savedDarkMode = prefs.getBool('isDarkMode') ?? false;

      // Solo actualiza el tema si el valor ha cambiado
      if (savedDarkMode != _isDarkMode) {
        _isDarkMode = savedDarkMode;
        _currentTheme = _isDarkMode ? darkTheme : lightTheme;
        notifyListeners();
      }

      print('Preferencia del tema cargada: $_isDarkMode');
    } catch (e) {
      print('Error al cargar la preferencia del tema: $e');
    }
  }

  // Cambiar el tema y guardar la preferencia
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    _currentTheme = _isDarkMode ? darkTheme : lightTheme;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      print('Preferencia del tema guardada: $_isDarkMode');
    } catch (e) {
      print('Error al guardar la preferencia del tema: $e');
    }
  }

  loadThemePreference() {}
}

// Definición del tema claro
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.blue,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: AppBarTheme(
    color: Colors.blue,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
);

// Definición del tema oscuro
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Colors.blueGrey,
  scaffoldBackgroundColor: Colors.grey[900],
  appBarTheme: AppBarTheme(
    color: Colors.blueGrey,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
);
