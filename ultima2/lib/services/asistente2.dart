import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Asistente2 {
  static final FlutterTts _tts = FlutterTts();
  static String? _cachedUserName;

  // Configuración básica de voz
  static Future<void> _configurarVoz() async {
    await _tts.setLanguage('es-ES');
    await _tts.setPitch(1.05); // Pitch ligeramente más alto para naturalidad
    await _tts.setSpeechRate(0.48); // Velocidad óptima
  }

  // Obtener nombre del usuario desde Firebase
  static Future<String?> _obtenerNombreUsuario() async {
    try {
      if (_cachedUserName != null) return _cachedUserName;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        _cachedUserName = userDoc.get('name') as String?;
        return _cachedUserName;
      }
      return null;
    } catch (e) {
      print('Error obteniendo nombre de usuario: $e');
      return null;
    }
  }

  // Saludar al usuario con su nombre
  static Future<void> saludarUsuario() async {
    try {
      await _configurarVoz();
      final userName = await _obtenerNombreUsuario();

      final saludo = userName != null
          ? 'Hola $userName, ¿en qué puedo ayudarte hoy?'
          : 'Hola, ¿en qué puedo ayudarte hoy?';

      await _tts.speak(saludo);
    } catch (e) {
      print('Error al saludar: $e');
      // Fallback en caso de error
      await _tts.speak("Hola, ¿en qué puedo ayudarte?");
    }
  }

  // Hablar texto personalizado
  static Future<void> hablar(String texto) async {
    try {
      await _configurarVoz();
      await _tts.speak(texto);
    } catch (e) {
      print('Error al hablar: $e');
    }
  }

  // Detener la reproducción
  static Future<void> detenerVoz() async {
    try {
      await _tts.stop();
    } catch (e) {
      print('Error al detener voz: $e');
    }
  }

  // Limpiar caché (útil para logout)
  static void limpiarCache() {
    _cachedUserName = null;
  }
}
