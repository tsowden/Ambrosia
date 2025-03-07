// lib/screens/game_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';
import '../widgets/dungeon_views.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerName;
  final String playerId;
  final GameService gameService;

  // État apporté par GameHomeScreen
  final String turnState;
  final bool isPlayerActive;

  final int myBerries;
  final int myRank;
  final int totalPlayers;
  final String? myAvatarBase64;
  final String? activePlayerAvatar;
  final String? activePlayerName;

  final String? cardName;
  final String? cardImage;
  final String? cardDescription;
  final String? cardCategory;
  final String? cardSubheading;

  final List<String> betOptions;
  final String? majorityVote;

  // Quiz
  final bool isQuizInProgress;
  final List<String> quizThemes;
  final bool? quizWasAnswerCorrect;
  final String? quizCorrectAnswer;
  final int quizCorrectAnswers;     // Nombre correct de réponses côté widget
  final int quizTotalQuestions;     // Nombre total de questions côté widget
  final int quizEarnedBerries;
  final int? quizCurrentDifficulty; // valeur initiale éventuellement

  // Mouvements possibles
  final Map<String, bool> validMoves;

  // Position/orientation joueur
  final int playerX;
  final int playerY;
  final String playerOrientation;

  // La map au format objets
  final List<List<Map<String, dynamic>>> fullMapObjects;

  const GameScreen({
    Key? key,
    required this.gameId,
    required this.playerName,
    required this.playerId,
    required this.gameService,
    required this.turnState,
    required this.isPlayerActive,
    required this.myBerries,
    required this.myRank,
    required this.totalPlayers,
    this.myAvatarBase64,
    this.activePlayerAvatar,
    this.activePlayerName,
    this.cardName,
    this.cardImage,
    this.cardDescription,
    this.cardCategory,
    this.cardSubheading,
    required this.betOptions,
    this.majorityVote,
    required this.isQuizInProgress,
    required this.quizThemes,
    this.quizWasAnswerCorrect,
    this.quizCorrectAnswer,
    required this.quizCorrectAnswers,
    required this.quizTotalQuestions,
    required this.quizEarnedBerries,
    required this.validMoves,
    required this.playerX,
    required this.playerY,
    required this.playerOrientation,
    required this.fullMapObjects,
    this.quizCurrentDifficulty,
  }) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Mémorise l'ancien état du tour pour l'animation
  String _oldTurnState = '';

  // Sélection du thème/difficulté quiz
  String? _selectedQuizTheme;
  bool _isLoadingQuizQuestion = false;

  // Infos quiz liées à la question en cours (venues de 'quizQuestion')
  int? _quizCurrentIndex;
  String? _quizCurrentDescription;
  List<dynamic>? _quizCurrentOptions;
  String? _quizCurrentImage;
  String? _quizCurrentCategory;
  int? _quizCurrentDifficulty;

  // Variables locales sur le résultat final
  String? _activeQuizResultMessage;
  String? _nonActiveQuizResultMessage;

  // Nombre correct/total de réponses de l'actif pour l'affichage passif
  int _localActivePlayerCorrectAnswers = 0;
  int _localQuizTotalQuestions = 0;

  // Niveau choisi (Débutant ou Expert)
  String _quizDifficulty = "Débutant";

  @override
  void initState() {
    super.initState();
    _oldTurnState = widget.turnState;

    // Écoute de l'événement 'quizQuestion' => met à jour la question
    widget.gameService.socket.on('quizQuestion', (data) {
      setState(() {
        _quizCurrentIndex     = data["questionIndex"];
        _quizCurrentDescription = data["questionDescription"];
        _quizCurrentOptions  = data["questionOptions"];
        _quizCurrentImage    = data["questionImage"];
        _quizCurrentCategory = data["questionCategory"];
        _quizCurrentDifficulty = data["questionDifficulty"];
        _isLoadingQuizQuestion = false;
      });
    });

    // Écoute de 'quizEnd' => on met à jour localement
    widget.gameService.onQuizEnd((data) {
      setState(() {
        // Récupère la difficulté
        _quizDifficulty = data['chosenDifficulty'] ?? "Débutant";

        // Récupère le nombre de bonnes réponses + totalQuestions du joueur ACTIF
        final activeCorrect = int.tryParse("${data['activeResult']['correctAnswers']}") ?? 0;
        final totalQ = int.tryParse("${data['activeResult']['totalQuestions']}") ?? 3;

        // Stocke pour l'affichage du joueur actif
        _localActivePlayerCorrectAnswers = activeCorrect;
        _localQuizTotalQuestions = totalQ;

        // Construit le message final pour le joueur ACTIF si on est l'actif
        _activeQuizResultMessage = _buildActiveResultMessage(_quizDifficulty, activeCorrect);

        // Si on est passif => on récupère notre propre score
        if (!widget.isPlayerActive && data['nonActiveResults'] != null) {
          final nonActiveResults = data['nonActiveResults'] as List<dynamic>;
          final myResult = nonActiveResults.firstWhere(
            (r) => r['playerId'] == widget.playerId,
            orElse: () => null,
          );
          if (myResult != null) {
            final correct = int.tryParse("${myResult['correct']}") ?? 0;
            final reward  = int.tryParse("${myResult['reward']}") ?? 0;
            final answered = (myResult['total'] != null && myResult['total'] > 0);
            _nonActiveQuizResultMessage =
                _buildPassiveOwnResultMessage(_quizDifficulty, correct, totalQ, reward, answered);
          } else {
            _nonActiveQuizResultMessage = "Vous n’avez répondu à aucune question.";
          }
        }
      });
    });
  }

  @override
  void didUpdateWidget(GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Détecte un changement d'état du tour
    if (widget.turnState != oldWidget.turnState) {
      setState(() => _oldTurnState = oldWidget.turnState);
    }
  }

  // ---------------------------------------------------------------------------
  // 1) Message de résultat pour le joueur ACTIF (fin de quiz)
  // ---------------------------------------------------------------------------
  String _buildActiveResultMessage(String difficulty, int correct) {
    // On sait qu'il y a 3 questions
    if (difficulty == "Débutant") {
      switch (correct) {
        case 3:
          return "Vous avez répondu bon à toutes les questions !\n+ 2 FD3.png";
        case 2:
          return "Vous avez répondu bon à 2 questions sur 3.\n+ 1 FD3.png";
        case 1:
          return "Vous n’avez répondu correctement qu’à 1 question sur 3. Au vu de la facilité des questions posées, ce n’est pas suffisant pour être récompensé.";
        default: // 0
          return "Vous avez tout faux. Les dieux sont indignés par votre performance.\n+ 0 FD3.png";
      }
    } else {
      // Expert
      switch (correct) {
        case 3:
          return "Vous avez répondu bon à toutes les questions !\n+ 3 FD3.png";
        case 2:
          return "Vous avez répondu bon à 2 questions sur 3.\n+ 2 FD3.png";
        case 1:
          return "Vous avez répondu bon à 1 question sur 3.\n+ 1 FD3.png";
        default: // 0
          return "Vous avez tout faux. Les dieux restent tolérants au vu de la difficulté des questions mais ne vous récompensent pas pour autant.\n+ 0 FD3.png";
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 2) Message de résultat (vue passive) sur le joueur ACTIF
  // ---------------------------------------------------------------------------
  String _buildPassiveActiveResultMessage(String difficulty, String activeName, int correct) {
    if (difficulty == "Débutant") {
      switch (correct) {
        case 3:
          return "$activeName a répondu bon à toutes les questions ! Les dieux lui accordent 2 faveurs divines.";
        case 2:
          return "$activeName a répondu bon à 2 questions sur 3. Les dieux lui accordent 1 faveur divine.";
        case 1:
          return "$activeName a répondu bon à 1 question sur 3. Au vu de la facilité des questions posées, ce n’est pas suffisant pour être récompensé.";
        default:
          return "$activeName a tout faux. Les dieux sont indignés et lui retirent 1 faveur divine.";
      }
    } else {
      // Expert
      switch (correct) {
        case 3:
          return "$activeName a répondu bon à toutes les questions ! Les dieux lui accordent 3 faveurs divines.";
        case 2:
          return "$activeName a répondu bon à 2 questions sur 3. Les dieux lui accordent 2 faveurs divines.";
        case 1:
          return "$activeName a répondu bon à 1 question sur 3. Les dieux lui accordent 1 faveur divine.";
        default:
          return "$activeName a tout faux. Les dieux sont tolérants au vu de la difficulté des questions, mais ne vont pas récompenser un score aussi mauvais.";
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 3) Message pour le joueur passif sur lui-même
  // ---------------------------------------------------------------------------
  String _buildPassiveOwnResultMessage(String difficulty, int correct, int totalQ, int reward, bool answered) {
    if (!answered) {
      return "Dommage, vous n’avez répondu à aucune question. La prochaine fois, vous pouvez essayer de répondre même si le regard des dieux n’est pas tourné vers vous.";
    }
    if (correct == totalQ) {
      if (reward > 0) {
        return "Vous avez été suffisamment rapide et eu bon à toutes les questions ! Les dieux ont remarqué votre exploit et vous récompensent d’une faveur divine.";
      } else {
        return "Vous avez été suffisamment rapide et eu bon à toutes les questions ! Malheureusement, le regard des dieux n’était pas tourné vers vous…";
      }
    } else if (correct > 0) {
      return "Vous avez répondu bon à $correct question${correct > 1 ? 's' : ''} sur 3 ! Ce n’est pas si mal, mais malheureusement insuffisant pour espérer gagner quoi que ce soit.";
    } else {
      return "Vous avez tout faux ! Heureusement que personne ne vous regardait lorsque vous essayiez vainement de répondre à ces questions.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Container(decoration: AppTheme.backgroundDecoration()),
        // "Vos infos"
        Positioned(
          top: screenHeight * 0.06,
          left: MediaQuery.of(context).size.width * 0.04,
          child: _buildYourInfo(context),
        ),
        // Joueur actif
        Positioned(
          top: screenHeight * 0.06,
          right: MediaQuery.of(context).size.width * 0.04,
          child: _buildActivePlayerInfo(context),
        ),
        // Corps de page => selon le turnState + si on est actif/passif
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              top: screenHeight * 0.20,
              left: MediaQuery.of(context).size.width * 0.03,
              right: MediaQuery.of(context).size.width * 0.03,
              bottom: screenHeight * 0.02,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Container(
                key: ValueKey(widget.turnState),
                child: SingleChildScrollView(
                  child: widget.isPlayerActive
                      ? _buildActivePlayerView()
                      : _buildPassivePlayerView(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // "Vos infos" (faveurs, rang, etc.)
  // ----------------------------------------------------------------
  Widget _buildYourInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = screenWidth * 0.18;
    final maxBerries = 30;
    final rankStr = "${_rankSuffix(widget.myRank)} sur ${widget.totalPlayers}";

    return SizedBox(
      width: circleSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Faveurs:", textAlign: TextAlign.center, style: AppTheme.topLabelStyle(context, 0.03)),
          const SizedBox(height: 4),
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${widget.myBerries}/$maxBerries", style: AppTheme.circleNumberStyle(circleSize)),
                SizedBox(height: circleSize * 0.05),
                Image.asset('assets/images/FD.png', width: circleSize * 0.40, height: circleSize * 0.40),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(rankStr, textAlign: TextAlign.center, style: AppTheme.rankStyle(context, 0.03)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Joueur actif
  // ----------------------------------------------------------------
  Widget _buildActivePlayerInfo(BuildContext context) {
    final circleSize = MediaQuery.of(context).size.width * 0.18;

    Widget avatarWidget;
    if (widget.activePlayerAvatar != null && widget.activePlayerAvatar!.isNotEmpty) {
      final bytes = base64Decode(widget.activePlayerAvatar!);
      avatarWidget = CircleAvatar(radius: circleSize * 0.5, backgroundImage: MemoryImage(bytes));
    } else {
      avatarWidget = Icon(Icons.person, size: circleSize * 0.5, color: AppTheme.primaryColor);
    }

    return SizedBox(
      width: circleSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Turn:", textAlign: TextAlign.center, style: AppTheme.topLabelStyle(context, 0.03)),
          const SizedBox(height: 4),
          SizedBox(width: circleSize, height: circleSize, child: avatarWidget),
          const SizedBox(height: 4),
          Text("Tour de ${widget.activePlayerName ?? '???'}",
              textAlign: TextAlign.center, style: AppTheme.topLabelStyle(context, 0.03)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // MOUVEMENT
  // ----------------------------------------------------------------
  Widget _buildMovementView({required bool isActive}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTheme.themeData.textTheme.bodyMedium,
            children: [
              if (isActive)
                const TextSpan(text: "C'est votre tour. Avancez dans le ")
              else
                TextSpan(text: "${widget.activePlayerName} se déplace dans le "),
              const TextSpan(
                text: "labyrinthe de brume",
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.boldRed),
              ),
              if (isActive)
                const TextSpan(text: " !")
              else
                const TextSpan(text: "..."),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildMovementControls(isActive: isActive),
      ],
    );
  }

  Widget _buildMovementControls({required bool isActive}) {
    if (!isActive) return const SizedBox();
    return Column(
      children: [
        Dungeon7x7(
          mapObjects: widget.fullMapObjects,
          playerX: widget.playerX,
          playerY: widget.playerY,
          playerOrientation: widget.playerOrientation,
          cellSize: 40.0,
          stepMessage: '',
        ),
        const SizedBox(height: 16),
        if (widget.validMoves['canMoveForward'] == true)
          AppTheme.customButton(
            label: 'Tout droit',
            onPressed: () => widget.gameService.movePlayer(widget.gameId, widget.playerId, 'forward'),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.validMoves['canMoveLeft'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AppTheme.customButton(
                  label: 'Gauche',
                  onPressed: () => widget.gameService.movePlayer(widget.gameId, widget.playerId, 'left'),
                ),
              ),
            if (widget.validMoves['canMoveRight'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AppTheme.customButton(
                  label: 'Droite',
                  onPressed: () => widget.gameService.movePlayer(widget.gameId, widget.playerId, 'right'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // VUES ACTIF vs PASSIF
  // ----------------------------------------------------------------
  Widget _buildActivePlayerView() {
    final cat = widget.cardCategory;
    if (cat == 'Quiz') return _buildQuizActiveView();
    if (cat == 'Challenge') return _buildChallengeActiveView();
    if (cat == 'Object') return _buildObjectActiveView();
    return _buildDefaultActiveView();
  }

  Widget _buildPassivePlayerView() {
    final cat = widget.cardCategory;
    if (cat == 'Quiz') return _buildQuizPassiveView();
    if (cat == 'Challenge') return _buildChallengePassiveView();
    if (cat == 'Object') return _buildObjectPassiveView();
    return _buildDefaultPassiveView();
  }

  // ----------------------------------------------------------------
  // QUIZ : ACTIF
  // ----------------------------------------------------------------
  Widget _buildQuizActiveView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    switch (widget.turnState) {
      case 'movement':
      case 'drawStep':
        return _buildMovementView(isActive: true);

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            SizedBox(height: screenHeight * 0.02),
            if (!widget.isQuizInProgress) ...[
              if (_selectedQuizTheme == null) ...[
                if (widget.quizThemes.isNotEmpty) ...[
                  Text('Choisissez un thème:', style: AppTheme.themeData.textTheme.bodyMedium, textAlign: TextAlign.center),
                  SizedBox(height: screenHeight * 0.005),
                  for (var theme in widget.quizThemes)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.001),
                      child: SizedBox(
                        width: screenWidth * 0.5,
                        child: AppTheme.customButton(
                          label: theme,
                          onPressed: () => setState(() => _selectedQuizTheme = theme),
                        ),
                      ),
                    ),
                ],
              ] else ...[
                Text('Choisissez la difficulté:', style: AppTheme.themeData.textTheme.bodyMedium, textAlign: TextAlign.center),
                SizedBox(height: screenHeight * 0.01),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isLoadingQuizQuestion = true);
                          widget.gameService.startQuiz(
                              widget.gameId, widget.playerId, _selectedQuizTheme!, "Débutant");
                          setState(() => _selectedQuizTheme = null);
                        },
                        child: Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenHeight * 0.005),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
                            ],
                          ),
                          child: Column(
                            children: [
                              Text("Débutant", style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.045)),
                              SizedBox(height: screenHeight * 0.005),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.star, color: AppTheme.accentYellow),
                                  Icon(Icons.star_border, color: AppTheme.accentYellow),
                                  Icon(Icons.star_border, color: AppTheme.accentYellow),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isLoadingQuizQuestion = true);
                          widget.gameService.startQuiz(widget.gameId, widget.playerId, _selectedQuizTheme!, "Expert");
                          setState(() => _selectedQuizTheme = null);
                        },
                        child: Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenHeight * 0.005),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
                            ],
                          ),
                          child: Column(
                            children: [
                              Text("Expert", style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.045)),
                              SizedBox(height: screenHeight * 0.005),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.star, color: AppTheme.accentYellow),
                                  Icon(Icons.star, color: AppTheme.accentYellow),
                                  Icon(Icons.star, color: AppTheme.accentYellow),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else if (widget.isQuizInProgress && _quizCurrentIndex == null)
              Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: const CircularProgressIndicator(),
              )
            else
              // Quiz en cours => question
              _buildQuizQuestionView(isActive: true),
          ],
        );

      case 'quizResult':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _activeQuizResultMessage ?? "Résultat inconnu...",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: "Terminer le tour",
              onPressed: () => widget.gameService.endTurn(widget.gameId),
            ),
          ],
        );

      default:
        if (widget.isQuizInProgress) {
          return _buildQuizQuestionView(isActive: true);
        }
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // QUIZ : PASSIF
  // ----------------------------------------------------------------
  Widget _buildQuizPassiveView() {
    final screenHeight = MediaQuery.of(context).size.height;

    switch (widget.turnState) {
      case 'movement':
        return _buildMovementView(isActive: false);

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            Text(
              "Ce quiz est pour ${widget.activePlayerName}, mais tu peux tenter d'y répondre pour te faire remarquer des dieux.",
              style: AppTheme.themeData.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "${widget.activePlayerName ?? '???'} doit d'abord choisir un thème. Sois prêt !",
              style: AppTheme.themeData.textTheme.bodySmall,
              textAlign: TextAlign.center,
            )
          ],
        );

      case 'quizResult':
        // Affichage des résultats de l'actif + du passif
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              // Au lieu de "widget.quizCorrectAnswers", on utilise la variable locale
              _buildPassiveActiveResultMessage(_quizDifficulty, widget.activePlayerName ?? "???", 
                _localActivePlayerCorrectAnswers,
              ),
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _nonActiveQuizResultMessage ?? '???',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: "Terminer le tour",
              onPressed: () => widget.gameService.endTurn(widget.gameId),
            ),
          ],
        );

      default:
        if (widget.isQuizInProgress) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "C'est à ${widget.activePlayerName ?? '???'} de répondre à la question !",
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Autorise aussi le passif à cliquer
              _buildQuizQuestionView(isActive: true),
            ],
          );
        }
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // CHALLENGE : ACTIF
  // ----------------------------------------------------------------
  Widget _buildChallengeActiveView() {
    switch (widget.turnState) {
      case 'movement':
      case 'drawStep':
        return _buildMovementView(isActive: true);

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: 'Start the challenge',
              onPressed: () => widget.gameService.startBetting(widget.gameId, widget.playerId),
            ),
          ],
        );

      case 'betting':
        return Text(
          "Other players are making their predictions...",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );

      case 'challengeInProgress':
        return Text(
          "Challenge in progress... Show us what you're capable of !",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );

      case 'result':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Challenge results : ${widget.majorityVote ?? "No result"}',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: "End the turn",
              onPressed: () => widget.gameService.endTurn(widget.gameId),
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // CHALLENGE : PASSIF
  // ----------------------------------------------------------------
  Widget _buildChallengePassiveView() {
    switch (widget.turnState) {
      case 'movement':
        return _buildMovementView(isActive: false);

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            Text(
              "${widget.activePlayerName} choisit un thème...",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        );

      case 'betting':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            Text(
              "Tentez de deviner si ${widget.activePlayerName} réussira ou non son challenge. A vos paris !",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...widget.betOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: AppTheme.customButton(
                  label: option,
                  onPressed: () => widget.gameService.placeBet(widget.gameId, widget.playerId, option),
                ),
              );
            }).toList(),
          ],
        );

      case 'challengeInProgress':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Challenge en cours. Une fois que ${widget.activePlayerName} déclare avoir fini, vous devez évaluer sa prestation.",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Comment ${widget.activePlayerName} a-t-il performé ?",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...widget.betOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: AppTheme.customButton(
                  label: option,
                  onPressed: () => widget.gameService.placeChallengeVote(widget.gameId, widget.playerId, option),
                ),
              );
            }).toList(),
          ],
        );

      case 'result':
        return Text(
          "Résultats du challenge : ${widget.majorityVote ?? "Aucun résultat"}",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );

      default:
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // OBJECT : ACTIF
  // ----------------------------------------------------------------
  Widget _buildObjectActiveView() {
    switch (widget.turnState) {
      case 'movement':
      case 'drawStep':
        return _buildMovementView(isActive: true);

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: 'Ramasser',
              onPressed: () {
                widget.gameService.pickUpObject(widget.gameId, widget.playerId);
                widget.gameService.endTurn(widget.gameId);
              },
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // OBJECT : PASSIF
  // ----------------------------------------------------------------
  Widget _buildObjectPassiveView() {
    switch (widget.turnState) {
      case 'movement':
        return _buildMovementView(isActive: false);

      case 'cardDrawn':
        return _buildCardDisplay();

      default:
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // FALLBACK : ACTIF
  // ----------------------------------------------------------------
  Widget _buildDefaultActiveView() {
    switch (widget.turnState) {
      case 'movement':
      case 'drawStep':
        return _buildMovementView(isActive: true);

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: 'Terminer le tour',
              onPressed: () => widget.gameService.endTurn(widget.gameId),
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // FALLBACK : PASSIF
  // ----------------------------------------------------------------
  Widget _buildDefaultPassiveView() {
    switch (widget.turnState) {
      case 'movement':
        return _buildMovementView(isActive: false);

      case 'cardDrawn':
        return _buildCardDisplay();

      default:
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // AFFICHAGE DE LA QUESTION DE QUIZ
  // ----------------------------------------------------------------
  Widget _buildQuizQuestionView({required bool isActive}) {
    if (_quizCurrentIndex == null) {
      return Text(
        "Chargement de la question...",
        style: AppTheme.themeData.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      );
    }
    return _ActiveQuizQuestionWidget(
      key: ValueKey<int>(_quizCurrentIndex!),
      gameId: widget.gameId,
      playerId: widget.playerId,
      gameService: widget.gameService,
      questionIndex: _quizCurrentIndex!,
      questionDescription: _quizCurrentDescription ?? '',
      questionOptions: _quizCurrentOptions ?? [],
      questionImage: _quizCurrentImage,
      questionCategory: _quizCurrentCategory,
      questionDifficulty: _quizCurrentDifficulty ?? 1,
      correctAnswer: widget.quizCorrectAnswer,
      wasAnswerCorrect: widget.quizWasAnswerCorrect,
      isAnswerable: isActive,
      onSendAnswer: (String chosenOption) {
        widget.gameService.quizAnswer(widget.gameId, widget.playerId, chosenOption);
      },
    );
  }

  // ----------------------------------------------------------------
  // AFFICHAGE CARTE
  // ----------------------------------------------------------------
  Widget _buildCardDisplay() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.cardName != null)
          Text(
            widget.cardName!,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w100,
                  fontSize: screenWidth * 0.08,
                ),
            textAlign: TextAlign.center,
          ),
        SizedBox(height: screenHeight * 0.005),
        if (widget.cardSubheading != null)
          Center(
            child: Text(
              widget.cardSubheading!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.normal,
                fontFamily: 'PermanentMarker',
                color: AppTheme.subtitleWhite,
                shadows: const [
                  Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(2, 2)),
                ],
              ),
            ),
          ),
        SizedBox(height: screenHeight * 0.01),
        if (widget.cardImage != null)
          Padding(
            padding: EdgeInsets.only(bottom: screenHeight * 0.02),
            child: SizedBox(
              height: screenHeight * 0.2,
              child: Image.asset('assets/images/${widget.cardImage}', fit: BoxFit.contain),
            ),
          ),
        SizedBox(height: screenHeight * 0.005),
        if (widget.cardDescription != null)
          TypewriterBubble(
            text: widget.cardDescription!,
            defaultStyle: TextStyle(
              fontSize: screenWidth * 0.035,
              color: AppTheme.primaryColor,
              fontFamily: 'Nunito',
              fontStyle: FontStyle.italic,
            ),
            boldStyle: TextStyle(
              fontSize: screenWidth * 0.035,
              color: AppTheme.primaryColor,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.normal,
            ),
          ),
      ],
    );
  }

  // Ajout d'un suffixe ordinal
  String _rankSuffix(int rank) {
    if (rank == 1) return "1er";
    if (rank == 2) return "2ème";
    if (rank == 3) return "3ème";
    return "${rank}ème";
  }
}

