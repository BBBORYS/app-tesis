import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class PriceManagementScreen extends StatefulWidget {
  const PriceManagementScreen({Key? key}) : super(key: key);

  @override
  _PriceManagementScreenState createState() => _PriceManagementScreenState();
}

class _PriceManagementScreenState extends State<PriceManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointmentTypes = [];
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _tipoController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _loadAppointmentTypes();
  }

  Future<void> _loadAppointmentTypes() async {
    try {
      final querySnapshot = await _firestore
          .collection('appointment_types')
          .orderBy('tipo')
          .get();

      setState(() {
        _appointmentTypes = querySnapshot.docs.map((doc) {
          final duration = doc['duracion'] as double;
          return {
            'id': doc.id,
            'tipo': doc['tipo'],
            'precio': doc['precio'],
            'duracion': duration,
            'duracion_formatted': _formatDuration(duration),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar tipos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(double hours) {
    final int totalMinutes = (hours * 60).round();
    final int hrs = totalMinutes ~/ 60;
    final int mins = totalMinutes % 60;
    return '${hrs}h ${mins}m';
  }

  double _calculateDurationFromInputs() {
    final int hours = int.tryParse(_hoursController.text) ?? 0;
    final int minutes = int.tryParse(_minutesController.text) ?? 0;
    return hours + (minutes / 60);
  }

  Future<void> _saveAppointmentType() async {
    if (!_formKey.currentState!.validate()) return;

    final duration = _calculateDurationFromInputs();
    if (duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La duración debe ser mayor a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para realizar esta acción'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newAppointmentType = {
        'tipo': _tipoController.text,
        'precio': double.parse(_precioController.text),
        'duracion': duration,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_editingId != null) {
        await _firestore
            .collection('appointment_types')
            .doc(_editingId)
            .update(newAppointmentType);
      } else {
        await _firestore
            .collection('appointment_types')
            .add(newAppointmentType);
      }

      _resetForm();
      await _loadAppointmentTypes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_editingId != null ? 'Tipo actualizado' : 'Tipo creado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editAppointmentType(Map<String, dynamic> appointmentType) {
    setState(() {
      _editingId = appointmentType['id'];
      _tipoController.text = appointmentType['tipo'];
      _precioController.text = appointmentType['precio'].toString();

      final double duration = appointmentType['duracion'];
      final int hours = duration.toInt();
      final int minutes = ((duration - hours) * 60).round();

      _hoursController.text = hours.toString();
      _minutesController.text = minutes.toString().padLeft(2, '0');
    });
  }

  Future<void> _deleteAppointmentType(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de eliminar este tipo de cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('appointment_types').doc(id).delete();
      await _loadAppointmentTypes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tipo eliminado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _tipoController.clear();
    _precioController.clear();
    _hoursController.clear();
    _minutesController.clear();
    _editingId = null;
  }

  @override
  void dispose() {
    _tipoController.dispose();
    _precioController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode =
        themeProvider.currentTheme.brightness == Brightness.dark;
    final Color primaryColor =
        isDarkMode ? Colors.blueGrey[800]! : Color.fromARGB(255, 125, 255, 140);
    final Color secondaryColor =
        isDarkMode ? Colors.blueGrey[700]! : Color.fromARGB(255, 109, 213, 237);
    final Color cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color inputColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;
    final Color borderColor =
        isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Administración de Precios',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, secondaryColor],
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        actions: [
          if (_editingId != null)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: _resetForm,
              tooltip: 'Cancelar edición',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDarkMode
                  ? Colors.grey[900]!
                  : Color.fromARGB(255, 125, 255, 140), // color del cuerpo
              isDarkMode
                  ? Colors.grey[800]!
                  : Color.fromARGB(255, 109, 213, 237), // color del cuerpo
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _tipoController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Tipo de cita',
                            labelStyle: TextStyle(color: hintColor),
                            filled: true,
                            fillColor: inputColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),

                        // Campo de precio
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Precio',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.blueGrey[700]!
                                          : Color.fromARGB(255, 170, 255, 184),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '\$',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _precioController,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        hintText: '0.00',
                                        hintStyle: TextStyle(color: hintColor),
                                        filled: true,
                                        fillColor: isDarkMode
                                            ? Colors.grey[800]!
                                            : Color.fromARGB(
                                                255, 170, 255, 184),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 14),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (value) {
                                        if (value?.isEmpty ?? true)
                                          return 'Requerido';
                                        if (double.tryParse(value!) == null)
                                          return 'Número inválido';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Campo de duración
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Duración',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Horas
                                  Container(
                                    width: 60,
                                    child: TextFormField(
                                      controller: _hoursController,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        hintText: '00',
                                        hintStyle: TextStyle(color: hintColor),
                                        filled: true,
                                        fillColor: isDarkMode
                                            ? Colors.grey[800]!
                                            : Color.fromARGB(
                                                255, 167, 248, 244),
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 14, horizontal: 12),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if ((value?.isEmpty ?? true) &&
                                            (_minutesController.text.isEmpty ||
                                                int.tryParse(_minutesController
                                                        .text) ==
                                                    0)) {
                                          return 'Requerido';
                                        }
                                        if (value!.isNotEmpty &&
                                            int.tryParse(value) == null) {
                                          return 'Inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Text(
                                      ':',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  // Minutos
                                  Container(
                                    width: 60,
                                    child: TextFormField(
                                      controller: _minutesController,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        hintText: '00',
                                        hintStyle: TextStyle(color: hintColor),
                                        filled: true,
                                        fillColor: isDarkMode
                                            ? Colors.grey[800]!
                                            : Color.fromARGB(
                                                255, 167, 248, 244),
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 14, horizontal: 12),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value!.isNotEmpty) {
                                          final minutes = int.tryParse(value);
                                          if (minutes == null)
                                            return 'Inválido';
                                          if (minutes >= 60) return '< 60';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Horas : Minutos',
                                  style: TextStyle(
                                    color: hintColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveAppointmentType,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? Colors.blueGrey[700]!
                                : const Color.fromARGB(255, 38, 176, 52),
                            padding: EdgeInsets.symmetric(
                                horizontal: 40, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _editingId != null ? 'Actualizar' : 'Guardar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _appointmentTypes.isEmpty
                        ? Center(
                            child: Text(
                              'No hay tipos registrados',
                              style: TextStyle(
                                color: hintColor,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _appointmentTypes.length,
                            itemBuilder: (context, index) {
                              final item = _appointmentTypes[index];
                              return Card(
                                color: cardColor,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    item['tipo'],
                                    style: TextStyle(color: textColor),
                                  ),
                                  subtitle: Text(
                                    '\$${item['precio']} - ${item['duracion_formatted']}',
                                    style: TextStyle(color: hintColor),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit,
                                            color: isDarkMode
                                                ? Colors.blue[200]!
                                                : Colors.blue),
                                        onPressed: () =>
                                            _editAppointmentType(item),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: isDarkMode
                                                ? Colors.red[300]!
                                                : Colors.red),
                                        onPressed: () =>
                                            _deleteAppointmentType(item['id']),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
