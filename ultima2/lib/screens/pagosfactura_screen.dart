import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'pagosfactura2_screen.dart';

class PagosFacturaScreen extends StatelessWidget {
  const PagosFacturaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Debes iniciar sesión para ver tus citas.',
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
          'Citas Realizadas',
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
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PagosFactura2Screen(),
                  ),
                );
              },
              icon: Icon(Icons.receipt_long, size: 24),
              label: Text(
                'Ver Facturas',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    themeProvider.currentTheme.brightness == Brightness.light
                        ? Color.fromARGB(255, 72, 255, 93)
                        : Colors.green[800],
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
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
                  ? Color(0xFF6DD5ED)
                  : Colors.grey[800]!,
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('citas')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar las citas',
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
                  return Center(
                    child: Text(
                      'No hay citas realizadas',
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

                double totalPagar = 0;
                for (var cita in citas) {
                  final data = cita.data() as Map<String, dynamic>;
                  totalPagar += (data['precio'] as num).toDouble();
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.0),
                        itemCount: citas.length,
                        itemBuilder: (context, index) {
                          final cita =
                              citas[index].data() as Map<String, dynamic>;
                          final fechaCita =
                              (cita['fecha'] as Timestamp).toDate();
                          final duracion = cita['duracion'] as int;
                          final fechaFinCita =
                              fechaCita.add(Duration(hours: duracion));

                          final ahora = DateTime.now();
                          final diferencia = ahora.difference(fechaCita);

                          if (diferencia.inHours > 2) {
                            FirebaseFirestore.instance
                                .collection('citas')
                                .doc(citas[index].id)
                                .delete();
                            return SizedBox.shrink();
                          }

                          return _buildCitaCard(
                            cita,
                            themeProvider,
                            fechaFinCita,
                            context,
                            citas[index].id,
                          );
                        },
                      ),
                    ),
                    Divider(
                      color: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? Colors.black54
                          : Colors.white54,
                      thickness: 1,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Total a pagar: \$${totalPagar.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.currentTheme.brightness ==
                                  Brightness.light
                              ? Colors.black87
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCitaCard(
    Map<String, dynamic> cita,
    ThemeProvider themeProvider,
    DateTime fechaFinCita,
    BuildContext context,
    String citaId,
  ) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16.0),
      color: themeProvider.currentTheme.brightness == Brightness.light
          ? const Color.fromARGB(255, 218, 252, 255)
          : Colors.grey[800],
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo de Cita: ${cita['tipo']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fecha y Hora: ${_formatTimestamp(cita['fecha'])}',
                    style: TextStyle(
                      color: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
                  Text(
                    'Duración: ${cita['duracion']} horas',
                    style: TextStyle(
                      color: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
                  Text(
                    'Precio: \$${cita['precio']}',
                    style: TextStyle(
                      color: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
                  Text(
                    'Estado: ${cita['estado']}',
                    style: TextStyle(
                      color: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? Colors.black87
                          : Colors.white,
                      fontWeight: cita['estado'] == 'pagado'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Temporizador 1: Tiempo restante de la cita
                  StreamBuilder(
                    stream: Stream.periodic(Duration(seconds: 1), (i) => i),
                    builder: (context, snapshot) {
                      final ahora = DateTime.now();
                      final tiempoRestante = fechaFinCita.difference(ahora);

                      return Text(
                        'Tiempo restante de la cita: ${_formatDuration(tiempoRestante)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: tiempoRestante.inSeconds > 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 4),
                  // Temporizador 2: Tiempo límite para realizar el pago
                  if (cita['estado'] == 'pendiente')
                    StreamBuilder(
                      stream: Stream.periodic(Duration(seconds: 1), (i) => i),
                      builder: (context, snapshot) {
                        final ahora = DateTime.now();
                        final fechaCreacion =
                            (cita['fecha'] as Timestamp).toDate();
                        final tiempoTranscurrido =
                            ahora.difference(fechaCreacion);
                        final tiempoRestantePago =
                            Duration(hours: 1) - tiempoTranscurrido;

                        if (tiempoRestantePago.inSeconds <= 0) {
                          Future.delayed(Duration.zero, () {
                            FirebaseFirestore.instance
                                .collection('citas')
                                .doc(citaId)
                                .delete()
                                .then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'La cita ha sido eliminada por falta de pago.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            });
                          });

                          return Text(
                            'Tiempo para pago: Expirado',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          );
                        }

                        return Text(
                          'Tiempo para pago: ${_formatDuration(tiempoRestantePago)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tiempoRestantePago.inMinutes > 5
                                ? Colors.blue
                                : Colors.red,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            Column(
              children: [
                if (cita['estado'] == 'pendiente')
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('citas')
                          .doc(citaId)
                          .update({'estado': 'pagado'});

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pago realizado con éxito.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? Color.fromARGB(255, 153, 251, 174)
                          : Colors.grey[800]!,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Realizar Pago',
                      style: TextStyle(
                        color: themeProvider.currentTheme.brightness ==
                                Brightness.light
                            ? Colors.black87
                            : Colors.white,
                      ),
                    ),
                  ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    _eliminarCita(context, citaId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.currentTheme.brightness ==
                            Brightness.light
                        ? Colors.red[400]
                        : Colors.red[800]!,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Eliminar Cita',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 0) {
      return 'Finalizada';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$hours h $minutes m $seconds s';
  }

  void _eliminarCita(BuildContext context, String citaId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar Cita'),
          content: Text('¿Estás seguro de que deseas eliminar esta cita?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('citas')
                    .doc(citaId)
                    .delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cita eliminada correctamente.'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }
}
