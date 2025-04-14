import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class PerfilScreen extends StatefulWidget {
  final String userName;

  const PerfilScreen({Key? key, required this.userName}) : super(key: key);

  @override
  _PerfilScreenState createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();

  String userType = 'usuario';
  String selectedSex = 'Masculino';
  bool isLoading = false;
  bool isEditing = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  final Map<String, AssetImage> sexImages = {
    'Masculino': AssetImage('assets/male_avatar.png'),
    'Femenino': AssetImage('assets/female_avatar.png'),
    'Otro': AssetImage('assets/other_avatar.png'),
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (currentUser != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userData.exists) {
          setState(() {
            nameController.text = userData['name'] ?? '';
            emailController.text = currentUser!.email ?? '';
            phoneController.text = userData['phone'] ?? '';
            ageController.text = userData['age']?.toString() ?? '';
            selectedSex = userData['sex'] ?? 'Masculino';
            userType = userData['userType'] ?? 'usuario';
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error al cargar datos: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _updateEmail(String newEmail) async {
    if (currentPasswordController.text.isEmpty) {
      _showErrorSnackBar('Ingresa tu contraseña actual para cambiar el correo');
      return;
    }

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: currentPasswordController.text,
      );
      await currentUser!.reauthenticateWithCredential(credential);
      await currentUser!.updateEmail(newEmail);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'email': newEmail});

      _showErrorSnackBar('Correo electrónico actualizado correctamente');
      currentPasswordController.clear();
    } catch (e) {
      _showErrorSnackBar('Error al actualizar correo: $e');
    }
  }

  Future<void> _updatePassword() async {
    if (currentPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty) {
      _showErrorSnackBar('Ingresa tanto la contraseña actual como la nueva');
      return;
    }

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: currentPasswordController.text,
      );
      await currentUser!.reauthenticateWithCredential(credential);
      await currentUser!.updatePassword(newPasswordController.text);

      _showErrorSnackBar('Contraseña actualizada correctamente');
      currentPasswordController.clear();
      newPasswordController.clear();
    } catch (e) {
      _showErrorSnackBar('Error al actualizar contraseña: $e');
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Validar edad
      int? age = int.tryParse(ageController.text);
      if (age == null || age <= 0 || age > 120) {
        throw Exception('Edad inválida');
      }

      // Actualizar datos en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'name': nameController.text,
        'phone': phoneController.text,
        'age': age,
        'sex': selectedSex,
      });

      // Actualizar email si cambió
      if (emailController.text != currentUser!.email) {
        await _updateEmail(emailController.text);
      }

      setState(() {
        isEditing = false;
      });

      _showErrorSnackBar('Perfil actualizado correctamente');
    } catch (e) {
      _showErrorSnackBar('Error al guardar cambios: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showPasswordDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: themeProvider.currentTheme.dialogBackgroundColor,
          title: Text(
            'Cambiar Contraseña',
            style: TextStyle(
              color: themeProvider.currentTheme.textTheme.bodyLarge?.color,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña Actual',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color:
                        themeProvider.currentTheme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nueva Contraseña',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color:
                        themeProvider.currentTheme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: themeProvider.currentTheme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updatePassword();
              },
              child: Text('Cambiar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: themeProvider.currentTheme.brightness == Brightness.light
              ? Colors.white.withOpacity(0.9)
              : Colors.grey[800]!.withOpacity(0.9),
          enabled: isEditing && enabled,
          labelStyle: TextStyle(
            color: themeProvider.currentTheme.textTheme.bodyLarge?.color,
          ),
        ),
        style: TextStyle(
          color: themeProvider.currentTheme.textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, double screenWidth) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isWideScreen = screenWidth > 600;
    final double contentWidth = isWideScreen ? 600 : screenWidth;

    return Container(
      width: contentWidth,
      padding: EdgeInsets.all(isWideScreen ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: themeProvider.currentTheme.shadowColor,
                  blurRadius: 10.0,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: isWideScreen ? 80 : 60,
              backgroundColor:
                  themeProvider.currentTheme.brightness == Brightness.light
                      ? const Color.fromARGB(255, 199, 255, 255)
                      : Colors.grey[700]!,
              backgroundImage: sexImages[selectedSex],
            ),
          ),
          SizedBox(height: isWideScreen ? 32 : 24),
          _buildFormField(
            controller: nameController,
            label: 'Nombre',
          ),
          _buildFormField(
            controller: emailController,
            label: 'Correo Electrónico',
          ),
          _buildFormField(
            controller: phoneController,
            label: 'Número de Teléfono',
          ),
          _buildFormField(
            controller: ageController,
            label: 'Edad',
            keyboardType: TextInputType.number,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: isEditing
                ? Container(
                    decoration: BoxDecoration(
                      color: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? const Color.fromARGB(255, 252, 252, 252)
                              .withOpacity(0.9)
                          : Colors.grey[800]!.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeProvider.currentTheme.dividerColor,
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: selectedSex,
                      decoration: InputDecoration(
                        labelText: 'Sexo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelStyle: TextStyle(
                          color: themeProvider
                              .currentTheme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      items:
                          ['Masculino', 'Femenino', 'Otro'].map((String sex) {
                        return DropdownMenuItem(
                          value: sex,
                          child: Text(
                            sex,
                            style: TextStyle(
                              color: themeProvider
                                  .currentTheme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSex = value!;
                        });
                      },
                    ),
                  )
                : InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Sexo',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: themeProvider.currentTheme.brightness ==
                              Brightness.light
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey[800]!.withOpacity(0.9),
                      labelStyle: TextStyle(
                        color: themeProvider
                            .currentTheme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    child: Text(
                      selectedSex,
                      style: TextStyle(
                        color: themeProvider
                            .currentTheme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Tipo de Usuario',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    themeProvider.currentTheme.brightness == Brightness.light
                        ? Colors.white.withOpacity(0.9)
                        : Colors.grey[800]!.withOpacity(0.9),
                labelStyle: TextStyle(
                  color: themeProvider.currentTheme.textTheme.bodyLarge?.color,
                ),
              ),
              child: Text(
                userType,
                style: TextStyle(
                  color: themeProvider.currentTheme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
          if (isEditing) ...[
            SizedBox(height: isWideScreen ? 32 : 24),
            ElevatedButton(
              onPressed: _showPasswordDialog,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isWideScreen ? 32 : 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Cambiar Contraseña'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Perfil',
          style: TextStyle(
            // Color dinámico basado en el tema
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
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: isLoading
                ? null
                : () {
                    if (isEditing) {
                      _saveChanges();
                    } else {
                      setState(() {
                        isEditing = true;
                      });
                    }
                  },
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
                  ? Color.fromARGB(255, 169, 251, 163)
                  : Colors.grey[900]!,
              themeProvider.currentTheme.brightness == Brightness.light
                  ? Color(0xFF6DD5ED)
                  : Colors.grey[800]!,
            ],
          ),
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildProfileContent(
                              context,
                              constraints.maxWidth,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          themeProvider.currentTheme.brightness ==
                                  Brightness.light
                              ? Color(0xFF2193B0)
                              : Colors.grey[900]!,
                          themeProvider.currentTheme.brightness ==
                                  Brightness.light
                              ? Color(0xFF6DD5ED)
                              : Colors.grey[800]!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: themeProvider.currentTheme.shadowColor,
                          offset: Offset(0, -4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '© 2025 Friendly Dentistry',
                        style: TextStyle(
                          color: themeProvider
                              .currentTheme.textTheme.bodyLarge?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    ageController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }
}
