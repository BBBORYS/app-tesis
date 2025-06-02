import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/theme_provider.dart';

class AsistenteAnaScreen extends StatefulWidget {
  const AsistenteAnaScreen({Key? key}) : super(key: key);

  @override
  _AsistenteAnaScreenState createState() => _AsistenteAnaScreenState();
}

class _AsistenteAnaScreenState extends State<AsistenteAnaScreen> {
  bool _isOn = false;
  PermissionStatus _microphonePermission = PermissionStatus.denied;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings initializationSettingsAndroid = 
      AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final InitializationSettings initializationSettings = 
      InitializationSettings(android: initializationSettingsAndroid);
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'asistente_channel',
        'Asistente Ana',
        channelDescription: 'Canal para el asistente Ana',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        largeIcon: DrawableResourceAndroidBitmap('ana_avatar'),
        styleInformation: BigPictureStyleInformation(
          DrawableResourceAndroidBitmap('ana_avatar'),
          hideExpandedLargeIcon: false,
        ),
        actions: [
          AndroidNotificationAction(
            'listen_action',
            'Escúchame',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'stop_action',
            'Detener',
            showsUserInterface: true,
          ),
        ],
      );
    
    const NotificationDetails platformChannelSpecifics = 
      NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      0,
      'Asistente Ana',
      _isOn ? 'Escuchando...' : 'En espera',
      platformChannelSpecifics,
    );
  }

  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    
    if (mounted) {
      setState(() {
        _microphonePermission = micStatus;
      });
    }
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    
    if (mounted) {
      setState(() {
        _microphonePermission = status;
      });
    }

    if (!status.isGranted) {
      _showPermissionDeniedDialog('micrófono');
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

  Future<void> _toggleAsistente() async {
    if (!_microphonePermission.isGranted) {
      await _requestMicrophonePermission();
      return;
    }

    setState(() {
      _isOn = !_isOn;
    });

    await _showNotification();
  }

  Future<void> _handleNotificationAction(String action) async {
    if (action == 'listen_action' && !_isOn) {
      await _toggleAsistente();
    } else if (action == 'stop_action' && _isOn) {
      await _toggleAsistente();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentTheme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    // Configurar el manejador de notificaciones
flutterLocalNotificationsPlugin.initialize(
  const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ),
  onDidReceiveNotificationResponse: (payload) async {
    if (payload != null) {
      _handleNotificationAction(payload as String);
    }
  },
);

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
                      color: _isOn ? Colors.blueAccent : Colors.grey[300]!,
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
                  _isOn ? 'Asistente activado' : 'Asistente desactivado',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
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
                _PermissionStatusIndicator(
                  icon: Icons.mic,
                  status: _microphonePermission,
                  label: 'Micrófono',
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