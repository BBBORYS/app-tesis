import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class PagosFactura2Screen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Debes iniciar sesión para ver tus facturas.',
            style: TextStyle(
              color: themeProvider.currentTheme.brightness == Brightness.light
                  ? Colors.black87
                  : Colors.white,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Facturas Pagadas jajaaj',
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.white
                : Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context); // Regresar a la pantalla anterior
          },
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('citas') // Nombre de la colección en Firestore
              .where('userId', isEqualTo: user.uid) // Filtrar por usuario
              .where('estado',
                  isEqualTo: 'pagado') // Filtrar por estado "pagado"
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print(
                  'Error al cargar las citas: ${snapshot.error}'); // Depuración
              return Center(
                child: Text(
                  'Error al cargar las facturas',
                  style: TextStyle(
                    color: themeProvider.currentTheme.brightness ==
                            Brightness.light
                        ? Colors.black87
                        : Colors.white,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              print('No hay citas pagadas'); // Depuración
              return Center(
                child: Text(
                  'No hay facturas pagadas',
                  style: TextStyle(
                    color: themeProvider.currentTheme.brightness ==
                            Brightness.light
                        ? Colors.black87
                        : Colors.white,
                  ),
                ),
              );
            }

            final citas = snapshot.data!.docs;
            print('Citas encontradas: ${citas.length}'); // Depuración

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: citas.length,
              itemBuilder: (context, index) {
                final cita = citas[index].data() as Map<String, dynamic>;
                print('Cita: $cita'); // Depuración
                final fecha = (cita['fecha'] as Timestamp).toDate();
                final tipo = cita['tipo'] as String;
                final precio = cita['precio'] as double;
                final duracion = cita['duracion'] as int;
                final estado = cita['estado'] as String;

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  color:
                      themeProvider.currentTheme.brightness == Brightness.light
                          ? const Color.fromARGB(255, 218, 252, 255)
                          : Colors.grey[800],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cita: $tipo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.currentTheme.brightness ==
                                    Brightness.light
                                ? Colors.black87
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fecha: ${_formatDate(fecha)}',
                          style: TextStyle(
                            color: themeProvider.currentTheme.brightness ==
                                    Brightness.light
                                ? Colors.black87
                                : Colors.white,
                          ),
                        ),
                        Text(
                          'Precio: \$${precio.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: themeProvider.currentTheme.brightness ==
                                    Brightness.light
                                ? Colors.black87
                                : Colors.white,
                          ),
                        ),
                        Text(
                          'Duración: $duracion hora(s)',
                          style: TextStyle(
                            color: themeProvider.currentTheme.brightness ==
                                    Brightness.light
                                ? Colors.black87
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Estado: $estado',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
