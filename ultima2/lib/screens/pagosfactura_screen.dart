import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:ultima2/screens/pagosfactura2_screen.dart';
import '../providers/theme_provider.dart';

class PagosFacturaScreen extends StatefulWidget {
  const PagosFacturaScreen({Key? key}) : super(key: key);

  @override
  _PagosFacturaScreenState createState() => _PagosFacturaScreenState();
}

class _PagosFacturaScreenState extends State<PagosFacturaScreen> {
  final Map<String, Timer> _paymentTimers = {};
  final Map<String, ValueNotifier<int>> _remainingTimes = {};

  @override
  void dispose() {
    _paymentTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  Future<void> _realizarPago(BuildContext context, String citaId,
      Map<String, dynamic> citaData) async {
    // Detener el temporizador pero no marcar como pagado todavía
    _paymentTimers[citaId]?.cancel();
    _paymentTimers.remove(citaId);
    _remainingTimes.remove(citaId);

    // Redirigir a la pantalla de pago con los datos de la cita
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PagosFacturas2Screen(
          citaId: citaId,
          citaData: citaData,
        ),
      ),
    );
  }

  void _startPaymentTimer(
      String citaId, DateTime fechaCreacion, BuildContext context) {
    final plazoPago = fechaCreacion.add(Duration(minutes: 30));
    final ahora = DateTime.now();
    final diferencia = plazoPago.difference(ahora);

    if (diferencia.inSeconds <= 0) {
      _eliminarCitaPorTiempo(citaId, context);
      return;
    }

    _remainingTimes[citaId] = ValueNotifier(diferencia.inSeconds);

    _paymentTimers[citaId] = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_remainingTimes.containsKey(citaId)) {
        timer.cancel();
        return;
      }

      _remainingTimes[citaId]!.value = _remainingTimes[citaId]!.value - 1;

      if (_remainingTimes[citaId]!.value <= 0) {
        _eliminarCitaPorTiempo(citaId, context);
      }
    });
  }

  void _eliminarCitaPorTiempo(String citaId, BuildContext context) async {
    _paymentTimers[citaId]?.cancel();
    _paymentTimers.remove(citaId);
    _remainingTimes.remove(citaId);

    await FirebaseFirestore.instance.collection('citas').doc(citaId).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cita eliminada por falta de pago.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _obtenerEstadoCita(DateTime fechaCita, DateTime fechaFinCita) {
    final ahora = DateTime.now();

    if (ahora.isBefore(fechaCita)) {
      return 'En espera';
    } else if (ahora.isAfter(fechaCita) && ahora.isBefore(fechaFinCita)) {
      return 'En curso';
    } else {
      return 'Finalizada';
    }
  }

  void _eliminarCita(BuildContext context, String citaId) {
    _paymentTimers[citaId]?.cancel();
    _paymentTimers.remove(citaId);
    _remainingTimes.remove(citaId);

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
                          final fechaCreacion =
                              (cita['fechaCreacion'] as Timestamp).toDate();

                          final estadoCita =
                              _obtenerEstadoCita(fechaCita, fechaFinCita);

                          if (cita['estado'] == 'pendiente' &&
                              !_paymentTimers.containsKey(citaId)) {
                            _startPaymentTimer(citaId, fechaCreacion, context);
                          }

                          return _CitaCard(
                            cita: cita,
                            citaId: citaId,
                            fechaCita: fechaCita,
                            fechaFinCita: fechaFinCita,
                            estadoCita: estadoCita,
                            remainingTime:
                                _remainingTimes[citaId] ?? ValueNotifier(1800),
                            themeProvider: themeProvider,
                            onPayment: () =>
                                _realizarPago(context, citaId, cita),
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
}

class _CitaCard extends StatelessWidget {
  final Map<String, dynamic> cita;
  final String citaId;
  final DateTime fechaCita;
  final DateTime fechaFinCita;
  final String estadoCita;
  final ValueNotifier<int> remainingTime;
  final ThemeProvider themeProvider;
  final VoidCallback onPayment;
  final VoidCallback onDelete;

  const _CitaCard({
    required this.cita,
    required this.citaId,
    required this.fechaCita,
    required this.fechaFinCita,
    required this.estadoCita,
    required this.remainingTime,
    required this.themeProvider,
    required this.onPayment,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16.0),
      color: themeProvider.currentTheme.brightness == Brightness.light
          ? const Color.fromARGB(255, 218, 252, 255)
          : Colors.grey[800],
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
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
                      Text(
                        _obtenerTextoEstado(estadoCita),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _obtenerColorEstado(estadoCita),
                        ),
                      ),
                      if (cita['estado'] == 'pendiente') ...[
                        SizedBox(height: 8),
                        ValueListenableBuilder<int>(
                          valueListenable: remainingTime,
                          builder: (context, value, child) {
                            final mostrarAlerta = value <= 300;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tiempo para pagar: ${_formatDuration(Duration(seconds: value))}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        value > 300 ? Colors.blue : Colors.red,
                                  ),
                                ),
                                if (mostrarAlerta)
                                  Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      '¡Realiza el pago pronto o se eliminará la cita!',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (cita['estado'] == 'pendiente')
                      ElevatedButton(
                        onPressed: onPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              themeProvider.currentTheme.brightness ==
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
                        backgroundColor:
                            themeProvider.currentTheme.brightness ==
                                    Brightness.light
                                ? Colors.red[400]
                                : Colors.red[800]!,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ValueListenableBuilder<int>(
              valueListenable: remainingTime,
              builder: (context, value, child) {
                if (cita['estado'] == 'pendiente' && value <= 300) {
                  return Container(
                    margin: EdgeInsets.only(top: 10),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¡Solo quedan ${_formatDuration(Duration(seconds: value))} para realizar el pago!',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _obtenerTextoEstado(String estado) {
    switch (estado) {
      case 'En espera':
        return 'En espera de la cita';
      case 'En curso':
        return 'En cita';
      case 'Finalizada':
        return 'Cita finalizada';
      default:
        return '';
    }
  }

  Color _obtenerColorEstado(String estado) {
    switch (estado) {
      case 'En espera':
        return Colors.black;
      case 'En curso':
        return Colors.green;
      case 'Finalizada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
