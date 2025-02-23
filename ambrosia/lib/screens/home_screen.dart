// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:ambrosia/services/game_service.dart';
import '../services/api_service.dart';
import '../styles/app_theme.dart';
import 'lobby_screen.dart';
import 'package:ambrosia/screens/profil_screen.dart';
import 'package:ambrosia/services/auth_service.dart'; 


class HomeScreen extends StatefulWidget {
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

    // 1) Vérifier si on a un compte
    final userProfile = await _getLoggedUserProfile();

    // On déclare en tant que String "non-null", initialisé à vide
    String finalPseudo = '';
    String avatarB64 = '';

    if (userProfile != null) {
      // => On récupère le pseudo et l'avatar depuis le profil
      finalPseudo = userProfile['pseudo'] ?? '';
      avatarB64 = userProfile['avatarBase64'] ?? '';
      print('HomeScreen: Utilisateur connecté, pseudo="$finalPseudo"');
    } else {
      // => Utilisateur pas connecté => on demande le pseudo
      final pseudoEntered = await _showInputDialog(
        title: 'Créer une partie',
        hint: 'Entrez votre pseudo (max 10 lettres)',
      );
      // Si l’utilisateur annule ou saisit rien => on quitte
      if (pseudoEntered == null || pseudoEntered.isEmpty) return;

      // On valide le pseudo
      if (!_validatePlayerName(pseudoEntered)) return;

      finalPseudo = pseudoEntered;
      avatarB64 = '';
    }

    // 2) Appel API (finalPseudo est forcément non-null et non vide ici)
    try {
      print('HomeScreen: Appel API createGame(playerName=$finalPseudo)');
      final result = await _apiService.createGame(finalPseudo);

      if (result != null) {
        print('HomeScreen: createGame OK -> gameId=${result['gameId']}, playerId=${result['playerId']}');

        final gameService = GameService();

        // 3) Navigation vers Lobby
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LobbyScreen(
              gameId: result['gameId']!,
              playerId: result['playerId']!,
              playerName: finalPseudo,       // <- maintenant c’est un String
              isHost: true,
              gameService: gameService,
              avatarBase64: avatarB64,       // <- pareil, c’est un String
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

    // On demande le gameId d’abord
    final gameId = await _showInputDialog(
      title: 'Rejoindre une partie',
      hint: 'Entrez le code de la partie',
    );
    if (gameId == null || gameId.isEmpty) return;

    // On vérifie si utilisateur logué
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

    // On appelle l’API
    try {
      print('HomeScreen: Appel API joinGame(gameId=$gameId, playerName=$finalPseudo)');
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
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
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
          // Fond commun
          Container(
            decoration: AppTheme.backgroundDecoration(),
          ),
          // Titre
          Positioned(
            top: screenHeight * 0.15,
            left: screenWidth * 0.05,
            right: screenWidth * 0.05,
            child: Center(
              child: Text(
                'Ambrosia',
                style: Theme.of(context).textTheme.headline1,
              ),
            ),
          ),
          // Logo
          Positioned(
            top: screenHeight * 0.2,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/logo-renard.png',
              height: screenHeight * 0.4,
              width: screenWidth * 0.4,
              fit: BoxFit.contain,
            ),
          ),
          // Boutons
          Positioned(
            bottom: screenHeight * 0.15,
            left: screenWidth * 0.1,
            right: screenWidth * 0.1,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280), // largeur maximale fixée
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: AppTheme.customButton(
                        label: 'Mon profil',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    SizedBox(
                      width: double.infinity,
                      child: AppTheme.customButton(
                        label: 'Créer une partie',
                        onPressed: _createGame,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    SizedBox(
                      width: double.infinity,
                      child: AppTheme.customButton(
                        label: 'Rejoindre une partie',
                        onPressed: _joinGame,
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