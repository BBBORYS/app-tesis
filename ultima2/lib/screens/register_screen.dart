import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String userType = 'usuario';
  String selectedSex = 'Masculino';
  bool isLoading = false;

  List<Color> colors = [
    Colors.blue[900]!,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.amber,
    Colors.cyan,
    Colors.deepOrange,
    Colors.indigo,
  ];
  int currentColorIndex = 0;
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        currentColorIndex = (currentColorIndex + 1) % colors.length;
      });
    });

    // Configuración de la animación del gradiente
    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    _animation =
        Tween<double>(begin: 0, end: 2 * 3.14).animate(_animationController);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    ageController.dispose();
    super.dispose();
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _registerUser(BuildContext context) async {
    if (!mounted) return;

    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();
    final String phone = phoneController.text.trim();
    final String age = ageController.text.trim();

    // Validaciones
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        phone.isEmpty ||
        age.isEmpty) {
      _showErrorMessage('Por favor, completa todos los campos');
      return;
    }

    // Validar que la edad sea un número
    int? ageNum = int.tryParse(age);
    if (ageNum == null || ageNum <= 0 || ageNum > 120) {
      _showErrorMessage('Por favor, ingresa una edad válida');
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      // 1. Crear el usuario en Authentication
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Crear el documento en Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'age': ageNum,
        'sex': selectedSex,
        'userType': userType,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso')),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showErrorMessage('Error en el registro: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 600;

    final double horizontalPadding = screenSize.width * 0.05;
    final double maxWidth = screenSize.width > 600 ? 600 : screenSize.width;
    final double titleFontSize = isSmallScreen ? 28 : 32;
    final double buttonHeight = isSmallScreen ? 45 : 50;

    return Theme(
      data: ThemeData.light(), // Forzar el modo claro
      child: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(255, 125, 255, 140), // Color azul turquesa
                      Color(0xFF6DD5ED), // Color azul claro
                    ],
                    transform: GradientRotation(_animation.value),
                  ),
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: screenSize.height * 0.02,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: screenSize.height * 0.02),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Registro',
                                style: TextStyle(
                                  color: colors[currentColorIndex],
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: screenSize.height * 0.03),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 169, 255, 246)
                                  .withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ResponsiveTextField(
                                  controller: nameController,
                                  hintText: 'Nombre completo',
                                  icon: Icons.person,
                                ),
                                SizedBox(height: screenSize.height * 0.02),
                                ResponsiveTextField(
                                  controller: emailController,
                                  hintText: 'Correo electrónico',
                                  icon: Icons.email,
                                ),
                                SizedBox(height: screenSize.height * 0.02),
                                ResponsiveTextField(
                                  controller: phoneController,
                                  hintText: 'Número de teléfono',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                ),
                                SizedBox(height: screenSize.height * 0.02),
                                ResponsiveTextField(
                                  controller: ageController,
                                  hintText: 'Edad',
                                  icon: Icons.calendar_today,
                                  keyboardType: TextInputType.number,
                                ),
                                SizedBox(height: screenSize.height * 0.02),
                                ResponsiveDropdownField(
                                  value: selectedSex,
                                  items: ['Masculino', 'Femenino', 'Otro'],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedSex = value!;
                                    });
                                  },
                                  icon: Icons.people,
                                ),
                                SizedBox(height: screenSize.height * 0.02),
                                ResponsiveTextField(
                                  controller: passwordController,
                                  hintText: 'Contraseña',
                                  icon: Icons.lock,
                                  isPassword: true,
                                ),
                                SizedBox(height: screenSize.height * 0.02),
                                ResponsiveDropdownField(
                                  value: userType,
                                  items: ['usuario', 'moderador'],
                                  itemLabels: {
                                    'usuario': 'Usuario',
                                    'moderador': 'Moderador'
                                  },
                                  onChanged: (value) {
                                    setState(() {
                                      userType = value!;
                                    });
                                  },
                                  icon: Icons.person_outline,
                                ),
                                SizedBox(height: screenSize.height * 0.03),
                                SizedBox(
                                  height: buttonHeight,
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Color.fromARGB(255, 135, 255, 137),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            buttonHeight / 2),
                                      ),
                                    ),
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            await _registerUser(context);
                                          },
                                    child: isLoading
                                        ? SizedBox(
                                            height: buttonHeight * 0.5,
                                            width: buttonHeight * 0.5,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Registrarse',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 16 : 18,
                                              fontWeight: FontWeight.bold,
                                              color: const Color.fromARGB(
                                                  255, 0, 0, 0),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: screenSize.height * 0.02),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text(
                              '¿Ya tienes cuenta? Inicia sesión aquí',
                              style: TextStyle(
                                color: const Color.fromARGB(255, 0, 0, 0),
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Responsive TextField Widget
class ResponsiveTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;

  const ResponsiveTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final double fontSize = isSmallScreen ? 14 : 16;

    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: fontSize),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 12 : 16,
          horizontal: isSmallScreen ? 12 : 16,
        ),
      ),
    );
  }
}

// Responsive Dropdown Field Widget
class ResponsiveDropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
  final Map<String, String>? itemLabels;
  final Function(String?) onChanged;
  final IconData icon;

  const ResponsiveDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    this.itemLabels,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final double fontSize = isSmallScreen ? 14 : 16;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 12 : 16,
          horizontal: isSmallScreen ? 12 : 16,
        ),
      ),
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.black,
      ),
      items: items.map((String item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            itemLabels?.containsKey(item) == true ? itemLabels![item]! : item,
            style: TextStyle(fontSize: fontSize),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
