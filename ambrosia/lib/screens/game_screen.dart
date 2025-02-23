// lib/screens/game_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';

class GameScreen extends StatelessWidget {
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

  final List<String> betOptions;
  final String? majorityVote;

  // Quiz
  final bool isQuizInProgress;
  final List<String> quizThemes;
  final int? quizCurrentIndex;
  final String? quizCurrentDescription;
  final String? quizCurrentCategory;
  final String? quizCurrentImage;
  final List<dynamic> quizCurrentOptions;
  final bool? quizWasAnswerCorrect;
  final String? quizCorrectAnswer;
  final int quizCorrectAnswers;
  final int quizTotalQuestions;
  final int quizEarnedBerries;

  // Mouvements possibles
  final Map<String, bool> validMoves;

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
    required this.betOptions,
    this.majorityVote,
    required this.isQuizInProgress,
    required this.quizThemes,
    this.quizCurrentIndex,
    this.quizCurrentDescription,
    this.quizCurrentCategory,
    this.quizCurrentImage,
    required this.quizCurrentOptions,
    this.quizWasAnswerCorrect,
    this.quizCorrectAnswer,
    required this.quizCorrectAnswers,
    required this.quizTotalQuestions,
    required this.quizEarnedBerries,
    required this.validMoves,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // 1) background
        Container(decoration: AppTheme.backgroundDecoration()),

        // 2) "About you" en haut à gauche
        Positioned(
          top: screenHeight * 0.06,
          left: MediaQuery.of(context).size.width * 0.04,
          child: _buildYourInfo(context),
        ),

        // 3) Info joueur actif en haut à droite
        Positioned(
          top: screenHeight * 0.06,
          right: MediaQuery.of(context).size.width * 0.04,
          child: _buildActivePlayerInfo(context),
        ),

