import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class GameScreen extends StatefulWidget {
  @override
  _SnakeGameState createState() => _SnakeGameState();
}

class _SnakeGameState extends State<GameScreen> {
  // Variables del juego
  List<Offset> snake = [Offset(0, 0)]; // Cuerpo de la serpiente
  Offset food = Offset(0, 0); // Posición de la comida
  Offset direction = Offset(1, 0); // Dirección de la serpiente
  int gridSize = 20; // Tamaño de la cuadrícula
  bool isPlaying = false; // Estado del juego
  Timer? gameTimer;
  FocusNode focusNode =
      FocusNode(); // Nodo de enfoque para capturar eventos de teclado

  // Variables para Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int highScore = 0;
  String highScoreUser = 'Nadie';

  // Variables para almacenamiento local
  final String _localScoreKey = 'localScore';
  int localScore = 0;
  bool isOnline = true;

  // Variables para manejar la conexión
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    startGame();
    _loadHighScore(); // Cargar el puntaje más alto al iniciar
    _loadLocalScore(); // Cargar el puntaje local al iniciar
    _initConnectivity(); // Iniciar la detección de conexión
  }

  void startGame() {
    setState(() {
      snake = [
        Offset((gridSize ~/ 2).toDouble(), (gridSize ~/ 2).toDouble())
      ]; // Inicia la serpiente en el centro
      spawnFood();
      isPlaying = true;
    });

    gameTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      moveSnake();
    });
  }

  void spawnFood() {
    // Genera comida en una posición aleatoria
    final random = Random();
    setState(() {
      food = Offset(
        random.nextInt(gridSize).toDouble(),
        random.nextInt(gridSize).toDouble(),
      );
    });
  }

  void moveSnake() {
    if (!isPlaying) return;

    setState(() {
      // Calcula la nueva cabeza de la serpiente
      Offset newHead = Offset(
        snake.first.dx + direction.dx,
        snake.first.dy + direction.dy,
      );

      // Verifica colisiones
      if (newHead.dx < 0 ||
          newHead.dx >= gridSize ||
          newHead.dy < 0 ||
          newHead.dy >= gridSize ||
          snake.any((segment) => segment == newHead)) {
        gameOver();
        return;
      }

      // Añade la nueva cabeza
      snake.insert(0, newHead);

      // Verifica si come la comida
      if (newHead == food) {
        spawnFood();
      } else {
        // Remueve la cola si no come
        snake.removeLast();
      }
    });
  }

  void gameOver() {
    setState(() {
      isPlaying = false;
    });
    gameTimer?.cancel();

    // Guardar el puntaje localmente
    final currentScore = snake.length - 1;
    _saveLocalScore(currentScore);

    // Intentar sincronizar con Firebase
    _syncScoreWithFirebase(currentScore);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('¡Game Over!'),
          content: Text('Puntaje: ${snake.length - 1}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                startGame();
              },
              child: Text('Jugar de nuevo'),
            ),
          ],
        );
      },
    );
  }

  void changeDirection(Offset newDirection) {
    // Evita que la serpiente se mueva en la dirección opuesta
    if (direction.dx != -newDirection.dx || direction.dy != -newDirection.dy) {
      setState(() {
        direction = newDirection;
      });
    }
  }

  // Maneja los eventos de teclado
  void handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        changeDirection(Offset(0, -1)); // Arriba
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        changeDirection(Offset(0, 1)); // Abajo
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        changeDirection(Offset(-1, 0)); // Izquierda
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        changeDirection(Offset(1, 0)); // Derecha
      }
    }
  }

  // Cargar el puntaje más alto desde Firebase
  Future<void> _loadHighScore() async {
    try {
      final doc =
          await _firestore.collection('highScores').doc('snakeGame').get();
      if (doc.exists) {
        setState(() {
          highScore = doc['score'] ?? 0;
          highScoreUser = doc['user'] ?? 'Nadie';
        });
      } else {
        // Crear el documento si no existe
        await _firestore.collection('highScores').doc('snakeGame').set({
          'score': 0,
          'user': 'Nadie',
        });
      }
    } catch (e) {
      print('Error al cargar el puntaje más alto: $e');
    }
  }

  // Guardar el puntaje localmente
  Future<void> _saveLocalScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_localScoreKey, score);
    setState(() {
      localScore = score;
    });
  }

  // Cargar el puntaje local
  Future<void> _loadLocalScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      localScore = prefs.getInt(_localScoreKey) ?? 0;
    });
  }

  // Obtener el nombre del usuario desde Firestore
  Future<String> _getUserName() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          return userDoc['name'] ?? 'Nadie'; // Usar el campo 'name' del perfil
        }
      } catch (e) {
        print('Error al obtener el nombre del usuario: $e');
      }
    }
    return 'Nadie'; // Valor por defecto si no se encuentra el nombre
  }

  // Sincronizar el puntaje con Firebase
  Future<void> _syncScoreWithFirebase(int score) async {
    if (isOnline) {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          // Obtener el puntaje actual desde Firebase
          final doc =
              await _firestore.collection('highScores').doc('snakeGame').get();
          final int currentHighScore = doc.exists ? doc['score'] ?? 0 : 0;

          // Solo actualizar si el nuevo puntaje es mayor que el puntaje actual
          if (score > currentHighScore) {
            // Obtener el nombre del usuario desde Firestore
            final userName = await _getUserName();

            // Actualizar el puntaje en Firestore
            await _firestore.collection('highScores').doc('snakeGame').set({
              'score': score,
              'user': userName,
            });

            // Recargar el puntaje más alto
            _loadHighScore();
          }
        } catch (e) {
          print('Error al sincronizar el puntaje: $e');
        }
      }
    } else {
      // Si no hay conexión, guardar el puntaje localmente
      _saveLocalScore(score);
    }
  }

  // Iniciar la detección de conexión
  Future<void> _initConnectivity() async {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      setState(() {
        isOnline = result != ConnectivityResult.none;
      });

      // Si hay conexión, intentar sincronizar el puntaje local
      if (isOnline && localScore > 0) {
        _syncScoreWithFirebase(localScore);
      }
    }) as StreamSubscription<ConnectivityResult>?;
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    focusNode.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final cellSize =
        MediaQuery.of(context).size.width / gridSize; // Tamaño de cada celda

    return Scaffold(
      appBar: AppBar(
        title: Text('Juego del Gusanito'),
        centerTitle: true,
      ),
      body: RawKeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKey: handleKeyEvent,
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy > 0) {
                    changeDirection(Offset(0, 1)); // Abajo
                  } else if (details.delta.dy < 0) {
                    changeDirection(Offset(0, -1)); // Arriba
                  }
                },
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx > 0) {
                    changeDirection(Offset(1, 0)); // Derecha
                  } else if (details.delta.dx < 0) {
                    changeDirection(Offset(-1, 0)); // Izquierda
                  }
                },
                child: Container(
                  color: Colors.black,
                  child: GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize,
                      childAspectRatio: 1, // Celdas cuadradas
                    ),
                    itemCount: gridSize * gridSize,
                    itemBuilder: (context, index) {
                      final x = index % gridSize;
                      final y = index ~/ gridSize;
                      final isSnake = snake
                          .any((segment) => segment.dx == x && segment.dy == y);
                      final isFood = food.dx == x && food.dy == y;

                      return Container(
                        margin: EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: isSnake
                              ? Colors.green
                              : isFood
                                  ? Colors.red
                                  : Colors.grey[900],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Puntaje: ${snake.length - 1}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Récord: $highScore por $highScoreUser',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
