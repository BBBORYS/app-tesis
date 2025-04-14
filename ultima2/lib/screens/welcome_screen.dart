import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ultima2/providers/theme_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

// ignore: must_be_immutable
class WelcomeScreen extends StatelessWidget {
  final String userName;

  WelcomeScreen({Key? key, required this.userName}) : super(key: key);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Variable para almacenar la última URL descargada
  // ignore: unused_field
  String _lastDownloadedUrl = '';

  // Variable para controlar la descarga
  CancelToken? _downloadCancelToken;

  // Variable para evitar múltiples verificaciones de actualización
  bool _isCheckingForUpdate = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bienvenido, $userName',
          style: TextStyle(
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
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
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuSelection(value, context),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Perfil',
                child: Text(
                  'Datos del perfil',
                  style: TextStyle(
                    color:
                        themeProvider.currentTheme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'Actualizar',
                child: Text(
                  'Verificar actualización',
                  style: TextStyle(
                    color:
                        themeProvider.currentTheme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'Cerrar Sesión',
                child: Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    color:
                        themeProvider.currentTheme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? const Color.fromARGB(255, 194, 252, 255)
                : Colors.grey[800]!,
            elevation: 8,
          ),
        ],
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
                  ? Color.fromARGB(255, 109, 213, 237)
                  : Colors.grey[800]!,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Ajustar el número de columnas según el ancho
              int crossAxisCount = 2; // Por defecto 2 columnas
              if (constraints.maxWidth > 600) crossAxisCount = 3;
              if (constraints.maxWidth > 900) crossAxisCount = 4;
              if (constraints.maxWidth > 1200) crossAxisCount = 5;

              // Ajustar el childAspectRatio basado en el tamaño de la pantalla
              double childAspectRatio = 0.8;
              if (constraints.maxWidth > 900) childAspectRatio = 0.85;
              if (constraints.maxWidth > 1200) childAspectRatio = 0.9;

              return Center(
                child: Container(
                  // Limitar el ancho máximo en pantallas grandes
                  constraints: BoxConstraints(
                    maxWidth: 1400,
                  ),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: _buttonData.length,
                    itemBuilder: (context, index) {
                      final data = _buttonData[index];
                      return _buildImageButton(
                        context,
                        imagePath: data['imagePath']!,
                        color: data['color']!,
                        text: data['text']!,
                        onTap: () =>
                            Navigator.pushNamed(context, data['route']!),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImageButton(
    BuildContext context, {
    required String imagePath,
    required Color color,
    required String text,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    // Determinar si estamos en una pantalla grande
    final bool isLargeScreen = screenSize.width > 900;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Limitar el tamaño máximo del contenedor en pantallas grandes
        double maxWidth = isLargeScreen ? 300 : double.infinity;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: isLargeScreen ? 350 : double.infinity,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color:
                      themeProvider.currentTheme.brightness == Brightness.light
                          ? Colors.black.withOpacity(0.1)
                          : Colors.white.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.asset(
                      imagePath,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image_not_supported,
                          color: color,
                          size: 50),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? const Color.fromARGB(255, 154, 242, 170)
                          : Colors.grey[800]!,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12)),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: isLargeScreen ? 15 : 14,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.currentTheme.brightness ==
                                Brightness.light
                            ? Colors.black87
                            : Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'Perfil':
        Navigator.pushNamed(context, '/perfil');
        break;
      case 'Actualizar':
        _verificarActualizacion(context);
        break;
      case 'Cerrar Sesión':
        _confirmarCerrarSesion(context);
        break;
    }
  }

  Future<void> _verificarActualizacion(BuildContext context) async {
    if (_isCheckingForUpdate) return;
    _isCheckingForUpdate = true;

    try {
      await inicializarNotificaciones();

      await _mostrarNotificacion(
        titulo: 'Verificando actualización',
        mensaje: 'Buscando nuevas versiones...',
        indeterminado: true,
      );

      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final userEmail = user.email;
      if (userEmail == null) {
        throw Exception('Correo del usuario no disponible');
      }

      // Obtener el enlace de la colección `link/update_url`
      final updateUrlDoc =
          await firestore.collection('link').doc('update_url').get();
      if (!updateUrlDoc.exists) {
        throw Exception(
            'No se encontró el enlace de actualización en Firestore');
      }

      final String updateUrl = updateUrlDoc['url'];

      // Verificar si el correo del usuario ya tiene un enlace en `link/correo`
      final userLinkDoc =
          await firestore.collection('link').doc(userEmail).get();

      if (!userLinkDoc.exists) {
        // Si no existe, copiar el enlace de `update_url` a `link/correo`
        await firestore.collection('link').doc(userEmail).set({
          'url': updateUrl,
          'updatedBy': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Si existe, verificar si el enlace es el mismo
        final String userLinkUrl = userLinkDoc['url'];
        if (userLinkUrl == updateUrl) {
          _isCheckingForUpdate = false;
          _mostrarDialogoActualizacion(
              context, 'Ya tienes la última versión de la aplicación.');
          return;
        } else {
          // Si el enlace es diferente, actualizar el enlace en `link/correo`
          await firestore.collection('link').doc(userEmail).update({
            'url': updateUrl,
            'updatedBy': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      _lastDownloadedUrl = updateUrl;

      final permisosOtorgados = await _verificarYSolicitarPermisos();

      if (!permisosOtorgados) {
        await _mostrarNotificacion(
          titulo: 'Permisos requeridos',
          mensaje:
              'Se necesitan permisos para descargar e instalar la actualización',
          completado: true,
        );

        _mostrarDialogoPermisos(context);
        return;
      }

      final downloadPath = await _obtenerRutaDescarga();
      final apkFilePath = '$downloadPath/app_update.apk';

      await _mostrarNotificacion(
        titulo: 'Descargando actualización',
        mensaje: 'Iniciando descarga...',
        progreso: 0,
        mostrarBotonDetener: true,
      );

      final dio = Dio();
      _downloadCancelToken = CancelToken();

      await dio.download(
        updateUrl,
        apkFilePath,
        cancelToken: _downloadCancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toInt();
            _mostrarNotificacion(
              titulo: 'Descargando actualización',
              mensaje: 'Progreso: $progress%',
              progreso: progress,
              mostrarBotonDetener: true,
            );
          }
        },
        deleteOnError: true,
      );

      await _mostrarNotificacion(
        titulo: 'Descarga completada',
        mensaje: 'Toca para instalar la actualización',
        completado: true,
        payload: 'update_completed|$apkFilePath',
      );

      final result = await OpenFile.open(apkFilePath);

      if (result.type == ResultType.done) {
        _programarEliminarAPK(apkFilePath);
      } else {
        await _mostrarNotificacion(
          titulo: 'Error de instalación',
          mensaje: 'No se pudo iniciar la instalación: ${result.message}',
          completado: true,
        );
      }
    } catch (e) {
      await _mostrarNotificacion(
        titulo: 'Error de actualización',
        mensaje: 'No se pudo completar la actualización',
        completado: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      _isCheckingForUpdate = false;
    }
  }

  Future<void> inicializarNotificaciones() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload?.startsWith('update_completed') == true) {
          final apkPath = response.payload?.split('|').last;
          if (apkPath != null && apkPath.isNotEmpty) {
            OpenFile.open(apkPath);
          }
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'update_channel',
      'Actualizaciones',
      description: 'Canal para notificaciones de actualización',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _mostrarNotificacion({
    required String titulo,
    required String mensaje,
    int progreso = 0,
    bool indeterminado = false,
    bool completado = false,
    String? payload,
    bool mostrarBotonDetener = false,
  }) async {
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'update_channel',
      'Actualizaciones',
      channelDescription: 'Canal para notificaciones de actualización',
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
      showProgress: !completado,
      indeterminate: indeterminado,
      progress: progreso,
      maxProgress: 100,
      channelShowBadge: true,
      icon: '@mipmap/ic_launcher',
      playSound: completado,
      enableVibration: true,
      color: const Color(0xFF6DD5ED),
      actions: mostrarBotonDetener
          ? [
              AndroidNotificationAction(
                'stop_download',
                'Detener',
                cancelNotification: true,
              ),
            ]
          : [],
    );

    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      titulo,
      mensaje,
      notificationDetails,
      payload: payload,
    );
  }

  Future<String> _obtenerRutaDescarga() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    try {
      if (androidInfo.version.sdkInt >= 29) {
        final directory = await getExternalStorageDirectory();
        final downloadDir = Directory('${directory?.path}/Updates');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      } else {
        Directory? directory;

        try {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          final testFile = File('${directory.path}/test.txt');
          await testFile.writeAsString('test');
          await testFile.delete();
        } catch (e) {
          directory = await getExternalStorageDirectory();
          final downloadDir = Directory('${directory?.path}/Updates');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          return downloadDir.path;
        }

        return directory.path;
      }
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      return tempDir.path;
    }
  }

  Future<bool> _verificarYSolicitarPermisos() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    if (androidInfo.version.sdkInt >= 33) {
      final installStatus = await Permission.requestInstallPackages.request();
      if (installStatus.isGranted) {
        return true;
      }
    } else if (androidInfo.version.sdkInt >= 29) {
      final installStatus = await Permission.requestInstallPackages.request();
      final storageStatus = await Permission.storage.request();
      if (installStatus.isGranted && storageStatus.isGranted) {
        return true;
      }
    } else {
      final storageStatus = await Permission.storage.request();
      final installStatus = await Permission.requestInstallPackages.request();
      if (storageStatus.isGranted && installStatus.isGranted) {
        return true;
      }
    }

    return false;
  }

  void _mostrarDialogoActualizacion(BuildContext context, String mensaje) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            themeProvider.currentTheme.brightness == Brightness.light
                ? Color.fromARGB(255, 152, 245, 252)
                : Colors.grey[900]!,
        title: Text(
          'Actualización',
          style: TextStyle(
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black87
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          mensaje,
          style: TextStyle(
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black87
                : Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor:
                  themeProvider.currentTheme.brightness == Brightness.light
                      ? Color.fromARGB(255, 131, 248, 116)
                      : Colors.grey[800]!,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Aceptar',
              style: TextStyle(
                color: themeProvider.currentTheme.brightness == Brightness.light
                    ? Colors.black87
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoPermisos(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            themeProvider.currentTheme.brightness == Brightness.light
                ? Color.fromARGB(255, 152, 245, 252)
                : Colors.grey[900]!,
        title: Text(
          'Permisos necesarios',
          style: TextStyle(
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black87
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Para poder descargar e instalar la actualización, necesitamos permisos de almacenamiento e instalación de aplicaciones.',
          style: TextStyle(
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black87
                : Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor:
                  themeProvider.currentTheme.brightness == Brightness.light
                      ? Color.fromARGB(255, 131, 248, 116)
                      : Colors.grey[800]!,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: themeProvider.currentTheme.brightness == Brightness.light
                    ? Colors.black87
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: TextButton.styleFrom(
              backgroundColor:
                  themeProvider.currentTheme.brightness == Brightness.light
                      ? const Color.fromARGB(255, 69, 160, 252)
                      : Colors.blue[900]!,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Abrir Configuración',
              style: TextStyle(
                color: themeProvider.currentTheme.brightness == Brightness.light
                    ? Colors.black87
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _programarEliminarAPK(String apkFilePath) async {
    await Future.delayed(Duration(minutes: 5));

    try {
      final file = File(apkFilePath);
      if (await file.exists()) {
        await file.delete();
        print('APK descargado eliminado con éxito');
      }
    } catch (e) {
      print('Error al eliminar APK: $e');
    }
  }

  void _confirmarCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);

        return AlertDialog(
          backgroundColor:
              themeProvider.currentTheme.brightness == Brightness.light
                  ? Color.fromARGB(255, 152, 245, 252)
                  : Colors.grey[900]!,
          title: Text(
            'Cerrar Sesión',
            style: TextStyle(
              color: themeProvider.currentTheme.brightness == Brightness.light
                  ? Colors.black87
                  : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas cerrar sesión?',
            style: TextStyle(
              color: themeProvider.currentTheme.brightness == Brightness.light
                  ? Colors.black87
                  : Colors.white,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor:
                    themeProvider.currentTheme.brightness == Brightness.light
                        ? Color.fromARGB(255, 131, 248, 116)
                        : Colors.grey[800]!,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color:
                      themeProvider.currentTheme.brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              },
              style: TextButton.styleFrom(
                backgroundColor:
                    themeProvider.currentTheme.brightness == Brightness.light
                        ? const Color.fromARGB(255, 252, 106, 96)
                        : Colors.red[900]!,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color:
                      themeProvider.currentTheme.brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

final List<Map<String, dynamic>> _buttonData = [
  {
    'imagePath': 'assets/imagen1.png',
    'color': const Color.fromARGB(255, 175, 76, 76),
    'text': 'Realizar citas',
    'route': '/appointment'
  },
  {
    'imagePath': 'assets/imagen2.png',
    'color': const Color.fromARGB(255, 2, 139, 251),
    'text': 'Pagos y Facturas',
    'route': '/pagosfactura'
  },
  {
    'imagePath': 'assets/imagen3.png',
    'color': Colors.orange,
    'text': 'Seguimiento',
    'route': '/screen3'
  },
  {
    'imagePath': 'assets/imagen4.png',
    'color': const Color.fromARGB(255, 6, 255, 35),
    'text': 'Mini Juego',
    'route': '/game'
  },
  {
    'imagePath': 'assets/imagen5.png',
    'color': const Color.fromARGB(255, 72, 75, 255),
    'text': 'administracion de citas',
    'route': '/price_management'
  },
  {
    'imagePath': 'assets/ana_avatar.png', // Asegúrate de tener esta imagen
    'color': const Color.fromARGB(255, 242, 255, 1), // Color morado
    'text': 'Asistente',
    'route': '/asistente'
  }
];