        // 4) Contenu principal (centré + scrollable)
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              top: screenHeight * 0.20,
              left: MediaQuery.of(context).size.width * 0.03,
              right: MediaQuery.of(context).size.width * 0.03,
              bottom: screenHeight * 0.08,
            ),
            child: SingleChildScrollView(
              child: isPlayerActive
                  ? _buildActivePlayerView()
                  : _buildPassivePlayerView(),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // 1) Header / About you
  // ----------------------------------------------------------------
  Widget _buildYourInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = screenWidth * 0.18;
    final maxBerries = 30; // ou la valeur voulue
    final rankStr = "${_rankSuffix(myRank)} out of $totalPlayers";

    return SizedBox(
      width: circleSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "About you:",
            textAlign: TextAlign.center,
            style: AppTheme.topLabelStyle(context, 0.03),
          ),
          const SizedBox(height: 4),
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.darkerGreen,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$myBerries/$maxBerries",
                  style: AppTheme.circleNumberStyle(circleSize),
                ),
                SizedBox(height: circleSize * 0.05),
                Image.asset(
                  'assets/images/berry1.png',
                  width: circleSize * 0.25,
                  height: circleSize * 0.22,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rankStr,
            textAlign: TextAlign.center,
            style: AppTheme.rankStyle(context, 0.03),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 2) Header / Joueur actif
  // ----------------------------------------------------------------
  Widget _buildActivePlayerInfo(BuildContext context) {
    final circleSize = MediaQuery.of(context).size.width * 0.18;

    // Décode l'avatar base64 du joueur actif
    Widget avatarWidget;
    if (activePlayerAvatar != null && activePlayerAvatar!.isNotEmpty) {
      final bytes = base64Decode(activePlayerAvatar!);
      avatarWidget = CircleAvatar(
        radius: circleSize * 0.5,
        backgroundImage: MemoryImage(bytes),
      );
    } else {
      // Icône par défaut
      avatarWidget = Icon(
        Icons.person,
        size: circleSize * 0.5,
        color: AppTheme.darkerGreen,
      );
    }

    return SizedBox(
      width: circleSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Turn:",
            textAlign: TextAlign.center,
            style: AppTheme.topLabelStyle(context, 0.03),
          ),
          const SizedBox(height: 4),
          SizedBox(width: circleSize, height: circleSize, child: avatarWidget),
          const SizedBox(height: 4),
          Text(
            "${activePlayerName ?? '???'} is playing",
            textAlign: TextAlign.center,
            style: AppTheme.topLabelStyle(context, 0.03),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 3) Corps principal
  // ----------------------------------------------------------------
  Widget _buildActivePlayerView() {
    if (cardCategory == 'Quiz') {
      return _buildQuizActiveView();
    } else if (cardCategory == 'Challenge') {
      return _buildChallengeActiveView();
    } else if (cardCategory == 'Object') {
      return _buildObjectActiveView();
    } else {
      return _buildDefaultActiveView();
    }
  }

  Widget _buildPassivePlayerView() {
    if (cardCategory == 'Quiz') {
      return _buildQuizPassiveView();
    } else if (cardCategory == 'Challenge') {
      return _buildChallengePassiveView();
    } else if (cardCategory == 'Object') {
      return _buildObjectPassiveView();
    } else {
      return _buildDefaultPassiveView();
    }
  }

  // ----------------------------------------------------------------
  // 4) CHALLENGE
  // ----------------------------------------------------------------
  Widget _buildChallengeActiveView() {
    switch (turnState) {
      case 'movement':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "It's your turn ! Please continue in the forest.",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildMovementControls(),
          ],
        );
      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: 'Start the challenge',
              onPressed: () => gameService.startBetting(gameId, playerId),
            ),
          ],
        );
      case 'betting':
        return Text(
          'Other players are making their predictions...',
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );
      case 'challengeInProgress':
        return Text(
          "Challenge in progress... Show us what you're capable of!",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );
      case 'result':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Challenge results : ${majorityVote ?? "No result"}',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: "End the turn",
              onPressed: () => gameService.endTurn(gameId),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildChallengePassiveView() {
    switch (turnState) {
      case 'movement':
        return Text(
          "$activePlayerName is moving in the forest...",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );
      case 'cardDrawn':
        return _buildCardDisplay();
      case 'betting':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            Text(
              'Make your predictions:',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...betOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: AppTheme.customButton(
                  label: option,
                  onPressed: () => gameService.placeBet(gameId, playerId, option),
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
              'Challenge in progress. Once $activePlayerName is done, we must judge the success.',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'How well did $activePlayerName succeed ?',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...betOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: AppTheme.customButton(
                  label: option,
                  onPressed: () => gameService.placeChallengeVote(gameId, playerId, option),
                ),
              );
            }).toList(),
          ],
        );
      case 'result':
        return Text(
          'Challenge results : ${majorityVote ?? "No result"}',
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );
      default:
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // 5) QUIZ
  // ----------------------------------------------------------------
  Widget _buildQuizActiveView() {
    switch (turnState) {
      case 'movement':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "It's your turn ! Please continue in the forest.",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildMovementControls(),
          ],
        );
      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            if (!isQuizInProgress) ...[
              if (quizThemes.isNotEmpty) ...[
                Text(
                  'Choose your quiz theme:',
                  style: AppTheme.themeData.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                for (var theme in quizThemes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: AppTheme.customButton(
                      label: theme,
                      onPressed: () => gameService.startQuiz(gameId, playerId, theme),
                    ),
                  ),
              ],
            ] else
              _buildQuizQuestionView(isActive: true),
          ],
        );
      case 'quizResult':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Quiz results: $quizCorrectAnswers / $quizTotalQuestions',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              // Visible seulement pour le joueur actif
              'Berries earned: $quizEarnedBerries',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppTheme.customButton(
              label: "End the turn",
              onPressed: () => gameService.endTurn(gameId),
            ),
          ],
        );
      default:
        // Si c'est un quiz en cours
        if (isQuizInProgress) {
          return _buildQuizQuestionView(isActive: true);
        }
        return const SizedBox();
    }
  }

  Widget _buildQuizPassiveView() {
    switch (turnState) {
      case 'movement':
        return Text(
          "$activePlayerName is moving in the forest...",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );
      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            Text(
              "$activePlayerName is choosing a quiz theme...",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 'quizResult':
        // Chez les passifs, on affiche juste correctAnswers / total
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Quiz results: $quizCorrectAnswers / $quizTotalQuestions',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            // On ne montre pas "Berries earned" ici
          ],
        );
      default:
        // Quiz en cours => on montre la question ET un label "It's up to X..."
        if (isQuizInProgress) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "It's up to ${activePlayerName ?? '???'} to answer the question!",
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildQuizQuestionView(isActive: false),
            ],
          );
        }
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // 6) OBJET
  // ----------------------------------------------------------------
  Widget _buildObjectActiveView() {
    switch (turnState) {
      case 'movement':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "It's your turn ! Please continue in the forest.",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildMovementControls(),
          ],
        );
      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: 'Ramasser',
              onPressed: () {
                // 1) Ramasser l’objet => pickUpObject
                gameService.pickUpObject(gameId, playerId);

                // 2) Mettre fin au tour immédiatement
                gameService.endTurn(gameId);
              },
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildObjectPassiveView() {
    switch (turnState) {
      case 'movement':
        return Text(
          "$activePlayerName is moving in the forest...",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );
      case 'cardDrawn':
        // Le joueur actif voit le bouton "Ramasser",
        // les passifs voient juste la carte
        return _buildCardDisplay();
      default:
        return const SizedBox();
    }
  }

  // ---------------------------------------------------------------------
  // Affichage question/choix (QUIZ)
  // ---------------------------------------------------------------------
  Widget _buildQuizQuestionView({required bool isActive}) {
    if (quizCurrentIndex == null) {
      return Text(
        "Loading question...",
        style: AppTheme.themeData.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      );
    }
    // On force la recréation du widget quand quizCurrentIndex change
    return _ActiveQuizQuestionWidget(
      key: ValueKey<int>(quizCurrentIndex!),
      gameId: gameId,
      playerId: playerId,
      gameService: gameService,
      questionIndex: quizCurrentIndex!,
      questionDescription: quizCurrentDescription ?? '',
      questionOptions: quizCurrentOptions,
      questionImage: quizCurrentImage,
      questionCategory: quizCurrentCategory,
      correctAnswer: quizCorrectAnswer,
      wasAnswerCorrect: quizWasAnswerCorrect,
      isAnswerable: isActive && quizWasAnswerCorrect == null,
      onSendAnswer: (String chosenOption) {
        gameService.quizAnswer(gameId, playerId, chosenOption);
      },
    );
  }

  // ----------------------------------------------------------------
  // 7) Logique "Default" (aucune carte spéciale)
  // ----------------------------------------------------------------
  Widget _buildDefaultActiveView() {
    switch (turnState) {
      case 'movement':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "It's your turn. Move!",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildMovementControls(),
          ],
        );
      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardDisplay(),
            const SizedBox(height: 16),
            AppTheme.customButton(
              label: 'End the turn',
              onPressed: () => gameService.endTurn(gameId),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildDefaultPassiveView() {
    switch (turnState) {
      case 'movement':
        return Text(
          "$activePlayerName is moving in the forest...",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );
      case 'cardDrawn':
        return _buildCardDisplay();
      default:
        return const SizedBox();
    }
  }

  // ----------------------------------------------------------------
  // 8) Boutons de déplacement
  // ----------------------------------------------------------------
  Widget _buildMovementControls() {
    if (!isPlayerActive) return const SizedBox();
    return Column(
      children: [
        if (validMoves['canMoveForward'] == true)
          AppTheme.customButton(
            label: 'Move forward',
            onPressed: () =>
                gameService.movePlayer(gameId, playerId, 'forward'),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (validMoves['canMoveLeft'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AppTheme.customButton(
                  label: 'Left',
                  onPressed: () =>
                      gameService.movePlayer(gameId, playerId, 'left'),
                ),
              ),
            if (validMoves['canMoveRight'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AppTheme.customButton(
                  label: 'Right',
                  onPressed: () =>
                      gameService.movePlayer(gameId, playerId, 'right'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // 9) Affichage de la carte
  // ----------------------------------------------------------------
  Widget _buildCardDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cardName != null)
          Text(
            cardName!,
            style: const TextStyle(
              fontSize: 24,
              color: AppTheme.greenButton,
              fontWeight: FontWeight.bold,
              fontFamily: 'Nunito',
            ),
            textAlign: TextAlign.center,
          ),
        if (cardDescription != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              cardDescription!,
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.greenButton,
                fontFamily: 'Nunito',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (cardImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: SizedBox(
              height: 200, // ajustez selon vos besoins
              child: Image.asset(
                'assets/images/$cardImage',
                fit: BoxFit.contain,
              ),
            ),
          ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // 10) Utilitaires
  // ----------------------------------------------------------------
  String _rankSuffix(int rank) {
    if (rank == 1) return "1st";
    if (rank == 2) return "2nd";
    if (rank == 3) return "3rd";
    return "${rank}th";
  }
}

// ---------------------------------------------------------------------
// WIDGET ÉTATFUL : _ActiveQuizQuestionWidget
// Gère :
//  - Timer de 10s (reset à chaque questionIndex),
//  - Envoi auto d'une mauvaise réponse si time-out,
//  - Coloration rouge/vert du bouton cliqué.
// ---------------------------------------------------------------------
class _ActiveQuizQuestionWidget extends StatefulWidget {
  final String gameId;
  final String playerId;
  final GameService gameService;

  final int questionIndex;
  final String questionDescription;
  final List<dynamic> questionOptions;
  final String? questionImage;
  final String? questionCategory;

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
    this.correctAnswer,
    this.wasAnswerCorrect,
    required this.isAnswerable,
    required this.onSendAnswer,
  }) : super(key: key);

  @override
  State<_ActiveQuizQuestionWidget> createState() =>
      _ActiveQuizQuestionWidgetState();
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
    if (!widget.isAnswerable || _hasAnswered) return;
    _cancelTimer();
    setState(() {
      _hasAnswered = true;
      _chosenOption = option;
    });
    widget.onSendAnswer(option);
  }

  @override
  Widget build(BuildContext context) {
    final questionNumber = widget.questionIndex + 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Question $questionNumber",
          style: AppTheme.themeData.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          "$_timeLeft s",
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),

        if (widget.questionDescription.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              widget.questionDescription,
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),

        if (widget.questionImage != null && widget.questionImage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Image.asset(
              'assets/images/${widget.questionImage}',
              fit: BoxFit.contain,
              height: 180,
            ),
          ),

        for (var option in widget.questionOptions)
          _buildAnswerButton(option.toString()),
      ],
    );
  }

  Widget _buildAnswerButton(String option) {
    // Couleur par défaut
    Color btnColor = AppTheme.greenButton;

    // Si une réponse a été donnée (manuelle ou timeout) et qu'on sait si c'est correct
    if (_hasAnswered && widget.correctAnswer != null) {
      if (option == _chosenOption) {
        // Si c'est la bonne réponse
        if (widget.wasAnswerCorrect == true) {
          btnColor = AppTheme.correctGreen; // Vert si correct
        } else {
          btnColor = AppTheme.incorrectRed; // Rouge si faux
        }
      } else if (option == widget.correctAnswer) {
        // Affiche la bonne réponse en vert si différent du chosenOption
        btnColor = AppTheme.correctGreen;
      }
    }

    final canClick = widget.isAnswerable && !_hasAnswered;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: AppTheme.customButton(
        label: option,
        backgroundColor: btnColor,
        onPressed: canClick ? () => _handleOptionClick(option) : null,
      ),
    );
  }
}
