import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AsistenteAnaScreen extends StatefulWidget {
  const AsistenteAnaScreen({Key? key}) : super(key: key);

  @override
  _AsistenteAnaScreenState createState() => _AsistenteAnaScreenState();
}

class _AsistenteAnaScreenState extends State<AsistenteAnaScreen>
    with SingleTickerProviderStateMixin {
  bool _isActive = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Manejar la interacción con la notificación
        if (response.payload == 'toggle') {
          _toggleActive();
        }
      },
    );
  }

  Future<void> _showNotification() async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'asistente_ana_channel',
      'Asistente Anaaaa',
      channelDescription: 'Canal para notificaciones del Asistente Dental Ana',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      visibility: NotificationVisibility.public,
      ongoing: true,
      actions: [
        AndroidNotificationAction(
          'toggle_action',
          _isActive ? 'Apagar' : 'Encender',
          showsUserInterface: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      'Asistente Ana',
      _isActive ? 'Asistente activado' : 'Asistente desactivado',
      platformChannelSpecifics,
      payload: 'toggle',
    );
  }

  Future<void> _cancelNotification() async {
    await _notificationsPlugin.cancel(0);
  }

  void _toggleActive() async {
    setState(() {
      _isActive = !_isActive;
    });

    if (_isActive) {
      _animationController.forward();
      await _showNotification();
    } else {
      _animationController.reverse();
      await _cancelNotification();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cancelNotification();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Asistente Ana',
          style: TextStyle(
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeProvider.currentTheme.brightness == Brightness.light
                    ? Color.fromARGB(255, 153, 251, 174)
                    : Colors.grey[900]!,
                themeProvider.currentTheme.brightness == Brightness.light
                    ? Color(0xFF6DD5ED)
                    : Colors.grey[800]!,
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
              themeProvider.currentTheme.brightness == Brightness.light
                  ? Color.fromARGB(255, 125, 255, 140)
                  : Colors.grey[900]!,
              themeProvider.currentTheme.brightness == Brightness.light
                  ? Color(0xFF6DD5ED)
                  : Colors.grey[800]!,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Imagen con animación
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          width: isPortrait
                              ? screenSize.width * 0.5
                              : screenSize.width * 0.3,
                          height: isPortrait
                              ? screenSize.width * 0.5
                              : screenSize.width * 0.3,
                          constraints: BoxConstraints(
                            maxWidth: 300,
                            maxHeight: 300,
                            minWidth: 150,
                            minHeight: 150,
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  _isActive ? Colors.white : Colors.grey[300]!,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                            gradient: _isActive
                                ? RadialGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                    stops: [0.1, 0.9],
                                  )
                                : null,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/ana_avatar.png',
                              fit: BoxFit.cover,
                              frameBuilder: (context, child, frame,
                                  wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) {
                                  return child;
                                }
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: frame != null
                                      ? child
                                      : _buildImagePlaceholder(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildImagePlaceholder(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: isPortrait ? 40 : 20),
                // Botón responsivo
                SizedBox(
                  width: isPortrait
                      ? screenSize.width * 0.7
                      : screenSize.width * 0.4,
                  child: ElevatedButton(
                    onPressed: _toggleActive,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isActive
                          ? Color.fromARGB(255, 87, 255, 124)
                          : const Color.fromARGB(255, 81, 81, 81),
                      padding: EdgeInsets.symmetric(
                        horizontal: isPortrait ? 50 : 30,
                        vertical: isPortrait ? 20 : 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                    ),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: Text(
                        _isActive ? 'ENCENDIDO' : 'APAGADO',
                        key: ValueKey<bool>(_isActive),
                        style: TextStyle(
                          fontSize: isPortrait ? 24 : 18,
                          color: _isActive ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.person,
          size: 60,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
