import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PagosFacturas2Screen extends StatefulWidget {
  final String citaId;
  final Map<String, dynamic> citaData;

  const PagosFacturas2Screen({
    Key? key,
    required this.citaId,
    required this.citaData,
  }) : super(key: key);

  @override
  _PagosFacturas2ScreenState createState() => _PagosFacturas2ScreenState();
}

class _PagosFacturas2ScreenState extends State<PagosFacturas2Screen> {
  bool _isProcessing = false;
  bool _paymentSuccess = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Procesar Pago'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de la Cita',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildDetailRow('Tipo de cita:', widget.citaData['tipo']),
            _buildDetailRow(
                'Fecha:', _formatTimestamp(widget.citaData['fecha'])),
            _buildDetailRow(
                'Duración:', '${widget.citaData['duracion']} horas'),
            _buildDetailRow(
                'Precio:', '\$${widget.citaData['precio'].toString()}'),
            Divider(height: 40),
            if (!_paymentSuccess) ...[
              Text(
                'Método de Pago',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              _buildPaymentMethodCard('Tarjeta de Crédito', Icons.credit_card),
              SizedBox(height: 15),
              _buildPaymentMethodCard('PayPal', Icons.payment),
              SizedBox(height: 30),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                ),
                child: _isProcessing
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Confirmar Pago',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ] else ...[
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              SizedBox(height: 20),
              Text(
                '¡Pago Completado Exitosamente!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Tu cita ha sido confirmada y el estado ha sido actualizado a "pagado".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
                child: Text(
                  'Volver a Mis Citas',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 10),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(String title, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
            Icon(icon, size: 30),
            SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      // Simular procesamiento de pago (reemplazar con tu lógica real de pago)
      await Future.delayed(Duration(seconds: 2));

      // Actualizar estado en Firestore
      await FirebaseFirestore.instance
          .collection('citas')
          .doc(widget.citaId)
          .update({'estado': 'pagado'});

      setState(() {
        _paymentSuccess = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al procesar el pago: ${e.toString()}';
      });
    } finally {
      if (!_paymentSuccess) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
