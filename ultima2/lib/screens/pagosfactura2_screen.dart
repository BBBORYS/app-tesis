import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PagosFacturas2Screen extends StatefulWidget {
  final String citaId;
  final Map<String, dynamic> citaData;

  const PagosFacturas2Screen({
    Key? key,
    required this.citaId,
    required this.citaData,
  }) : super(key: key);

  @override
  State<PagosFacturas2Screen> createState() => _PagosFacturas2ScreenState();
}

class _PagosFacturas2ScreenState extends State<PagosFacturas2Screen> {
  final _storage = const FlutterSecureStorage();
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();

  bool _isProcessing = false;
  bool _paymentSuccess = false;
  String _errorMessage = '';

  // Datos del cliente
  String _nombres = '';
  String _apellidos = '';
  String _cedula = '';
  String _email = '';
  String _telefono = '';

  // Datos de la tarjeta
  String _numeroTarjeta = '';
  String _fechaExpiracion = '';
  String _cvv = '';
  bool _saveCard = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _nombres = data['nombres'] ?? '';
          _apellidos = data['apellidos'] ?? '';
          _cedula = data['cedula']?.toString() ?? '';
          _email = user.email ?? '';
          _telefono = data['telefono']?.toString() ?? '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago con Banco Pichincha'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: !_paymentSuccess ? _buildPaymentForm() : _buildSuccessScreen(),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de la Cita',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildDetailRow('Tipo de cita:', widget.citaData['tipo']),
          _buildDetailRow('Fecha:', _formatTimestamp(widget.citaData['fecha'])),
          _buildDetailRow('Duración:', '${widget.citaData['duracion']} horas'),
          _buildDetailRow('Total a pagar:',
              '\$${widget.citaData['precio'].toStringAsFixed(2)}'),
          const Divider(height: 40),
          const Text(
            'Datos Personales',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _nombres,
            decoration: const InputDecoration(labelText: 'Nombres'),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Campo obligatorio' : null,
            onSaved: (value) => _nombres = value ?? '',
          ),
          TextFormField(
            initialValue: _apellidos,
            decoration: const InputDecoration(labelText: 'Apellidos'),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Campo obligatorio' : null,
            onSaved: (value) => _apellidos = value ?? '',
          ),
          TextFormField(
            initialValue: _cedula,
            decoration: const InputDecoration(labelText: 'Cédula'),
            keyboardType: TextInputType.number,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Campo obligatorio' : null,
            onSaved: (value) => _cedula = value ?? '',
          ),
          TextFormField(
            initialValue: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Campo obligatorio' : null,
            onSaved: (value) => _email = value ?? '',
          ),
          TextFormField(
            initialValue: _telefono,
            decoration: const InputDecoration(labelText: 'Teléfono'),
            keyboardType: TextInputType.phone,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Campo obligatorio' : null,
            onSaved: (value) => _telefono = value ?? '',
          ),
          const SizedBox(height: 30),
          const Text(
            'Datos de Pago',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Número de Tarjeta'),
            keyboardType: TextInputType.number,
            validator: (value) =>
                value?.length != 16 ? 'Número inválido' : null,
            onSaved: (value) => _numeroTarjeta = value ?? '',
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'MM/AA'),
                  validator: (value) =>
                      value?.length != 5 ? 'Formato inválido' : null,
                  onSaved: (value) => _fechaExpiracion = value ?? '',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'CVV'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (value) =>
                      (value?.length ?? 0) < 3 || (value?.length ?? 0) > 4
                          ? 'CVV inválido'
                          : null,
                  onSaved: (value) => _cvv = value ?? '',
                ),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: _saveCard,
                onChanged: (value) {
                  setState(() {
                    _saveCard = value ?? false;
                  });
                },
              ),
              const Text('Guardar tarjeta para futuros pagos'),
            ],
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blue,
            ),
            child: _isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    'Pagar \$${widget.citaData['precio'].toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 20),
        const Text(
          '¡Pago Completado Exitosamente!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const Text(
          'Tu cita ha sido confirmada y el estado ha sido actualizado a "pagado".',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Colors.green,
          ),
          child: const Text(
            'Volver a Mis Citas',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      // 1. Validar formato de fecha MM/AA
      if (!_validateExpirationDate(_fechaExpiracion)) {
        throw Exception('Fecha de expiración inválida');
      }

      // 2. Generar datos de transacción
      final transactionId = _uuid.v4();
      final amount = widget.citaData['precio'].toStringAsFixed(2);

      // 3. Crear solicitud de pago a Banco Pichincha
      final response = await _sendPaymentRequest(
        transactionId: transactionId,
        amount: amount,
        customerName: '$_nombres $_apellidos',
        customerEmail: _email,
        customerId: _cedula,
      );

      // 4. Verificar respuesta del banco
      if (response['status'] != 'approved') {
        throw Exception(response['message'] ?? 'Error en el pago');
      }

      // 5. Guardar tarjeta si el usuario lo solicitó
      if (_saveCard) {
        await _saveCardInfo();
      }

      // 6. Actualizar estado en Firestore
      await _updateAppointmentStatus(
          transactionId, response['authorizationCode'] ?? 'N/A');

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

  bool _validateExpirationDate(String date) {
    try {
      final parts = date.split('/');
      if (parts.length != 2) return false;

      final month = int.parse(parts[0]);
      final year = int.parse(parts[1]);

      if (month < 1 || month > 12) return false;

      final now = DateTime.now();
      final currentYear = now.year % 100;
      final currentMonth = now.month;

      if (year < currentYear) return false;
      if (year == currentYear && month < currentMonth) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _sendPaymentRequest({
    required String transactionId,
    required String amount,
    required String customerName,
    required String customerEmail,
    required String customerId,
  }) async {
    // NOTA: En producción, esto debe hacerse desde tu backend
    // Este es solo un ejemplo de cómo sería la estructura

    final url = Uri.parse('https://tu-backend.com/api/pichincha/payment');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'transactionId': transactionId,
        'amount': amount,
        'customer': {
          'name': customerName,
          'email': customerEmail,
          'id': customerId,
        },
        'card': {
          'number': _numeroTarjeta,
          'expiration': _fechaExpiracion,
          'cvv': _cvv,
        },
        'metadata': {
          'cita_id': widget.citaId,
          'user_id': FirebaseAuth.instance.currentUser?.uid,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error en la comunicación con el servidor');
    }

    return json.decode(response.body);
  }

  Future<void> _saveCardInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // En producción, usa tokenización o encriptación fuerte
    final last4 = _numeroTarjeta.substring(_numeroTarjeta.length - 4);

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('tarjetas')
        .add({
      'ultimos4': last4,
      'tipo': _detectCardType(_numeroTarjeta),
      'fechaExpiracion': _fechaExpiracion,
      'fechaGuardado': FieldValue.serverTimestamp(),
    });
  }

  String _detectCardType(String cardNumber) {
    if (cardNumber.startsWith('4')) return 'Visa';
    if (cardNumber.startsWith('5')) return 'Mastercard';
    if (cardNumber.startsWith('34') || cardNumber.startsWith('37'))
      return 'American Express';
    if (cardNumber.startsWith('6')) return 'Discover';
    return 'Otra';
  }

  Future<void> _updateAppointmentStatus(
      String transactionId, String authCode) async {
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget.citaId)
        .update({
      'estado': 'pagado',
      'fechaPago': FieldValue.serverTimestamp(),
      'metodoPago': 'Tarjeta Banco Pichincha',
      'transaccionId': transactionId,
      'codigoAutorizacion': authCode,
      'ultimos4Tarjeta': _numeroTarjeta.substring(_numeroTarjeta.length - 4),
    });
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime date;

      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Fecha inválida';
      }

      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}
