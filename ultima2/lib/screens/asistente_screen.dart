import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AsistenteAnaScreen extends StatefulWidget {
  const AsistenteAnaScreen({super.key});

  @override
  State<AsistenteAnaScreen> createState() => _AsistenteAnaScreenState();
}

class _AsistenteAnaScreenState extends State<AsistenteAnaScreen> {
  bool _encendido = false;
  bool _hablando = false;
  bool _showPulseAnimation = false;

  void _toggleEncendido() {
    setState(() {
      _encendido = !_encendido;
      if (!_encendido)
        _hablando = false; // Si se apaga, termina la conversación
      if (_encendido) {
        _showPulseAnimation = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showPulseAnimation = false);
        });
      }
    });
  }

  void _toggleHablar() {
    setState(() {
      _hablando = !_hablando;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode =
        themeProvider.currentTheme.brightness == Brightness.light;
    final colors = _getColors(isLightMode);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Asistente Ana',
          style: TextStyle(
            color: isLightMode ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.appBarGradient,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors.backgroundGradient,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar con efecto de pulso
                _buildAvatar(isLightMode),
                const SizedBox(height: 40),

                // Botón principal de encendido
                _buildActionButton(isLightMode, colors),
                const SizedBox(height: 20),

                // Botón de hablar/terminar (solo visible cuando está encendido)
                if (_encendido) ...[
                  _buildHablarButton(isLightMode, colors),
                  const SizedBox(height: 20),
                ],

                // Texto de estado
                _buildStatusText(isLightMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isLightMode) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_showPulseAnimation)
          PulseAnimation(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLightMode
                    ? Colors.green[100]?.withOpacity(0.5)
                    : Colors.green[900]?.withOpacity(0.3),
              ),
            ),
          ),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isLightMode ? Colors.white : Colors.grey[800]!,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            image: const DecorationImage(
              image: AssetImage('assets/ana_avatar.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: _hablando
              ? const Icon(Icons.mic, size: 40, color: Colors.white)
              : null,
        ),
      ],
    );
  }

  Widget _buildActionButton(bool isLightMode, AppColors colors) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.identity()..scale(_encendido ? 1.05 : 1.0),
      child: ElevatedButton(
        onPressed: _toggleEncendido,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.buttonColor,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _encendido ? Icons.power_off : Icons.power_settings_new,
              size: 24,
              color: isLightMode ? Colors.black87 : Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              _encendido ? 'APAGAR' : 'ENCENDER',
              style: TextStyle(
                color: isLightMode ? Colors.black87 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHablarButton(bool isLightMode, AppColors colors) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.identity()..scale(_hablando ? 1.05 : 1.0),
      child: ElevatedButton(
        onPressed: _toggleHablar,
        style: ElevatedButton.styleFrom(
          backgroundColor: _hablando
              ? Colors.red[400]
              : isLightMode
                  ? Colors.blue[400]
                  : Colors.blue[700],
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hablando ? Icons.stop : Icons.mic,
              size: 24,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              _hablando ? 'TERMINAR' : 'HABLAR',
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText(bool isLightMode) {
    String statusText;
    if (!_encendido) {
      statusText = 'Asistente apagada';
    } else if (_hablando) {
      statusText = 'Escuchando...';
    } else {
      statusText = 'Asistente lista';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        statusText,
        key: ValueKey<String>(statusText),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: isLightMode ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }

  AppColors _getColors(bool isLightMode) {
    return isLightMode
        ? AppColors(
            appBarGradient: const [
              Color.fromARGB(255, 153, 251, 174),
              Color(0xFF6DD5ED),
            ],
            backgroundGradient: const [
              Color.fromARGB(255, 125, 255, 140),
              Color(0xFF6DD5ED),
            ],
            buttonColor: const Color.fromARGB(255, 72, 255, 93),
          )
        : AppColors(
            appBarGradient: [
              Colors.grey[900]!,
              Colors.grey[800]!,
            ],
            backgroundGradient: [
              Colors.grey[900]!,
              Colors.grey[800]!,
            ],
            buttonColor: Colors.green[800]!,
          );
  }
}

class AppColors {
  final List<Color> appBarGradient;
  final List<Color> backgroundGradient;
  final Color buttonColor;

  AppColors({
    required this.appBarGradient,
    required this.backgroundGradient,
    required this.buttonColor,
  });
}

class PulseAnimation extends StatefulWidget {
  final Widget child;

  const PulseAnimation({super.key, required this.child});

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}
