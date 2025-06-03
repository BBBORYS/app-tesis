import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';

class ComandoScreen extends StatefulWidget {
  const ComandoScreen({Key? key}) : super(key: key);

  @override
  _ComandoScreenState createState() => _ComandoScreenState();
}

class _ComandoScreenState extends State<ComandoScreen> {
  final List<Map<String, dynamic>> _conversation = [];
  final TextEditingController _textController = TextEditingController();
  bool _isFirstTime = true;
  bool _isLoading = false;
  int? _selectedDate;
  String? _selectedTime;
  int? _selectedTypeIndex;
  List<Map<String, dynamic>> _tiposCitas = [];
  int _currentStep = 0; // 0: inicio, 1: fecha, 2: hora, 3: tipo, 4: confirmación

  @override
  void initState() {
    super.initState();
    _loadAppointmentTypes();
    if (_isFirstTime) {
      _addMessage('Ana', 'Hola soy Ana yo seré tu asistente cuando necesites realizar una cita');
      _addMessage('Ana', 'En que puedo ayudarte');
    }
  }

  Future<void> _loadAppointmentTypes() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointment_types')
          .orderBy('tipo')
          .get();

      setState(() {
        _tiposCitas = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'tipo': data['tipo'] ?? 'Tipo no definido',
            'precio': (data['precio'] ?? 0.0).toDouble(),
            'duracion': (data['duracion'] ?? 1).toInt(),
            'id': doc.id,
          };
        }).toList();
      });
    } catch (e) {
      _addMessage('Ana', 'Error al cargar los tipos de cita. Por favor intenta más tarde.');
    }
  }

  void _addMessage(String sender, String message) {
    setState(() {
      _conversation.add({
        'sender': sender,
        'message': message,
        'timestamp': DateTime.now(),
      });
    });
  }

  void _handleUserMessage(String message) {
    _addMessage('Usuario', message);
    
    setState(() {
      _isLoading = true;
    });

    // Simulamos un pequeño retraso para que parezca que Ana está pensando
    Future.delayed(Duration(milliseconds: 500), () {
      _processUserMessage(message.toLowerCase());
    });
  }

  void _processUserMessage(String message) {
    switch (_currentStep) {
      case 0: // Esperando que el usuario pida crear cita
        if (message.contains('crear') || message.contains('generar') || message.contains('cita')) {
          _currentStep = 1;
          _addMessage('Ana', 'De acuerdo, ya te agendo');
          _addMessage('Ana', 'Para que fecha necesitas? Dime un número');
        } else {
          _addMessage('Ana', 'No entendí. ¿Quieres que te ayude a crear una cita?');
        }
        break;
      
      case 1: // Esperando fecha
        final dateRegex = RegExp(r'(\d{1,2})');
        final match = dateRegex.firstMatch(message);
        if (match != null) {
          _selectedDate = int.tryParse(match.group(1)!);
          if (_selectedDate != null && _selectedDate! >= 1 && _selectedDate! <= 31) {
            _currentStep = 2;
            _addMessage('Ana', 'Esta bien ya tienes la fecha. Ahora dime la hora que puedes ir');
          } else {
            _addMessage('Ana', 'Por favor dime un número de día válido (1-31)');
          }
        } else {
          _addMessage('Ana', 'No entendí la fecha. Por favor dime un número de día (1-31)');
        }
        break;
      
      case 2: // Esperando hora
        final timeRegex = RegExp(r'(\d{1,2})');
        final match = timeRegex.firstMatch(message);
        if (match != null) {
          final hour = int.tryParse(match.group(1)!);
          if (hour != null && hour >= 0 && hour <= 23) {
            _selectedTime = '$hour:00';
            _currentStep = 3;
            _addMessage('Ana', 'Ya está casi lista');
            _addMessage('Ana', 'Ahora dime qué tipo de cita quieres:');
            
            // Mostrar tipos de cita
            if (_tiposCitas.isNotEmpty) {
              String tiposMessage = '';
              for (int i = 0; i < _tiposCitas.length; i++) {
                tiposMessage += '${i + 1}. ${_tiposCitas[i]['tipo']} - \$${_tiposCitas[i]['precio']} (${_tiposCitas[i]['duracion']} hora(s))\n';
              }
              _addMessage('Ana', tiposMessage);
              _addMessage('Ana', 'Cual necesitas? Dime el número');
            } else {
              _addMessage('Ana', 'No hay tipos de cita disponibles. Por favor intenta más tarde.');
              _currentStep = 0;
            }
          } else {
            _addMessage('Ana', 'Por favor dime una hora válida (0-23)');
          }
        } else {
          _addMessage('Ana', 'No entendí la hora. Por favor dime un número de hora (0-23)');
        }
        break;
      
      case 3: // Esperando tipo de cita
        final typeRegex = RegExp(r'(\d+)');
        final match = typeRegex.firstMatch(message);
        if (match != null) {
          final typeIndex = int.tryParse(match.group(1)!)! - 1;
          if (typeIndex >= 0 && typeIndex < _tiposCitas.length) {
            _selectedTypeIndex = typeIndex;
            _currentStep = 4;
            _addMessage('Ana', 'OK listo. Confirma la cita por favor');
          } else {
            _addMessage('Ana', 'Número inválido. Por favor elige uno de la lista');
          }
        } else {
          _addMessage('Ana', 'No entendí. Por favor dime el número de la cita que quieres');
        }
        break;
      
      case 4: // Esperando confirmación
        if (message.contains('confirm') ){
          _saveAppointment();
        } else {
          _addMessage('Ana', 'Por favor confirma la cita diciendo "confirmo"');
        }
        break;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveAppointment() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addMessage('Ana', 'Debes iniciar sesión para guardar una cita');
        return;
      }

      final now = DateTime.now();
      final appointmentDate = DateTime(
        now.year,
        now.month,
        _selectedDate!,
        int.parse(_selectedTime!.split(':')[0]),
      );

      if (appointmentDate.isBefore(now)) {
        _addMessage('Ana', 'No puedes agendar citas en fechas pasadas');
        return;
      }

      final tipoCita = _tiposCitas[_selectedTypeIndex!];
      final endTime = appointmentDate.add(Duration(hours: tipoCita['duracion']));

      // Verificar solapamiento
      final QuerySnapshot existingCitas = await FirebaseFirestore.instance
          .collection('citas')
          .where('fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                  appointmentDate.year, appointmentDate.month, appointmentDate.day)))
          .where('fecha',
              isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
                  appointmentDate.year, appointmentDate.month, appointmentDate.day, 23, 59, 59)))
          .get();

      for (var doc in existingCitas.docs) {
        final citaData = doc.data() as Map<String, dynamic>;
        final fechaTimestamp = citaData['fecha'] as Timestamp;
        final citaExistenteFecha = fechaTimestamp.toDate();
        final duracionExistente = citaData['duracion'] as int;
        final finCitaExistente = citaExistenteFecha.add(Duration(hours: duracionExistente));

        if ((appointmentDate.isBefore(finCitaExistente) &&
                endTime.isAfter(citaExistenteFecha)) ||
            appointmentDate.isAtSameMomentAs(citaExistenteFecha)) {
          _addMessage('Ana', 'Ya existe una cita que se solapa con este horario');
          return;
        }
      }

      await FirebaseFirestore.instance.collection('citas').add({
        'userId': user.uid,
        'fecha': Timestamp.fromDate(appointmentDate),
        'tipo': tipoCita['tipo'],
        'precio': tipoCita['precio'],
        'duracion': tipoCita['duracion'],
        'estado': 'pendiente',
        'timestamp': Timestamp.now(),
      });

      _addMessage('Ana', '¡Cita creada con éxito!');
      _addMessage('Ana', 'Recuerda que tienes 2 horas para realizar el pago');
      
      // Resetear el proceso
      _currentStep = 0;
      _selectedDate = null;
      _selectedTime = null;
      _selectedTypeIndex = null;
    } catch (e) {
      _addMessage('Ana', 'Ocurrió un error al guardar la cita. Por favor intenta de nuevo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = themeProvider.currentTheme.brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Asistente Ana',
          style: TextStyle(
            color: isLightMode ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isLightMode ? Color.fromARGB(255, 153, 251, 174) : Colors.grey[900]!,
                isLightMode ? Color(0xFF6DD5ED) : Colors.grey[800]!,
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
              isLightMode ? Color.fromARGB(255, 125, 255, 140) : Colors.grey[900]!,
              isLightMode ? Color(0xFF6DD5ED) : Colors.grey[800]!,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                reverse: false,
                itemCount: _conversation.length,
                itemBuilder: (context, index) {
                  final message = _conversation[index];
                  return _buildMessageBubble(
                    message['sender'],
                    message['message'],
                    isLightMode,
                  );
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            _buildInputField(isLightMode),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String sender, String message, bool isLightMode) {
    final isAna = sender == 'Ana';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isAna ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isAna
                ? (isLightMode ? Colors.white : Colors.grey[700])
                : (isLightMode ? Color.fromARGB(255, 200, 255, 209) : Colors.green[800]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: isAna
                  ? (isLightMode ? Colors.black87 : Colors.white)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(bool isLightMode) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Escribe tu mensaje...',
                filled: true,
                fillColor: isLightMode ? Colors.white : Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _handleUserMessage(text);
                  _textController.clear();
                }
              },
            ),
          ),
          SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: isLightMode ? Colors.green[400] : Colors.green[700],
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  _handleUserMessage(_textController.text);
                  _textController.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}