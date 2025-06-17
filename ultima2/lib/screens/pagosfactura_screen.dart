import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../providers/theme_provider.dart';

class PagosFacturaScreen extends StatefulWidget {
  const PagosFacturaScreen({Key? key}) : super(key: key);

  @override
  _PagosFacturaScreenState createState() => _PagosFacturaScreenState();
}

class _PagosFacturaScreenState extends State<PagosFacturaScreen> {
  final Map<String, int> _countdownValues = {};
  final Map<String, Timer> _countdownTimers = {};

  @override
  void dispose() {
    // Cancelar todos los timers al salir de la pantalla
    _countdownTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

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
                  // Limpiar timers cuando no hay citas
                  _countdownTimers.values.forEach((timer) => timer.cancel());
                  _countdownTimers.clear();
                  _countdownValues.clear();

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
                          final citaId = citas[index].id;
                          final fechaCita =
                              (cita['fecha'] as Timestamp).toDate();
                          final duracion = cita['duracion'] as int;
                          final fechaFinCita =
                              fechaCita.add(Duration(hours: duracion));

                          // Inicializar el contador si no existe y la cita está pendiente
                          if (cita['estado'] == 'pendiente' &&
                              !_countdownValues.containsKey(citaId)) {
                            _countdownValues[citaId] = 100;
                            _startCountdown(citaId, context);
                          }

                          // Verificar si la cita ya expiró (2 horas después de la fecha de fin)
                          final ahora = DateTime.now();
                          final diferenciaExpiracion =
                              ahora.difference(fechaFinCita);
                          if (diferenciaExpiracion.inHours > 2) {
                            _removeCountdown(citaId);
                            FirebaseFirestore.instance
                                .collection('citas')
                                .doc(citaId)
                                .delete();
                            return SizedBox.shrink();
                          }

                          return _CitaCard(
                            cita: cita,
                            citaId: citaId,
                            fechaFinCita: fechaFinCita,
                            countdownValue: _countdownValues[citaId],
                            themeProvider: themeProvider,
                            onPayment: () => _realizarPago(context, citaId),
                            onDelete: () => _eliminarCita(context, citaId),
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

  void _startCountdown(String citaId, BuildContext context) {
    _countdownTimers[citaId] = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_countdownValues.containsKey(citaId)) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownValues[citaId] = _countdownValues[citaId]! - 1;
      });

      if (_countdownValues[citaId]! <= 0) {
        _removeCountdown(citaId);
        FirebaseFirestore.instance.collection('citas').doc(citaId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('La cita ha sido eliminada por falta de pago.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _removeCountdown(String citaId) {
    _countdownTimers[citaId]?.cancel();
    _countdownTimers.remove(citaId);
    _countdownValues.remove(citaId);
  }

  Future<void> _realizarPago(BuildContext context, String citaId) async {
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(citaId)
        .update({'estado': 'pagado'});

    _removeCountdown(citaId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pago realizado con éxito.'),
        backgroundColor: Colors.green,
      ),
    );
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
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                _removeCountdown(citaId);
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

class _CitaCard extends StatelessWidget {
  final Map<String, dynamic> cita;
  final String citaId;
  final DateTime fechaFinCita;
  final int? countdownValue;
  final ThemeProvider themeProvider;
  final VoidCallback onPayment;
  final VoidCallback onDelete;

  const _CitaCard({
    required this.cita,
    required this.citaId,
    required this.fechaFinCita,
    required this.countdownValue,
    required this.themeProvider,
    required this.onPayment,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // No mostrar si el contador llegó a 0 y la cita sigue pendiente
    if (cita['estado'] == 'pendiente' &&
        countdownValue != null &&
        countdownValue! <= 0) {
      return SizedBox.shrink();
    }

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
                  // Temporizador de la cita
                  _CitaTimer(fechaFinCita: fechaFinCita),
                  SizedBox(height: 4),
                  // Temporizador de pago (solo para citas pendientes)
                  if (cita['estado'] == 'pendiente')
                    Text(
                      countdownValue != null
                          ? 'Tiempo para pago: $countdownValue segundos'
                          : 'Tiempo para pago: 100 segundos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: countdownValue != null && countdownValue! > 30
                            ? Colors.blue
                            : Colors.red,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                if (cita['estado'] == 'pendiente')
                  ElevatedButton(
                    onPressed: onPayment,
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
                  onPressed: onDelete,
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
}

class _CitaTimer extends StatefulWidget {
  final DateTime fechaFinCita;

  const _CitaTimer({required this.fechaFinCita, Key? key}) : super(key: key);

  @override
  __CitaTimerState createState() => __CitaTimerState();
}

class __CitaTimerState extends State<_CitaTimer> {
  late Duration _tiempoRestante;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _tiempoRestante = widget.fechaFinCita.difference(DateTime.now());
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _tiempoRestante = widget.fechaFinCita.difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Tiempo restante de la cita: ${_formatDuration(_tiempoRestante)}',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: _tiempoRestante.inSeconds > 0 ? Colors.green : Colors.red,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 0) {
      return 'Finalizada';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$hours h ${minutes.toString().padLeft(2, '0')} m ${seconds.toString().padLeft(2, '0')} s';
  }
}
