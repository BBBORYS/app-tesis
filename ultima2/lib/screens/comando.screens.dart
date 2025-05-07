// ignore: unused_import
import 'package:flutter/material.dart';

/// Clase que maneja los comandos de voz para el asistente Ana
class CommandHandler {
  // Función para hablar las respuestas
  final Future<void> Function(String text) speak;

  // Constructor
  CommandHandler({required this.speak});

  /// Procesa los comandos de voz y devuelve una respuesta
  String processCommand(String command) {
    // Convertir a minúsculas para facilitar la comparación
    final commandLower = command.toLowerCase();

    // Comandos de saludo
    if (_containsAny(commandLower,
        ['hola', 'buenos días', 'buenas tardes', 'buenas noches'])) {
      return _getGreeting();
    }

    // Comando de ayuda
    if (_containsAny(
        commandLower, ['ayuda', 'qué puedes hacer', 'que puedes hacer'])) {
      return 'Puedo responder a saludos y preguntas simples. '
          'Di "Hola Ana" para saludarme o pregúntame "¿Qué hora es?" para saber la hora actual.';
    }

    // Comando para saber la hora
    if (_containsAny(commandLower, ['hora', 'qué hora es', 'que hora es'])) {
      return _getCurrentTime();
    }

    // Comando para el día actual
    if (_containsAny(commandLower, ['qué día es', 'que dia es', 'fecha'])) {
      return _getCurrentDate();
    }

    // Gracias o despedida
    if (_containsAny(
        commandLower, ['gracias', 'adiós', 'adios', 'hasta luego', 'chao'])) {
      return 'Ha sido un placer ayudarte. Estaré aquí cuando me necesites.';
    }

    // Si no se reconoce ningún comando
    return 'No he entendido tu comando. Puedes decir "ayuda" para saber qué puedo hacer.';
  }

  /// Comprueba si alguna de las palabras clave está en el comando
  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  /// Devuelve un saludo adecuado según la hora del día
  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = 'Ana';

    if (hour < 12) {
      return 'Buenos días, soy $name. ¿En qué puedo ayudarte hoy?';
    } else if (hour < 19) {
      return 'Buenas tardes, soy $name. ¿Cómo puedo asistirte?';
    } else {
      return 'Buenas noches, soy $name. Estoy aquí para ayudarte.';
    }
  }

  /// Devuelve la hora actual en formato amigable
  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;

    String minuteStr = minute < 10 ? '0$minute' : '$minute';

    if (hour == 0) {
      return 'Son las 12:$minuteStr de la medianoche.';
    } else if (hour < 12) {
      return 'Son las $hour:$minuteStr de la mañana.';
    } else if (hour == 12) {
      return 'Son las 12:$minuteStr del mediodía.';
    } else {
      final pmHour = hour - 12;
      return 'Son las $pmHour:$minuteStr de la tarde.';
    }
  }

  /// Devuelve la fecha actual en formato amigable
  String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo'
    ];
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];

    final weekday = weekdays[now.weekday - 1];
    final day = now.day;
    final month = months[now.month - 1];
    final year = now.year;

    return 'Hoy es $weekday $day de $month de $year.';
  }
}
