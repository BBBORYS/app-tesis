import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AsistenteAnaScreen extends StatefulWidget {
  const AsistenteAnaScreen({Key? key}) : super(key: key);

  @override
  _AsistenteAnaScreenState createState() => _AsistenteAnaScreenState();
}

class _AsistenteAnaScreenState extends State<AsistenteAnaScreen> {
  bool _isOn = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentTheme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Asistente Ana',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDarkMode
                    ? Colors.grey[900]!
                    : Color.fromARGB(255, 153, 251, 174),
                isDarkMode ? Colors.grey[800]! : Color(0xFF6DD5ED),
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
              isDarkMode
                  ? Colors.grey[900]!
                  : Color.fromARGB(255, 125, 255, 140),
              isDarkMode ? Colors.grey[800]! : Color(0xFF6DD5ED),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: screenSize.width * 0.6,
                height: screenSize.width * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isOn ? Colors.green : Colors.grey[300]!,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/ana_avatar.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.mic_none,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                _isOn ? 'Asistente activado' : 'Asistente desactivado',
                style: TextStyle(
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isOn = !_isOn;
                  });
                },
                child: Container(
                  width: 120,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: _isOn
                        ? Color.fromARGB(255, 1, 248, 54).withOpacity(0.3)
                        : Colors.grey[400]!.withOpacity(0.3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 3))
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (!_isOn)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 20),
                            child: Text(
                              'OFF',
                              style: TextStyle(
                                color: const Color.fromARGB(255, 0, 0, 0),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      if (_isOn)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Text(
                              'ON',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      AnimatedAlign(
                        duration: Duration(milliseconds: 200),
                        alignment: _isOn
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 50,
                          height: 50,
                          margin: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color.fromARGB(255, 87, 220, 247),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
