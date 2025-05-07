import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../providers/theme_provider.dart';

class AsistenteAnaScreen extends StatefulWidget {
  const AsistenteAnaScreen({Key? key}) : super(key: key);

  @override
  _AsistenteAnaScreenState createState() => _AsistenteAnaScreenState();
}

class _AsistenteAnaScreenState extends State<AsistenteAnaScreen> {
  bool _isOn = false;
  bool _backgroundServiceEnabled = false;
  PermissionStatus _microphonePermission = PermissionStatus.denied;
  PermissionStatus _backgroundPermission = PermissionStatus.denied;
  late SharedPreferences _prefs;

  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastWords = '';
  String _statusMessage = 'Di "Ok Ana" para comenzar';

  @override
  void initState() {
    super.initState();
    _initPreferences();
    _initSpeechServices();
    _checkPermissions();
    _initAlarmManager();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isOn = _prefs.getBool('asistente_activo') ?? false;
      _backgroundServiceEnabled = _prefs.getBool('segundo_plano') ?? false;
    });
  }

  Future<void> _initSpeechServices() async {
    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    await _speech.initialize(
      onStatus: (status) => _updateListeningStatus(status),
      onError: (error) => _handleSpeechError(error),
    );

    await _tts.setLanguage('es-ES');
    await _tts.setPitch(1.1); // Voz más femenina
    await _tts.setSpeechRate(0.5); // Velocidad natural
    await _tts.setVoice({'name': 'es-es-x-ana-local', 'locale': 'es-ES'});

    _tts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
      if (_isOn) _startListening();
    });

    if (_isOn) {
      _startListening();
    }
  }

  Future<void> _initAlarmManager() async {
    await AndroidAlarmManager.initialize();
    if (_backgroundServiceEnabled) {
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        1,
        _backgroundTask,
        exact: true,
        wakeup: true,
      );
    }
  }

  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    final backgroundStatus = await Permission.ignoreBatteryOptimizations.status;

    setState(() {
      _microphonePermission = micStatus;
      _backgroundPermission = backgroundStatus;
    });
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _microphonePermission = status;
    });

    if (!status.isGranted) {
      _showPermissionDeniedDialog('micrófono');
    } else if (_isOn) {
      _startListening();
    }
  }

  Future<void> _requestBackgroundPermission() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() {
      _backgroundPermission = status;
    });

    if (!status.isGranted) {
      _showPermissionDeniedDialog('ejecución en segundo plano');
    }
  }

  void _showPermissionDeniedDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso requerido'),
        content: Text(
            'Para que el asistente funcione correctamente, necesitas conceder el permiso de $permission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Ajustes'),
          ),
        ],
      ),
    );
  }

  void _updateListeningStatus(String status) {
    setState(() {
      _isListening = status == 'listening';
      if (status == 'done' && _isOn && !_isSpeaking) {
        _startListening();
      }
    });
  }

  void _handleSpeechError(error) {
    setState(() {
      _statusMessage = 'Error de voz: $error';
    });
    if (_isOn && !_isSpeaking) {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    try {
      await _speech.listen(
        onResult: (result) => _processSpeechResult(result),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: 'es_ES',
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() => _isListening = level > 0);
        },
      );
      _updateStatus('Escuchando...');
    } catch (e) {
      _updateStatus('Error al escuchar');
    }
  }

  void _processSpeechResult(result) {
    if (!mounted || !_isOn || _isSpeaking) return;

    setState(() => _lastWords = result.recognizedWords.toLowerCase());

    if (_lastWords.contains('ok ana') || _lastWords.contains('ocana')) {
      _responderSaludo();
    }
  }

  Future<void> _responderSaludo() async {
    if (!_isOn || _isSpeaking) return;

    final now = DateTime.now();
    String saludo;

    if (now.hour < 12) {
      saludo = 'Buenos días, soy Ana. ¿En qué puedo ayudarte hoy?';
    } else if (now.hour < 19) {
      saludo = 'Buenas tardes, soy Ana. ¿Qué necesitas?';
    } else {
      saludo = 'Buenas noches, soy Ana. ¿Cómo puedo ayudarte?';
    }

    await _speech.stop();
    await _tts.speak(saludo);
    _updateStatus(saludo);
  }

  Future<void> _toggleAsistente() async {
    if (!_microphonePermission.isGranted) {
      await _requestMicrophonePermission();
      return;
    }

    setState(() {
      _isOn = !_isOn;
    });

    await _prefs.setBool('asistente_activo', _isOn);

    if (_isOn) {
      _startListening();
      _updateStatus('Di "Ok Ana" para comenzar');
    } else {
      await _speech.stop();
      _updateStatus('Asistente desactivado');
    }
  }

  Future<void> _toggleBackgroundService() async {
    if (!_backgroundPermission.isGranted) {
      await _requestBackgroundPermission();
      return;
    }

    setState(() {
      _backgroundServiceEnabled = !_backgroundServiceEnabled;
    });

    await _prefs.setBool('segundo_plano', _backgroundServiceEnabled);

    if (_backgroundServiceEnabled) {
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        1,
        _backgroundTask,
        exact: true,
        wakeup: true,
      );
    } else {
      await AndroidAlarmManager.cancel(1);
    }
  }

  static Future<void> _backgroundTask() async {
    debugPrint('Ejecutando tarea en segundo plano');
    // Aquí puedes agregar lógica para ejecutar en segundo plano
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentTheme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Asistente Ana',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDarkMode
                    ? Colors.grey[900]!
                    : const Color.fromARGB(255, 153, 251, 174),
                isDarkMode ? Colors.grey[800]! : const Color(0xFF6DD5ED),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDarkMode
                  ? Colors.grey[900]!
                  : const Color.fromARGB(255, 125, 255, 140),
              isDarkMode ? Colors.grey[800]! : const Color(0xFF6DD5ED),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: screenSize.width * 0.6,
                  height: screenSize.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isOn
                          ? (_isListening
                              ? Colors.green
                              : _isSpeaking
                                  ? Colors.blue
                                  : Colors.blueAccent)
                          : Colors.grey[300]!,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/ana_avatar.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.mic_none,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                if (_lastWords.isNotEmpty)
                  Text(
                    '"$_lastWords"',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 40),
                // Botón principal de encendido/apagado
                GestureDetector(
                  onTap: _toggleAsistente,
                  child: Container(
                    width: 120,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: _isOn
                          ? const Color.fromARGB(255, 1, 248, 54)
                              .withOpacity(0.3)
                          : Colors.grey[400]!.withOpacity(0.3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (!_isOn)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Text(
                                'OFF',
                                style: TextStyle(
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        if (_isOn)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Text(
                                'ON',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: _isOn
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color.fromARGB(255, 87, 220, 247),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Botón para trabajo en segundo plano
                GestureDetector(
                  onTap: _toggleBackgroundService,
                  child: Container(
                    width: 200,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: _backgroundServiceEnabled
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.grey[600]!.withOpacity(0.3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            _backgroundServiceEnabled
                                ? 'Segundo plano: ON'
                                : 'Segundo plano: OFF',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: _backgroundServiceEnabled
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: Icon(
                              _backgroundServiceEnabled
                                  ? Icons.check
                                  : Icons.close,
                              color: _backgroundServiceEnabled
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Indicadores de estado de permisos
                _PermissionStatusIndicator(
                  icon: Icons.mic,
                  status: _microphonePermission,
                  label: 'Micrófono',
                ),
                const SizedBox(height: 10),
                _PermissionStatusIndicator(
                  icon: Icons.battery_charging_full,
                  status: _backgroundPermission,
                  label: 'Segundo plano',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionStatusIndicator extends StatelessWidget {
  final IconData icon;
  final PermissionStatus status;
  final String label;

  const _PermissionStatusIndicator({
    required this.icon,
    required this.status,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = status.isGranted
        ? Colors.green
        : status.isDenied
            ? Colors.orange
            : Colors.red;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: isDarkMode ? Colors.white70 : Colors.black54),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        Text(
          status.isGranted
              ? 'Concedido'
              : status.isDenied
                  ? 'Denegado'
                  : 'No concedido',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