// ----------------------------------------------------------------
// Widget gérant l'affichage d'une question de quiz + Timer
// ----------------------------------------------------------------
class _ActiveQuizQuestionWidget extends StatefulWidget {
  final String gameId;
  final String playerId;
  final GameService gameService;

  final int questionIndex;
  final String questionDescription;
  final List<dynamic> questionOptions;
  final String? questionImage;
  final String? questionCategory;
  final int questionDifficulty;

  final String? correctAnswer;
  final bool? wasAnswerCorrect;
  final bool isAnswerable;

  final void Function(String chosenOption) onSendAnswer;

  const _ActiveQuizQuestionWidget({
    Key? key,
    required this.gameId,
    required this.playerId,
    required this.gameService,
    required this.questionIndex,
    required this.questionDescription,
    required this.questionOptions,
    this.questionImage,
    this.questionCategory,
    required this.questionDifficulty,
    this.correctAnswer,
    this.wasAnswerCorrect,
    required this.isAnswerable,
    required this.onSendAnswer,
  }) : super(key: key);

  @override
  State<_ActiveQuizQuestionWidget> createState() => _ActiveQuizQuestionWidgetState();
}

class _ActiveQuizQuestionWidgetState extends State<_ActiveQuizQuestionWidget> {
  int _timeLeft = 10;
  Timer? _timer;
  bool _hasAnswered = false;
  String? _chosenOption;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  void _startTimer() {
    _timeLeft = 10;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _timer?.cancel();
          _handleTimeOut();
        }
      });
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _handleTimeOut() {
    if (!_hasAnswered) {
      widget.onSendAnswer("TIMED_OUT");
      setState(() {
        _hasAnswered = true;
        _chosenOption = "TIMED_OUT";
      });
    }
  }

  void _handleOptionClick(String option) {
    if (!_hasAnswered && widget.isAnswerable) {
      setState(() {
        _hasAnswered = true;
        _chosenOption = option;
      });
      _cancelTimer();
      widget.onSendAnswer(option);
    }
  }

  Widget _buildDifficultyStars(int difficulty) {
    final stars = <Widget>[];
    for (int i = 0; i < 3; i++) {
      if (i < difficulty) {
        stars.add(const Icon(Icons.star, color: AppTheme.accentYellow));
      } else {
        stars.add(const Icon(Icons.star_border, color: AppTheme.accentYellow));
      }
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: stars);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final questionNumber = widget.questionIndex + 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDifficultyStars(widget.questionDifficulty),
        const SizedBox(height: 8),
        Text("Question $questionNumber", style: AppTheme.themeData.textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text("$_timeLeft s", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        if (widget.questionDescription.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(widget.questionDescription, style: AppTheme.themeData.textTheme.bodyMedium, textAlign: TextAlign.center),
          ),
        if (widget.questionImage != null && widget.questionImage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Image.asset('assets/images/${widget.questionImage}', fit: BoxFit.contain, height: 180),
          ),
        for (var option in widget.questionOptions) _buildAnswerButton(option.toString()),
      ],
    );
  }

  Widget _buildAnswerButton(String option) {
    final screenWidth = MediaQuery.of(context).size.width;

    Color btnColor = AppTheme.primaryColor;
    if (_hasAnswered && option == _chosenOption) {
      if (widget.wasAnswerCorrect == true && _chosenOption != "TIMED_OUT") {
        btnColor = AppTheme.correctGreen;
      } else {
        btnColor = AppTheme.incorrectRed;
      }
    }
    final canClick = !_hasAnswered && widget.isAnswerable;

    return Container(
      margin: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
      child: SizedBox(
        width: screenWidth * 0.8,
        child: AppTheme.customButton(
          label: option,
          backgroundColor: btnColor,
          onPressed: canClick ? () => _handleOptionClick(option) : null,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
//  Typewriter effect
// ----------------------------------------------------------------
class TypewriterBubble extends StatefulWidget {
  final String text;
  final TextStyle? defaultStyle;
  final TextStyle? boldStyle;
  final Duration speed;

  const TypewriterBubble({
    Key? key,
    required this.text,
    this.defaultStyle,
    this.boldStyle,
    this.speed = const Duration(milliseconds: 30),
  }) : super(key: key);

  @override
  _TypewriterBubbleState createState() => _TypewriterBubbleState();
}

class _TextSegment {
  final String text;
  final bool isBold;
  _TextSegment(this.text, this.isBold);
}

class _TypewriterBubbleState extends State<TypewriterBubble> {
  late List<_TextSegment> _segments;
  int _totalLength = 0;
  int _currentLength = 0;
  Timer? _timer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _parseAndStart();
  }

  @override
  void didUpdateWidget(TypewriterBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _parseAndStart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _parseAndStart() {
    _segments = _parseText(widget.text);
    _totalLength = _segments.fold(0, (sum, seg) => sum + seg.text.length);
    _currentLength = 0;
    _completed = false;
    _startTypewriter();
  }

  List<_TextSegment> _parseText(String text) {
    final segments = <_TextSegment>[];
    final parts = text.split('"');
    for (int i = 0; i < parts.length; i++) {
      segments.add(_TextSegment(parts[i], i % 2 == 1));
    }
    return segments;
  }

  void _startTypewriter() {
    _timer = Timer.periodic(widget.speed, (timer) {
      if (!mounted) return;
      if (_currentLength < _totalLength) {
        setState(() => _currentLength++);
      } else {
        timer.cancel();
        setState(() => _completed = true);
      }
    });
  }

  void _completeText() {
    _timer?.cancel();
    setState(() {
      _currentLength = _totalLength;
      _completed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = widget.defaultStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic);
    final boldStyle = widget.boldStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontStyle: FontStyle.normal);

    int remaining = _currentLength;
    final spans = <TextSpan>[];
    for (final seg in _segments) {
      if (remaining <= 0) break;
      String segText;
      if (remaining >= seg.text.length) {
        segText = seg.text;
        remaining -= seg.text.length;
      } else {
        segText = seg.text.substring(0, remaining);
        remaining = 0;
      }
      spans.add(TextSpan(text: segText, style: seg.isBold ? boldStyle : defaultStyle));
    }

    return GestureDetector(
      onTap: () {
        if (!_completed) _completeText();
      },
      child: Container(
        constraints: BoxConstraints.tight(Size(MediaQuery.of(context).size.width * 0.85,
            MediaQuery.of(context).size.height * 0.18)),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(children: spans),
        ),
      ),
    );
  }
}
