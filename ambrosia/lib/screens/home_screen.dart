// lib/screens/home_screen.dart

// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:ambrosia/services/game_service.dart';
import '../services/api_service.dart';
import '../styles/app_theme.dart';
import 'lobby_screen.dart';
import 'package:ambrosia/screens/profil_screen.dart';
import 'package:ambrosia/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> _getLoggedUserProfile() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) return null;
    return await _authService.getProfile();
  }

  // ----------------------------------------------------------
  // CREER UNE PARTIE
  // ----------------------------------------------------------
  Future<void> _createGame() async {
    print('HomeScreen: Bouton "Créer une partie" cliqué');

    final userProfile = await _getLoggedUserProfile();
    String finalPseudo = '';
    String avatarB64 = '';

    if (userProfile != null) {
      finalPseudo = userProfile['pseudo'] ?? '';
      avatarB64 = userProfile['avatarBase64'] ?? '';
      print('HomeScreen: Utilisateur connecté, pseudo="$finalPseudo"');
    } else {
      final pseudoEntered = await _showInputDialog(
        title: 'Créer une partie',
        hint: 'Entrez votre pseudo (max 10 lettres)',
      );
      if (pseudoEntered == null || pseudoEntered.isEmpty) return;

      if (!_validatePlayerName(pseudoEntered)) return;

      finalPseudo = pseudoEntered;
      avatarB64 = '';
    }

    try {
      print('HomeScreen: Appel API createGame(playerName=$finalPseudo)');
      final result = await _apiService.createGame(finalPseudo);

      if (result != null) {
        print(
            'HomeScreen: createGame OK -> gameId=${result['gameId']}, playerId=${result['playerId']}');
        final gameService = GameService();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LobbyScreen(
              gameId: result['gameId']!,
              playerId: result['playerId']!,
              playerName: finalPseudo,
              isHost: true,
              gameService: gameService,
              avatarBase64: avatarB64,
            ),
          ),
        );
      } else {
        print('HomeScreen: createGame renvoie null, erreur ?');
        _showErrorDialog('Erreur lors de la création de la partie.');
      }
    } catch (e) {
      print('HomeScreen: Exception lors de la création de la partie : $e');
      _showErrorDialog('Erreur lors de la création de la partie.');
    }
  }

  // ----------------------------------------------------------
  // REJOINDRE UNE PARTIE
  // ----------------------------------------------------------
  Future<void> _joinGame() async {
    print('HomeScreen: Bouton "Rejoindre une partie" cliqué');

    final gameId = await _showInputDialog(
      title: 'Rejoindre une partie',
      hint: 'Entrez le code de la partie',
    );
    if (gameId == null || gameId.isEmpty) return;

    final userProfile = await _getLoggedUserProfile();
    String finalPseudo = '';
    String avatarB64 = '';

    if (userProfile != null) {
      finalPseudo = userProfile['pseudo'] ?? '';
      avatarB64 = userProfile['avatarBase64'] ?? '';
      print('HomeScreen: Utilisateur connecté, pseudo="$finalPseudo"');
    } else {
      final pseudoEntered = await _showInputDialog(
        title: 'Pseudo',
        hint: 'Entrez votre pseudo (max 10 lettres)',
      );
      if (pseudoEntered == null || pseudoEntered.isEmpty) return;

      if (!_validatePlayerName(pseudoEntered)) return;

      finalPseudo = pseudoEntered;
      avatarB64 = '';
    }

    try {
      print(
          'HomeScreen: Appel API joinGame(gameId=$gameId, playerName=$finalPseudo)');
      final result = await _apiService.joinGame(gameId, finalPseudo);
      if (result != null) {
        print('HomeScreen: joinGame OK -> playerId=${result['playerId']}');
        final gameService = GameService();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LobbyScreen(
              gameId: gameId,
              playerId: result['playerId']!,
              playerName: finalPseudo,
              isHost: false,
              gameService: gameService,
              avatarBase64: avatarB64,
            ),
          ),
        );
      } else {
        print('HomeScreen: joinGame renvoie null, erreur ?');
        _showErrorDialog('Erreur lors de la connexion à la partie.');
      }
    } catch (e) {
      print('HomeScreen: Exception lors de la connexion à la partie : $e');
      _showErrorDialog('Erreur lors de la connexion à la partie.');
    }
  }

  Future<String?> _showInputDialog({
    required String title,
    required String hint,
  }) async {
    final TextEditingController controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(viewInsets: EdgeInsets.zero),
          child: Theme(
            data: AppTheme.themeData,
            child: AlertDialog(
              title: Text(
                title,
                style: AppTheme.themeData.textTheme.bodyLarge,
              ),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTheme.themeData.textTheme.bodySmall,
                ),
                style: AppTheme.themeData.textTheme.bodySmall,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTheme.themeData.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, controller.text.trim());
                  },
                  child: Text(
                    'Confirm',
                    style: AppTheme.themeData.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _validatePlayerName(String name) {
    final regex = RegExp(r'^[a-zA-Z0-9\-]{1,10}$');
    if (!regex.hasMatch(name)) {
      _showErrorDialog('Invalid nickname. Use only letters, digits, or "-".');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Fond de la home
          Container(
            decoration: AppTheme.backgroundDecoration(isHome: true),
          ),
          // Titre
          Positioned(
            top: screenHeight * 0.08,
            left: screenWidth * 0.05,
            right: screenWidth * 0.05,
            child: Center(
              child: Text(
                'Ambrosia',
                // On utilise notre thème, MAIS on veut un fontWeight plus léger:
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w100, // plus fin que bold
                    ),
              ),
            ),
          ),
          // Sous-titre
          Positioned(
            top: screenHeight * 0.14,
            left: 0,
            right: 0,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10), // Ajout de padding
              child: Center(
                child: Text(
                  'Parviendrez-vous à vous hisser au sommet ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.normal,
                    fontFamily: 'PermanentMarker',
                    color: AppTheme.subtitleWhite,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Boutons
          Positioned(
            bottom: screenHeight * 0.06,
            left: screenWidth * 0.1,
            right: screenWidth * 0.1,
            child: Center(
              child: ConstrainedBox(
                // Diminue la largeur max
                constraints: const BoxConstraints(maxWidth: 250),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // On personnalise encore un peu la hauteur
                        style: ButtonStyle(
                          minimumSize: MaterialStateProperty.all(
                            const Size.fromHeight(56), // plus haut
                          ),
                          backgroundColor: MaterialStateProperty.all(
                              AppTheme.buttonBlue),
                          foregroundColor:
                              MaterialStateProperty.all(AppTheme.white),
                          textStyle: MaterialStateProperty.all(
                            const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                              side: const BorderSide(
                                color: AppTheme.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilScreen(),
                            ),
                          );
                        },
                        child: const Text('Mon profil'),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          minimumSize: MaterialStateProperty.all(
                            const Size.fromHeight(56),
                          ),
                          backgroundColor: MaterialStateProperty.all(
                              AppTheme.buttonBlue),
                          foregroundColor:
                              MaterialStateProperty.all(AppTheme.white),
                          textStyle: MaterialStateProperty.all(
                            const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                              side: const BorderSide(
                                color: AppTheme.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        onPressed: _createGame,
                        child: const Text('Créer une partie'),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          minimumSize: MaterialStateProperty.all(
                            const Size.fromHeight(56),
                          ),
                          backgroundColor: MaterialStateProperty.all(
                              AppTheme.buttonBlue),
                          foregroundColor:
                              MaterialStateProperty.all(AppTheme.white),
                          textStyle: MaterialStateProperty.all(
                            const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                              side: const BorderSide(
                                color: AppTheme.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        onPressed: _joinGame,
                        child: const Text('Rejoindre une partie'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
