import 'package:flutter/material.dart';
import 'package:ambrosia/screens/game_home_screen.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';
import 'game_screen.dart';

class TutorialScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final String playerName;
  final GameService gameService;

  const TutorialScreen({
    Key? key,
    required this.gameId,
    required this.playerId,
    required this.playerName,
    required this.gameService,
  }) : super(key: key);

  @override
  _TutorialScreenState createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  // Les 4 textes du tuto
  final List<String> tutorialTexts = [
    "Welcome... Nice to meet you, my name is Filip. You also appeared out of nowhere in the middle of the forest? You're not the first. The gods of the forest are having fun opening various portals, and many characters from different universes find themselves trapped in this maze...",
    "I'm a local who lives here. You're not the first ones I've guided. I can't help you directly, but I can tell you what the foxes, the gods of the forest, expect from you. Not only will you have to find your way out of the forest on your own, but you'll also need to collect a certain number of berries...",
    "Indeed, to prove your worth, you must collect 30 berries. Once you reach the edge of the forest, you’ll have to offer them to the foxes. Otherwise, they will never let you leave and may even randomly move you around the forest, making you even more lost.",
    "You'll quickly understand that collecting berries is not always easy. The characters you meet will challenge you, and you'll need to prove your worth. Only one of you will receive the foxes' blessing and be able to leave. Good luck to you. We may meet again."
  ];

  int currentTextIndex = 0;
  bool isFinished = false;  // si le joueur a validé le 4e texte
  bool isWaitingOthers = false; // pour afficher "En attente des autres..."

  @override
  void initState() {
    super.initState();

    // Écoute l’événement "tutorialAllFinished" envoyé par le serveur.
    widget.gameService.socket.on('tutorialAllFinished', _onTutorialAllFinished);
  }

  @override
  void dispose() {
    // Nettoyage
    widget.gameService.socket.off('tutorialAllFinished', _onTutorialAllFinished);
    super.dispose();
  }

  void _onTutorialAllFinished(data) {
    // data contient alors { maze, players, activePlayerName, ... }
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameHomeScreen(
            gameId: widget.gameId,
            playerName: widget.playerName,
            playerId: widget.playerId,
            gameService: widget.gameService,
            initialData: Map<String, dynamic>.from(data),
          ),
        ),
      );
  }


  void _onContinue() {
    // Si on est pas encore sur le dernier texte...
    if (currentTextIndex < tutorialTexts.length - 1) {
      setState(() {
        currentTextIndex++;
      });
    } 
    // Si on était sur le dernier texte, on passe en "finished"
    else {
      setState(() {
        isFinished = true;
        isWaitingOthers = true;
      });

      // Informer le serveur "j'ai fini mon tuto"
      widget.gameService.finishTutorial(widget.gameId, widget.playerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = tutorialTexts[currentTextIndex];

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: AppTheme.backgroundDecoration()),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Titre
                Text(
                  "Welcome",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.buttonBlue,
                  ),
                ),
                SizedBox(height: 40),

                // Le texte qui change
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 18, color: AppTheme.buttonBlue),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 40),

                // Image
                Image.asset(
                  'assets/images/lutin.png', 
                  width: 300, 
                  height: 300,
                ),
                SizedBox(height: 40),

                // Bouton "Continue" si pas fini
                if (!isFinished && !isWaitingOthers)
                  AppTheme.customButton(
                    label: "Continue",
                    onPressed: _onContinue,
                  ),

                // Ou alors "Waiting for others..."
                if (isWaitingOthers)
                  Text("Waiting for other players to finish..."),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
