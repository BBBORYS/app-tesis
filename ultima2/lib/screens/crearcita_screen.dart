import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({Key? key}) : super(key: key);

  @override
  _AppointmentScreenState createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedTipo;
  double? selectedPrecio;
  int? selectedDuracion;
  bool isSaving = false;
  bool isLoadingTypes = true;
  List<Map<String, dynamic>> tiposCitas = [];

  @override
  void initState() {
    super.initState();
    _loadAppointmentTypes();
  }

  Future<void> _loadAppointmentTypes() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointment_types')
          .orderBy('tipo')
          .get();

      setState(() {
        tiposCitas = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'tipo': data['tipo'] ?? 'Tipo no definido',
            'precio': (data['precio'] ?? 0.0).toDouble(),
            'duracion': (data['duracion'] ?? 1).toInt(),
            'id': doc.id,
          };
        }).toList();
        isLoadingTypes = false;
      });
    } catch (e) {
      setState(() {
        isLoadingTypes = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar tipos de cita: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
        selectedTime = null;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  Future<void> _saveAppointment(BuildContext context) async {
    if (isSaving) return;
    setState(() {
      isSaving = true;
    });

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debes iniciar sesión para guardar una cita.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isSaving = false;
      });
      return;
    }

    if (selectedDate == null ||
        selectedTime == null ||
        selectedTipo == null ||
        selectedPrecio == null ||
        selectedDuracion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, completa todos los campos.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isSaving = false;
      });
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime fullDate = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    if (fullDate.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No puedes seleccionar una fecha y hora en el pasado.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isSaving = false;
      });
      return;
    }

    try {
      final DateTime startTime = fullDate;
      final DateTime endTime =
          startTime.add(Duration(hours: selectedDuracion!));

      final QuerySnapshot existingCitas = await FirebaseFirestore.instance
          .collection('citas')
          .where('fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                  selectedDate!.year, selectedDate!.month, selectedDate!.day)))
          .where('fecha',
              isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                  23,
                  59,
                  59)))
          .get();

      bool hasOverlap = false;
      String errorMessage = '';

      for (var doc in existingCitas.docs) {
        final citaData = doc.data() as Map<String, dynamic>;
        final Timestamp fechaTimestamp = citaData['fecha'] as Timestamp;
        final DateTime citaExistenteFecha = fechaTimestamp.toDate();
        final int duracionExistente = citaData['duracion'] as int;
        final DateTime finCitaExistente =
            citaExistenteFecha.add(Duration(hours: duracionExistente));

        if ((startTime.isBefore(finCitaExistente) &&
                endTime.isAfter(citaExistenteFecha)) ||
            (startTime.isAtSameMomentAs(citaExistenteFecha))) {
          hasOverlap = true;
          final String tipoExistente = citaData['tipo'] as String;
          errorMessage =
              'Ya existe una cita de "$tipoExistente" que se solapa con el horario seleccionado.';
          break;
        }
      }

      if (hasOverlap) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isSaving = false;
        });
        return;
      }

      // ignore: unused_local_variable
      final docRef = await FirebaseFirestore.instance.collection('citas').add({
        'userId': user.uid,
        'fecha': Timestamp.fromDate(fullDate),
        'tipo': selectedTipo,
        'precio': selectedPrecio,
        'duracion': selectedDuracion,
        'estado': 'pendiente',
        'timestamp': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cita de "$selectedTipo" guardada exitosamente.'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        selectedDate = null;
        selectedTime = null;
        selectedTipo = null;
        selectedPrecio = null;
        selectedDuracion = null;
        isSaving = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la cita: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = 600.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Realizar Cita',
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: screenWidth > maxContentWidth
                      ? maxContentWidth * 0.8
                      : screenWidth,
                  height: screenWidth > maxContentWidth
                      ? maxContentWidth * 0.3
                      : screenWidth * 0.4,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/cita.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  width: screenWidth > maxContentWidth
                      ? maxContentWidth
                      : screenWidth,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Programar una Cita',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.currentTheme.brightness ==
                                  Brightness.light
                              ? Colors.black87
                              : Colors.white,
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildDatePicker(context),
                      SizedBox(height: 20),
                      _buildTipoCitaDropdown(context),
                      SizedBox(height: 20),
                      _buildTimePicker(context),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed:
                            isSaving ? null : () => _saveAppointment(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              themeProvider.currentTheme.brightness ==
                                      Brightness.light
                                  ? Color.fromARGB(255, 153, 251, 174)
                                  : Colors.grey[800]!,
                          padding: EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isSaving
                            ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    themeProvider.currentTheme.brightness ==
                                            Brightness.light
                                        ? Colors.black87
                                        : Colors.white),
                              )
                            : Text(
                                'Guardar Cita',
                                style: TextStyle(
                                  fontSize: 18,
                                  color:
                                      themeProvider.currentTheme.brightness ==
                                              Brightness.light
                                          ? Colors.black87
                                          : Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona una fecha:',
          style: TextStyle(
            fontSize: 16,
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black87
                : Colors.white,
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeProvider.currentTheme.brightness == Brightness.light
                  ? Colors.white
                  : Colors.grey[800]!,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color:
                      themeProvider.currentTheme.brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  selectedDate != null
                      ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                      : 'Seleccionar fecha',
                  style: TextStyle(
                    color: themeProvider.currentTheme.brightness ==
                            Brightness.light
                        ? Colors.black87
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipoCitaDropdown(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona el tipo de cita:',
          style: TextStyle(
            fontSize: 16,
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black87
                : Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.white
                : Colors.grey[800]!,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoadingTypes
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : tiposCitas.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No hay tipos de cita disponibles',
                        style: TextStyle(
                          color: themeProvider.currentTheme.brightness ==
                                  Brightness.light
                              ? Colors.black87
                              : Colors.white,
                        ),
                      ),
                    )
                  : DropdownButton<String>(
                      value: selectedTipo,
                      hint: Text(
                        'Seleccionar tipo de cita',
                        style: TextStyle(
                          color: themeProvider.currentTheme.brightness ==
                                  Brightness.light
                              ? Colors.black87
                              : Colors.white,
                        ),
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          final selected = tiposCitas
                              .firstWhere((tipo) => tipo['tipo'] == newValue);
                          setState(() {
                            selectedTipo = newValue;
                            selectedPrecio = selected['precio'];
                            selectedDuracion = selected['duracion'];
                          });
                        }
                      },
                      items: tiposCitas.map<DropdownMenuItem<String>>(
                          (Map<String, dynamic> tipo) {
                        return DropdownMenuItem<String>(
                          value: tipo['tipo'],
                          child: Text(
                            '${tipo['tipo']} - \$${tipo['precio']} (${tipo['duracion']} hora(s))',
                            style: TextStyle(
                              color: themeProvider.currentTheme.brightness ==
                                      Brightness.light
                                  ? Colors.black87
                                  : Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona una hora:',
          style: TextStyle(
            fontSize: 16,
            color: themeProvider.currentTheme.brightness == Brightness.light
                ? Colors.black87
                : Colors.white,
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () => _selectTime(context),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeProvider.currentTheme.brightness == Brightness.light
                  ? Colors.white
                  : Colors.grey[800]!,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color:
                      themeProvider.currentTheme.brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  selectedTime != null
                      ? selectedTime!.format(context)
                      : 'Seleccionar hora',
                  style: TextStyle(
                    color: themeProvider.currentTheme.brightness ==
                            Brightness.light
                        ? Colors.black87
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
