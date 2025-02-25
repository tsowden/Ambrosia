// lib/screens/game_home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../screens/game_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/quest_screen.dart';
import '../styles/app_theme.dart';

class GameHomeScreen extends StatefulWidget {
  final String gameId;
  final String playerName;
  final String playerId;
  final GameService gameService;
  final Map<String, dynamic> initialData;

  const GameHomeScreen({
    Key? key,
    required this.gameId,
    required this.playerName,
    required this.playerId,
    required this.gameService,
    required this.initialData,
  }) : super(key: key);

  @override
  _GameHomeScreenState createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen> {
  // ----------------------------------------------------
  // BOTTOM NAV
  // ----------------------------------------------------
  int _currentIndex = 0; // 0 => Game, 1 => Inventory, 2 => Quest, 3 => Quit

  // ----------------------------------------------------
  // ÉTATS DU TOUR / JOUEUR
  // ----------------------------------------------------
  String _turnState = 'movement';
  bool _isPlayerActive = false;

  // ----------------------------------------------------
  // INFOS PERSO (baies, rang, avatar, etc.)
  // ----------------------------------------------------
  int _myBerries = 0;
  int _myRank = 1;
  int _totalPlayers = 1;
  String? _myAvatarBase64;

  // ----------------------------------------------------
  // INFOS DU JOUEUR ACTIF
  // ----------------------------------------------------
  String? _activePlayerName;
  String? _activePlayerAvatar;

  // ----------------------------------------------------
  // CARTE PIOCHÉE
  // ----------------------------------------------------
  String? _cardName;
  String? _cardImage;
  String? _cardDescription;
  String? _cardCategory;
  List<String> _betOptions = [];
  String? _majorityVote;

  // ----------------------------------------------------
  // QUIZ
  // ----------------------------------------------------
  bool _isQuizInProgress = false;
  List<String> _quizThemes = [];
  int? _quizCurrentIndex;
  String? _quizCurrentDescription;
  String? _quizCurrentCategory;
  String? _quizCurrentImage;
  List<dynamic> _quizCurrentOptions = [];
  bool? _quizWasAnswerCorrect;
  String? _quizCorrectAnswer;
  int _quizCorrectAnswers = 0;
  int _quizTotalQuestions = 0;
  int _quizEarnedBerries = 0;
  Timer? _quizTimer;
  int _timeLeft = 10; // on veut 10 secondes

  // ----------------------------------------------------
  // MOUVEMENTS POSSIBLES
  // ----------------------------------------------------
  Map<String, bool> _validMoves = {
    'canMoveForward': false,
    'canMoveLeft': false,
    'canMoveRight': false,
  };

  // ----------------------------------------------------
  // VARIABLES POUR POSITION/ORIENTATION + SNIPPET
  // ----------------------------------------------------
  int _playerX = 0;
  int _playerY = 0;
  String _playerOrientation = 'south'; // ou n'importe quelle valeur par défaut
  Map<String,int> _localMapSnippet = {
    'me': -1,
    'f1': -1,
    'f2': -1,
    'left': -1,
    'right': -1,
  };

  // ----------------------------------------------------
  // GESTION DES MESSAGES ÉPHÉMÈRES (comme l'ancien code)
  // ----------------------------------------------------
  List<bool> _slotsOccupied = [false, false, false, false];
  Map<String, String> _playerMessages = {};
  double _messageOpacity = 0.0;

  List<Map<String, dynamic>> _initialInventory = [];

  @override
  void initState() {
    super.initState();
    widget.gameService.connectToGame(widget.gameId);

    // On configure nos listeners
    _setupSocketListeners();

    // On traite les données initiales
    _handleInitialData(widget.initialData);
  }

  // ----------------------------------------------------
  // 1) RESET quand un nouveau tour commence
  //    (Comme dans le code "old" qui appelait _handleNewTurn)
  // ----------------------------------------------------
  void _resetForNewTurn(Map<String, dynamic> data) {
    setState(() {
      // Récupère le joueur actif
      _activePlayerName = data['activePlayerName'];
      _turnState = data['turnState'] ?? 'movement';
      _isPlayerActive = (_activePlayerName?.trim().toLowerCase() ==
                         widget.playerName.trim().toLowerCase());

      // Comme dans l'ancien code: on reset
      _cardName = null;
      _cardImage = null;
      _cardDescription = null;
      _cardCategory = null;
      _betOptions = [];
      _majorityVote = null;

      // Quiz
      _isQuizInProgress = false;
      _quizThemes = [];
      _quizCurrentIndex = null;
      _quizCurrentDescription = null;
      _quizCurrentCategory = null;
      _quizCurrentImage = null;
      _quizCurrentOptions = [];
      _quizWasAnswerCorrect = null;
      _quizCorrectAnswer = null;
      _quizCorrectAnswers = 0;
      _quizTotalQuestions = 0;
      _quizEarnedBerries = 0;

      // Si c'est mon tour et qu'on est en phase 'movement', je récupère mes moves
      if (_isPlayerActive && _turnState == 'movement') {
        widget.gameService.getValidMoves(widget.gameId, widget.playerId, (moves) {
          setState(() {
            _validMoves = moves;
          });
        });
      }
    });
  }

  // ----------------------------------------------------
  // 2) TRAITEMENT DES DONNÉES INITIALES
  // ----------------------------------------------------
  void _handleInitialData(Map<String, dynamic> data) {
    // Similaire à l'ancien _handleNewTurn
    // + mise à jour de mes stats / rank
    final playersData = data['players'] ?? [];
    if (playersData is List) {
      _totalPlayers = playersData.length;

      final me = playersData.firstWhere(
        (p) => p['playerId'] == widget.playerId,
        orElse: () => null,
      );
      if (me != null) {
        _myBerries = me['berries'] ?? 0;
        _myRank = me['rank'] ?? 1;
        _myAvatarBase64 = me['avatarBase64'] ?? '';
        _initialInventory = List<Map<String, dynamic>>.from(me['inventory'] ?? []);
      }
    }
    // On fait comme si c'était un "nouveau tour" => on reset tout
    _resetForNewTurn(data);
  }

  // ----------------------------------------------------
  // 3) SOCKET LISTENERS
  // ----------------------------------------------------
  void _setupSocketListeners() {
    final gs = widget.gameService;

    // a) onGameInfos => mise à jour de la liste de joueurs
    gs.onGameInfos((data) {
      final playersData = data['players'] ?? [];
      if (playersData is List) {
        _totalPlayers = playersData.length;
        final me = playersData.firstWhere(
          (p) => p['playerId'] == widget.playerId,
          orElse: () => null,
        );
        if (me != null) {
          _myBerries = me['berries'] ?? 0;
          _myRank = me['rank'] ?? 1;
          _myAvatarBase64 = me['avatarBase64'] ?? '';
        }

        final activeName = data['activePlayerName'] as String?;
        _activePlayerName = activeName;
        _isPlayerActive = (activeName?.trim().toLowerCase() ==
                           widget.playerName.trim().toLowerCase());

        // avatar
        String? activeAvatar;
        if (activeName != null) {
          final activePlayerData = playersData.firstWhere(
            (p) => p['playerName'] == activeName,
            orElse: () => null,
          );
          if (activePlayerData != null) {
            activeAvatar = activePlayerData['avatarBase64'] ?? '';
          }
        }
        _activePlayerAvatar = activeAvatar;
      }
      setState(() {});
    });

    gs.onPositionUpdate((data) {
    // data = { playerId, position:{x,y}, orientation:"...", localMapSnippet: {...} }
    setState(() {
      if (data['position'] != null) {
        _playerX = data['position']['x'] ?? 0;
        _playerY = data['position']['y'] ?? 0;
      }
      if (data['orientation'] != null) {
        _playerOrientation = data['orientation'];
      }
      if (data['localMapSnippet'] != null) {
        _localMapSnippet = Map<String,int>.from(data['localMapSnippet']);
      }
      print("Front: onPositionUpdate => data=$data");  
    }
    );
  });

    // b) onTurnStarted
    gs.onTurnStarted((data) {
      // Comme dans l'ancien code, on reset tout à chaque début de tour
      _resetForNewTurn(data);
    });

    // c) onActivePlayerChanged
    gs.onActivePlayerChanged((data) {
      // Pareil : reset
      _resetForNewTurn(data);
    });

    // d) onCardDrawn
    gs.onCardDrawn((data) {
      setState(() {
        // Mémorise la carte
        _activePlayerName = data['activePlayerName'];
        _isPlayerActive = (_activePlayerName?.trim().toLowerCase() ==
                           widget.playerName.trim().toLowerCase());

        _cardName = data['cardName'];
        _cardImage = data['cardImage'];
        _cardCategory = data['cardCategory'];
        _cardDescription = _isPlayerActive
            ? data['cardDescription']
            : data['cardDescriptionPassive'];

        _turnState = data['turnState'] ?? _turnState;

        // BetOptions
        final rawBetOptions = data['betOptions'];
        if (rawBetOptions is List) {
          _betOptions = rawBetOptions.map((e) => e.toString()).toList();
        } else {
          _betOptions = [];
        }

        // Quiz
        if (_cardCategory == 'Quiz') {
          final rawTheme = data['cardTheme'];
          if (rawTheme is String) {
            // si c'est une string (ex: "Explorers;Geography")
            if (rawTheme.isNotEmpty) {
              _quizThemes = rawTheme.split(';').map((s) => s.trim()).toList();
            } else {
              _quizThemes = [];
            }
          } else if (rawTheme is List) {
            // si c'est une liste (ex: ["Explorers","Geography"])
            _quizThemes = rawTheme.map((e) => e.toString().trim()).toList();
          } else {
            _quizThemes = [];
          }
        } else {
          _quizThemes = [];
        }
      });
    });

    // e) onTurnStateChanged
    gs.onTurnStateChanged((data) {
      setState(() {
        _turnState = data['turnState'] ?? _turnState;
        final pid = data['playerId'];
        if (_turnState == 'drawStep' && pid == widget.playerId) {
          print("Front: It's my turn to draw a card => calling playerDrawCard()");
          widget.gameService.playerDrawCard(widget.gameId, widget.playerId);
        }
        final rawBetOptions = data['betOptions'];
        if (rawBetOptions is List) {
          _betOptions = rawBetOptions.map((e) => e.toString()).toList();
        }
        if (data.containsKey('majorityVote')) {
          _majorityVote = data['majorityVote'];
          gs.majorityVote = _majorityVote;
        }
      });
    });

    // f) Valid moves
    gs.onValidMovesReceived((moves) {
      setState(() {
        _validMoves = moves;
      });
    });

    // g) Challenge => onBetPlaced, onChallengeResult, onChallengeVotesUpdated
    gs.onBetPlaced((data) {
      if (_isPlayerActive) {
        final bet = data['bet'];
        final playerName = data['playerName'];
        final idx = _betOptions.indexOf(bet);
        String msg;
        if (idx == 0) {
          msg = "$playerName doesn't believe in you at all.";
        } else if (idx == _betOptions.length - 1) {
          msg = "$playerName bets everything on you!";
        } else {
          msg = "$playerName believes in you averagely.";
        }
        _showTransientMessage(playerName, msg);
      }
    });
    gs.onChallengeResult((data) {
      setState(() {
        _turnState = 'result';
        if (data['majorityVote'] != null) {
          _majorityVote = data['majorityVote'];
        }
        if (data['rewards'] != null) {
          final rewards = data['rewards'] as List<dynamic>;
          final me = rewards.firstWhere(
            (r) => r['playerName'] == widget.playerName,
            orElse: () => null,
          );
          if (me != null && me['berries'] != null) {
            _myBerries = me['berries'];
          }
        }
      });
    });
    gs.onChallengeVotesUpdated((data) {
      setState(() {
        if (data['isMajorityReached'] == true) {
          _turnState = 'result';
          _majorityVote = data['majorityVote'];
          gs.majorityVote = data['majorityVote'];
        }
      });
    });

    // h) Quiz => onQuizStarted, onQuizQuestion, onQuizAnswerResult, onQuizEnd
    gs.onQuizStarted((data) {
      setState(() {
        _isQuizInProgress = true;
        _turnState = 'quizInProgress';
        _quizCurrentIndex = null;
        _quizCurrentDescription = null;
        _quizCurrentOptions = [];
        _quizWasAnswerCorrect = null;
        _quizCorrectAnswer = null;
        _quizCurrentCategory = null;
        _quizCurrentImage = null;
      });
    });

    gs.onQuizQuestion((data) {
      setState(() {
        _quizCurrentIndex = data['questionIndex'];
        _quizCurrentDescription = data['questionDescription'];
        _quizCurrentOptions = data['questionOptions'] ?? [];
        _quizWasAnswerCorrect = null;
        _quizCorrectAnswer = null;
        _quizCurrentCategory = data['questionCategory'];
        _quizCurrentImage = data['questionImage'];
      });
    });

    gs.onQuizAnswerResult((data) {
      setState(() {
        _quizCorrectAnswer = data['correctAnswer'];
        _quizWasAnswerCorrect = data['isCorrect'];
      });
    });

    gs.onQuizEnd((data) {
      setState(() {
        _quizCorrectAnswers = data['correctAnswers'] ?? 0;
        _quizTotalQuestions = data['totalQuestions'] ?? 0;
        if (data['playerId'] == widget.playerId) {
          int newlyEarned = data['earnedBerries'] ?? 0;
          _myBerries += newlyEarned;
          _quizEarnedBerries = newlyEarned;
        }
        _isQuizInProgress = false;
        _turnState = 'quizResult';
      });
    });
  }

  // ----------------------------------------------------
  // MESSAGES ÉPHÉMÈRES
  // ----------------------------------------------------
  void _showTransientMessage(String playerName, String message) {
    final freeSlot = _slotsOccupied.indexWhere((occupied) => !occupied);
    if (freeSlot == -1) {
      print("DEBUG: Pas de slot libre pour afficher un message ephemeral");
      return;
    }
    setState(() {
      _slotsOccupied[freeSlot] = true;
      _playerMessages[playerName] = message;
      _messageOpacity = 1.0;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _messageOpacity = 0.0);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _slotsOccupied[freeSlot] = false;
            _playerMessages.remove(playerName);
          });
        }
      });
    });
  }

  List<Widget> _buildEphemeralMessages(BuildContext context) {
    final list = _playerMessages.entries.toList();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return List.generate(_slotsOccupied.length, (index) {
      if (index < list.length) {
        final msg = list[index].value;
        return AnimatedOpacity(
          opacity: _messageOpacity,
          duration: const Duration(seconds: 1),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: AppTheme.transientMessageBoxDecoration(screenWidth * 0.02),
            child: Text(
              msg,
              style: AppTheme.transientMessageTextStyle(screenWidth * 0.04),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return const SizedBox();
    });
  }

  // ----------------------------------------------------
  // 4) BOTTOM NAV
  // ----------------------------------------------------
  void _onNavItemTapped(int index) {
    if (index == 3) {
      _showQuitDialog();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _showQuitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: Text('Quit Game', style: AppTheme.themeData.textTheme.bodyLarge),
        content: Text(
          'Are you sure you want to quit the current game?',
          style: AppTheme.themeData.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // 5) BUILD
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // a) GameScreen en fond
          GameScreen(
            gameId: widget.gameId,
            playerName: widget.playerName,
            playerId: widget.playerId,
            gameService: widget.gameService,

            turnState: _turnState,
            isPlayerActive: _isPlayerActive,
            myBerries: _myBerries,
            myRank: _myRank,
            totalPlayers: _totalPlayers,
            myAvatarBase64: _myAvatarBase64,
            activePlayerAvatar: _activePlayerAvatar,
            activePlayerName: _activePlayerName,

            cardName: _cardName,
            cardImage: _cardImage,
            cardDescription: _cardDescription,
            cardCategory: _cardCategory,
            betOptions: _betOptions,
            majorityVote: _majorityVote,

            isQuizInProgress: _isQuizInProgress,
            quizThemes: _quizThemes,
            quizCurrentIndex: _quizCurrentIndex,
            quizCurrentDescription: _quizCurrentDescription,
            quizCurrentCategory: _quizCurrentCategory,
            quizCurrentImage: _quizCurrentImage,
            quizCurrentOptions: _quizCurrentOptions,
            quizWasAnswerCorrect: _quizWasAnswerCorrect,
            quizCorrectAnswer: _quizCorrectAnswer,
            quizCorrectAnswers: _quizCorrectAnswers,
            quizTotalQuestions: _quizTotalQuestions,
            quizEarnedBerries: _quizEarnedBerries,
            validMoves: _validMoves,
            playerX: _playerX,
            playerY: _playerY,
            playerOrientation: _playerOrientation,
            localMapSnippet: _localMapSnippet,
          ),

          // b) Inventory ou Quest si _currentIndex = 1 ou 2
          if (_currentIndex == 1)
            InventoryScreen(
              gameId: widget.gameId,
              playerId: widget.playerId,
              gameService: widget.gameService,
              initialInventory: _initialInventory,
            ),
          if (_currentIndex == 2)
            QuestScreen(
              gameId: widget.gameId,
              playerId: widget.playerId,
              gameService: widget.gameService,
            ),

          // c) Messages éphémères au-dessus
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: _buildEphemeralMessages(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.buttonBlue,
        selectedItemColor: AppTheme.white,
        unselectedItemColor: AppTheme.white.withOpacity(0.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.videogame_asset),
            label: 'Game',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flag),
            label: 'Quest',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.exit_to_app),
            label: 'Quit',
          ),
        ],
      ),
    );
  }
}
