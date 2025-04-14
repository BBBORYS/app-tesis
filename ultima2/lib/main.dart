import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ultima2/providers/theme_provider.dart';
import 'package:ultima2/screens/asistente_screen.dart';
import 'package:ultima2/screens/crearcita_screen.dart';
import 'package:ultima2/screens/gusanito_screen.dart';
import 'package:ultima2/screens/pagosfactura_screen.dart';
import 'package:ultima2/screens/price_management_screen.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/perfil_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase inicializado correctamente');
  } catch (e) {
    print('Error al inicializar Firebase: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(), // Provee el ThemeProvider
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Usar un FutureBuilder para cargar la preferencia del tema antes de construir la UI
    return FutureBuilder(
      future:
          themeProvider.loadThemePreference(), // Cargar la preferencia del tema
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Cargando preferencia del tema...');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          print('Error al cargar la preferencia del tema: ${snapshot.error}');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Text('Error al cargar el tema'),
              ),
            ),
          );
        } else {
          print('Preferencia del tema cargada correctamente');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme, // Usa el tema actual
            home: AuthenticationWrapper(),
            routes: {
              '/login': (context) => LoginScreen(),
              '/register': (context) => RegisterScreen(),
              '/welcome': (context) => WelcomeScreen(userName: 'Usuario'),
              '/appointment': (context) => AppointmentScreen(),
              '/pagosfactura': (context) => PagosFacturaScreen(),
              '/game': (context) => GameScreen(),
              '/perfil': (context) => PerfilScreen(userName: 'Usuario'),
              '/price_management': (context) => PriceManagementScreen(),
              '/asistente': (context) => const AsistenteAnaScreen(),
            },
          );
        }
      },
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Verificando estado de autenticación...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error en authStateChanges: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.hasData && snapshot.data != null) {
          print('Usuario autenticado: ${snapshot.data!.uid}');
          // Usuario está autenticado, obtener su nombre desde Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                print('Cargando datos del usuario...');
                return const Center(child: CircularProgressIndicator());
              }

              if (userSnapshot.hasError) {
                print(
                    'Error al cargar datos del usuario: ${userSnapshot.error}');
                return Center(child: Text('Error: ${userSnapshot.error}'));
              }

              if (userSnapshot.hasData && userSnapshot.data != null) {
                final userName = userSnapshot.data!['name'] as String;
                print('Usuario cargado: $userName');
                return WelcomeScreen(userName: userName);
              }

              // Si no se encuentra el documento del usuario, redirigir al login
              print('Documento del usuario no encontrado');
              return LoginScreen();
            },
          );
        }

        // Usuario no está autenticado
        print('Usuario no autenticado');
        return LoginScreen();
      },
    );
  }
}
