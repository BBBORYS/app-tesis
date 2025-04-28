import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultima2/providers/theme_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _initPreferences();
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

  Future<void> _initAlarmManager() async {
    await AndroidAlarmManager.initialize();
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
        title: Text('Permiso requerido'),
        content: Text(
            'Para que el asistente funcione correctamente, necesitas conceder el permiso de $permission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: Text('Ajustes'),
          ),
        ],
      ),
    );
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
                    : Color.fromARGB(255, 153, 251, 174),
                isDarkMode ? Colors.grey[800]! : Color(0xFF6DD5ED),
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
                  : Color.fromARGB(255, 125, 255, 140),
              isDarkMode ? Colors.grey[800]! : Color(0xFF6DD5ED),
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
                      color: _isOn ? Colors.green : Colors.grey[300]!,
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
                SizedBox(height: 20),
                Text(
                  _isOn ? 'Asistente activado' : 'Asistente desactivado',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                // Botón principal de encendido/apagado
                GestureDetector(
                  onTap: _toggleAsistente,
                  child: Container(
                    width: 120,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: _isOn
                          ? Color.fromARGB(255, 1, 248, 54).withOpacity(0.3)
                          : Colors.grey[400]!.withOpacity(0.3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (!_isOn)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 20),
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
                              padding: EdgeInsets.only(left: 20),
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
                          duration: Duration(milliseconds: 200),
                          alignment: _isOn
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 50,
                            height: 50,
                            margin: EdgeInsets.all(5),
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
                SizedBox(height: 30),
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
                          offset: Offset(0, 3),
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
                          duration: Duration(milliseconds: 200),
                          alignment: _backgroundServiceEnabled
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 50,
                            height: 50,
                            margin: EdgeInsets.all(5),
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
                SizedBox(height: 20),
                // Indicadores de estado de permisos
                _PermissionStatusIndicator(
                  icon: Icons.mic,
                  status: _microphonePermission,
                  label: 'Micrófono',
                ),
                SizedBox(height: 10),
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
        SizedBox(width: 8),
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
