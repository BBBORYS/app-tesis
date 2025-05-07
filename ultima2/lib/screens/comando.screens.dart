import 'package:flutter/material.dart';

/// Clase avanzada que maneja los comandos de voz para el asistente Ana
class CommandHandler {
  final Future<void> Function(String text) speak;
  final Map<String, List<String>> _commandSynonyms;
  final Map<String, String> _customResponses;

  CommandHandler({required this.speak}) : 
    _commandSynonyms = _buildSynonyms(),
    _customResponses = _buildCustomResponses();

  /// Procesa los comandos de voz y devuelve una respuesta
  String processCommand(String command) {
    // Limpiar y normalizar el comando
    final cleanedCommand = _cleanCommand(command);
    
    // Verificar comandos prioritarios primero
    if (_matchesCommand(cleanedCommand, 'salir|apagar|detener')) {
      return 'Hasta luego. Puedes decir "Ok Ana" cuando necesites ayuda.';
    }

    // Comandos de emergencia
    if (_matchesCommand(cleanedCommand, 'emergencia|ayuda médica|llamar ambulancia')) {
      return 'Llamando a emergencias. Por favor mantén la calma.';
    }

    // Procesar otros comandos
    for (final entry in _commandSynonyms.entries) {
      if (_matchesCommand(cleanedCommand, entry.key)) {
        return _getResponse(entry.key, entry.value, cleanedCommand);
      }
    }

    // Respuesta por defecto si no se reconoce el comando
    return _getRandomDefaultResponse();
  }

  /// Limpia y normaliza el comando
  String _cleanCommand(String command) {
    return command
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sáéíóúüñ]'), '') // Eliminar signos de puntuación
        .trim();
  }

  /// Verifica si el comando coincide con un patrón
  bool _matchesCommand(String command, String pattern) {
    return RegExp(pattern).hasMatch(command);
  }

  /// Obtiene la respuesta adecuada para el comando
  String _getResponse(String pattern, List<String> keywords, String command) {
    // Respuestas personalizadas tienen prioridad
    for (final key in _customResponses.keys) {
      if (_matchesCommand(command, key)) {
        return _customResponses[key]!;
      }
    }

    // Respuestas basadas en el tipo de comando
    switch (pattern) {
      case 'saludo':
        return _getGreeting();
      case 'hora':
        return _getCurrentTime();
      case 'fecha':
        return _getCurrentDate();
      case 'ayuda':
        return _getHelpResponse();
      case 'agradecimiento':
        return 'De nada. Estoy aquí para ayudarte.';
      default:
        return _getRandomDefaultResponse();
    }
  }

  /// Construye el mapa de sinónimos para los comandos
  static Map<String, List<String>> _buildSynonyms() {
    return {
      'saludo': ['hola', 'buenos días', 'buenas tardes', 'buenas noches', 'oye ana', 'hola ana'],
      'ayuda': ['ayuda', 'qué puedes hacer', 'que puedes hacer', 'para qué sirves', 'funciones'],
      'hora': ['hora', 'qué hora es', 'que hora es', 'dime la hora', 'hora actual'],
      'fecha': ['fecha', 'qué día es', 'que dia es', 'dime la fecha', 'fecha actual'],
      'agradecimiento': ['gracias', 'muchas gracias', 'te lo agradezco'],
      'despedida': ['adiós', 'adios', 'hasta luego', 'chao', 'nos vemos'],
    };
  }

  /// Construye respuestas personalizadas para comandos específicos
  static Map<String, String> _buildCustomResponses() {
    return {
      'cómo estás|qué tal|como estas|que tal': 'Estoy funcionando perfectamente, gracias por preguntar. ¿Y tú?',
      'quién eres|quien eres': 'Soy Ana, tu asistente virtual personal. Estoy aquí para ayudarte.',
      'cuál es tu nombre|cual es tu nombre': 'Me llamo Ana, tu asistente virtual.',
      'qué tiempo hace|que tiempo hace': 'Para saber el clima, necesitaría acceder a tu ubicación.',
      'dime un chiste': '¿Qué le dice un semáforo a otro? No me mires, me estoy cambiando.',
    };
  }

  /// Devuelve un saludo adecuado según la hora del día
  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = 'Ana';

    if (hour < 6) {
      return '¡Buenas madrugadas! Soy $name. ¿No puedes dormir o necesitas ayuda con algo?';
    } else if (hour < 12) {
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
    } else if (hour < 6) {
      return 'Son las $hour:$minuteStr de la madrugada.';
    } else if (hour < 12) {
      return 'Son las $hour:$minuteStr de la mañana.';
    } else if (hour == 12) {
      return 'Son las 12:$minuteStr del mediodía.';
    } else if (hour < 20) {
      final pmHour = hour - 12;
      return 'Son las $pmHour:$minuteStr de la tarde.';
    } else {
      final pmHour = hour - 12;
      return 'Son las $pmHour:$minuteStr de la noche.';
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

  /// Devuelve la respuesta de ayuda
  String _getHelpResponse() {
    return 'Puedo ayudarte con varias cosas. Aquí tienes algunos ejemplos:\n\n'
        '- "¿Qué hora es?" para saber la hora actual\n'
        '- "¿Qué día es hoy?" para conocer la fecha\n'
        '- "Cuéntame un chiste" para alegrarte el día\n'
        '- También puedo responder a saludos y preguntas simples\n\n'
        'Solo dime "Ok Ana" seguido de tu pregunta o comando.';
  }

  /// Devuelve una respuesta por defecto aleatoria
  String _getRandomDefaultResponse() {
    final responses = [
      'No estoy segura de haber entendido. ¿Podrías repetirlo?',
      'Disculpa, no reconozco ese comando. ¿Necesitas ayuda?',
      'Creo que no he entendido bien. Prueba a formularlo de otra manera.',
      'Mi capacidad es limitada, no puedo responder a eso todavía.',
      'Vaya, parece que no sé cómo responder a eso. ¿Quieres que te ayude con algo más?'
    ];
    return responses[DateTime.now().millisecondsSinceEpoch % responses.length];
  }
}