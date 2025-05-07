import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:ultima2/screens/comando.screens.dart';
import '../providers/theme_provider.dart';

class AsistenteAnaScreen extends StatefulWidget {
  const AsistenteAnaScreen({Key? key}) : super(key: key);

  @override
  _AsistenteAnaScreenState createState() => _AsistenteAnaScreenState();
}

class _AsistenteAnaScreenState extends State<AsistenteAnaScreen> with WidgetsBindingObserver {
  bool _isOn = false;
  bool _backgroundServiceEnabled = false;
  PermissionStatus _microphonePermission = PermissionStatus.denied;
  PermissionStatus _backgroundPermission = PermissionStatus.denied;
  PermissionStatus _overlayPermission = PermissionStatus.denied; // Nuevo permiso para overlay
  late SharedPreferences _prefs;

  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastWords = '';
  String _statusMessage = 'Di "Ok Ana" para comenzar';
  
  // Referencia al overlay global
  OverlayEntry? _overlayEntry;
  bool _overlayVisible = false;
  
  // Controlador de comandos
  late CommandHandler _commandHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPreferences();
    _initSpeechServices();
    _checkPermissions();
    _initAlarmManager();
    _commandHandler = CommandHandler(speak: _speak);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mantener el asistente de voz activo cuando la app está en segundo plano
    if (state == AppLifecycleState.paused && _isOn && _backgroundServiceEnabled) {
      _createOverlay();
    } else if (state == AppLifecycleState.resumed && _overlayVisible) {
      _removeOverlay();
    }
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isOn = _prefs.getBool('asistente_activo') ?? false;
      _backgroundServiceEnabled = _prefs.getBool('segundo_plano') ?? false;
    });
  }

  Future<void> _initSpeechServices() async {
    // Crear nuevas instancias para evitar problemas con instancias anteriores
    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    try {
      // Inicializar el reconocimiento de voz
      bool available = await _speech.initialize(
        onStatus: (status) => _updateListeningStatus(status),
        onError: (error) => _handleSpeechError(error),
      );
      
      if (!available) {
        debugPrint('Error: Reconocimiento de voz no disponible en el dispositivo');
        _updateStatus('Error: Reconocimiento de voz no disponible');
        return;
      }

      // Configurar el TTS
      await _tts.setLanguage('es-ES');
      await _tts.setPitch(1.1); // Voz más femenina
      await _tts.setSpeechRate(0.5); // Velocidad natural
      
      // Intentar configurar la voz específica, con respaldo si no está disponible
      try {
        await _tts.setVoice({'name': 'es-es-x-ana-local', 'locale': 'es-ES'});
      } catch (e) {
        debugPrint('Voz específica no disponible: $e');
        // Intentar usar cualquier voz española disponible
        final voices = await _tts.getVoices;
        debugPrint('Voces disponibles: $voices');
        // No hacemos nada más, dejamos que use la voz por defecto del idioma
      }

      _tts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
          if (_isOn) {
            // Pequeña pausa antes de volver a escuchar
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isOn && mounted) _startListening();
            });
          }
        }
      });

      _tts.setErrorHandler((error) {
        debugPrint('Error TTS: $error');
        if (mounted) {
          setState(() => _isSpeaking = false);
          if (_isOn) _startListening();  // Intentar seguir escuchando a pesar del error
        }
      });

      // Iniciar escucha si está activado
      if (_isOn && mounted) {
        // Pequeña pausa para asegurarse de que todo está inicializado correctamente
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isOn && mounted) _startListening();
        });
      }
    } catch (e) {
      debugPrint('Error al inicializar los servicios de voz: $e');
      _updateStatus('Error al inicializar. Intenta de nuevo.');
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
    final overlayStatus = await Permission.systemAlertWindow.status;

    setState(() {
      _microphonePermission = micStatus;
      _backgroundPermission = backgroundStatus;
      _overlayPermission = overlayStatus;
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
  
  Future<void> _requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    setState(() {
      _overlayPermission = status;
    });

    if (!status.isGranted) {
      _showPermissionDeniedDialog('mostrar sobre otras aplicaciones');
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
    if (!mounted) return;
    
    debugPrint('Error de reconocimiento: $error');
    
    setState(() {
      // Para error_busy, usamos un mensaje más amigable
      if (error.errorMsg == 'error_busy') {
        _statusMessage = 'Servicio de voz ocupado, reiniciando...';
      } else {
        _statusMessage = 'Error de voz: ${error.errorMsg}';
      }
    });
    
    // Para errores permanentes, reinicializar el servicio
    if (error.permanent) {
      debugPrint('Error permanente detectado. Reiniciando servicios de voz...');
      // Detener todo
      _speech.stop();
      
      // Esperar un momento y reiniciar los servicios
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isOn && !_isSpeaking) {
          _initSpeechServices();
        }
      });
    } else {
      // Para errores no permanentes, intentar reanudar la escucha después de una pausa
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isOn && !_isSpeaking) {
          _startListening();
        }
      });
    }
  }

  Future<void> _startListening() async {
    try {
      // Verificar primero si ya está escuchando para evitar error_busy
      if (_speech.isListening) {
        await _speech.stop();
        // Pequeña pausa para asegurarse de que se liberó correctamente
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Verificar si la instancia está disponible
      bool available = await _speech.initialize(
        onStatus: (status) => _updateListeningStatus(status),
        onError: (error) => _handleSpeechError(error),
      );
      
      if (available) {
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
      } else {
        _updateStatus('Reconocimiento de voz no disponible');
        // Reintentar después de un breve retraso
        await Future.delayed(const Duration(seconds: 2));
        if (_isOn) _initSpeechServices();
      }
    } catch (e) {
      debugPrint('Error al iniciar escucha: $e');
      _updateStatus('Error al escuchar: ${e.toString().substring(0, 50)}');
      // Esperar un momento antes de reintentar
      await Future.delayed(const Duration(seconds: 3));
      if (_isOn) _initSpeechServices();
    }
  }

  void _processSpeechResult(result) {
    if (!mounted || !_isOn || _isSpeaking) return;

    final words = result.recognizedWords.toLowerCase();
    setState(() => _lastWords = words);

    if (words.contains('ok ana') || words.contains('ocana')) {
      _responderSaludo();
      // Mostrar el overlay cuando se active con la palabra clave
      if (_backgroundServiceEnabled && _overlayPermission.isGranted) {
        _showFloatingIcon();
      }
    } else if (_overlayVisible) {
      // Procesar el comando si el overlay está visible
      _processCommand(words);
    }
  }
  
  void _processCommand(String command) {
    // Usamos el manejador de comandos para procesar la entrada
    final response = _commandHandler.processCommand(command);
    if (response.isNotEmpty) {
      _speak(response);
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
    await _speak(saludo);
    _updateStatus(saludo);
  }
  
  Future<void> _speak(String text) async {
    try {
      // Detener cualquier síntesis de voz en curso
      if (_isSpeaking) {
        await _tts.stop();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Detener cualquier reconocimiento de voz en curso
      if (_speech.isListening) {
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Iniciar síntesis de voz
      setState(() => _isSpeaking = true);
      _updateStatus(text);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Error al hablar: $e');
      setState(() => _isSpeaking = false);
      _updateStatus('Error al hablar');
      
      // Intentar reanudar la escucha después de un error
      if (_isOn && mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (_isOn && !_isSpeaking && mounted) _startListening();
        });
      }
    }
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
      _removeOverlay();
      _updateStatus('Asistente desactivado');
    }
  }

  Future<void> _toggleBackgroundService() async {
    if (!_backgroundPermission.isGranted) {
      await _requestBackgroundPermission();
      return;
    }
    
    if (!_overlayPermission.isGranted) {
      await _requestOverlayPermission();
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
      _removeOverlay();
    }
  }

  static Future<void> _backgroundTask() async {
    debugPrint('Ejecutando tarea en segundo plano');
    // Aquí puedes agregar lógica para ejecutar en segundo plano
    
    // Obtener instancia de preferencias
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool('asistente_activo') ?? false;
    
    if (isActive) {
      // Aquí podrías reiniciar el servicio de escucha si es necesario
    }
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }
  
  // Métodos para gestionar el icono flotante
  void _showFloatingIcon() {
    if (_overlayEntry != null || !_overlayPermission.isGranted) return;
    
    _createOverlay();
    setState(() => _overlayVisible = true);
    
    // Configurar temporizador para ocultar el icono después de 10 segundos sin uso
    Future.delayed(const Duration(seconds: 10), () {
      if (_overlayVisible && !_isSpeaking) {
        _removeOverlay();
      }
    });
  }
  
  void _createOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        right: 20,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: GestureDetector(
            onTap: () {
              // Al tocar el icono, iniciar la escucha
              if (_isOn && !_isListening && !_isSpeaking) {
                _startListening();
              }
            },
            onPanUpdate: (details) {
              // Implementar para permitir arrastrar el icono
              // Se necesitaría un StatefulBuilder aquí para actualizar la posición
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isListening ? Colors.green : Colors.blue,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    
    // Añadir el overlay a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_overlayEntry != null) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    });
  }
  
  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      setState(() => _overlayVisible = false);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _removeOverlay();
    WidgetsBinding.instance.removeObserver(this);
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
                const SizedBox(height: 10),
                _PermissionStatusIndicator(
                  icon: Icons.layers,
                  status: _overlayPermission,
                  label: 'Overlay',
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