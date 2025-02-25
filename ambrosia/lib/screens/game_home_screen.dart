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
  // Bottom navigation index (Game, Inventory, Quest, Quit)
  int _currentIndex = 0;

  // Etat du tour et du joueur
  String _turnState = 'movement';
  bool _isPlayerActive = false;

  // Infos perso
  int _myBerries = 0;
  int _myRank = 1;
  int _totalPlayers = 1;
  String? _myAvatarBase64;

  // Infos joueur actif
  String? _activePlayerName;
  String? _activePlayerAvatar;

  // Infos de la carte piochée (carte courante)
  String? _cardName;
  String? _cardImage;
  String? _cardDescription;
  String? _cardCategory;
  List<String> _betOptions = [];
  String? _majorityVote;

  // Quiz
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

  // Mouvements possibles (fourni par le back)
  Map<String, bool> _validMoves = {
    'canMoveForward': false,
    'canMoveLeft': false,
    'canMoveRight': false,
  };

  // Map complète sous forme de liste d'objets (chaque cellule possède ses propriétés)
  List<List<Map<String, dynamic>>> _fullMapObjects = [];
  int _playerX = 0;
  int _playerY = 0;
  String _playerOrientation = 'south';

  // Messages éphémères
  List<bool> _slotsOccupied = [false, false, false, false];
  Map<String, String> _playerMessages = {};
  double _messageOpacity = 0.0;

  // Inventaire initial
  List<Map<String, dynamic>> _initialInventory = [];

  // Lock pour empêcher plusieurs déplacements simultanés
  bool _moveLocked = false;
  Timer? _moveLockTimer;

  @override
  void initState() {
    super.initState();

    _setupSocketListeners();
    _handleInitialData(widget.initialData);

    widget.gameService.onStartGame((data) {
      if (data.containsKey('maze')) {
        final rawMaze = data['maze'];
        if (rawMaze is List) {
          final converted = rawMaze.map((row) {
            if (row is List) {
              return row.map((cell) {
                if (cell is Map) return Map<String, dynamic>.from(cell);
                return <String, dynamic>{};
              }).toList();
            }
            return <Map<String, dynamic>>[];
          }).toList();
          setState(() {
            _fullMapObjects = converted.cast<List<Map<String, dynamic>>>();
          });
        }
      }
      _resetForNewTurn(data);
    });

    widget.gameService.connectToGame(widget.gameId);
  }

  void _resetForNewTurn(Map<String, dynamic> data) {
    setState(() {
      _activePlayerName = data['activePlayerName'];
      _turnState = data['turnState'] ?? 'movement';
      _isPlayerActive =
          (_activePlayerName?.trim().toLowerCase() == widget.playerName.trim().toLowerCase());
      _cardName = null;
      _cardImage = null;
      _cardDescription = null;
      _cardCategory = null;
      _betOptions = [];
      _majorityVote = null;
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
      // On réinitialise le lock
      _moveLocked = false;
    });

    if (_isPlayerActive && _turnState == 'movement') {
      widget.gameService.getValidMoves(widget.gameId, widget.playerId, (moves) {
        setState(() {
          _validMoves = moves;
        });
      });
      // On verrouille les déplacements pendant 3 secondes
      _setMoveLockFor(const Duration(seconds: 3));
    }
  }

  void _setMoveLockFor(Duration duration) {
    _moveLockTimer?.cancel();
    setState(() {
      _moveLocked = true;
    });
    _moveLockTimer = Timer(duration, () {
      setState(() {
        _moveLocked = false;
      });
    });
  }

  void _handleInitialData(Map<String, dynamic> data) {
    final playersData = data['players'] ?? [];
    if (playersData is List) {
      _totalPlayers = playersData.length;
      final me = playersData.firstWhere((p) => p['playerId'] == widget.playerId, orElse: () => null);
      if (me != null) {
        _myBerries = me['berries'] ?? 0;
        _myRank = me['rank'] ?? 1;
        _myAvatarBase64 = me['avatarBase64'] ?? '';
        _initialInventory = List<Map<String, dynamic>>.from(me['inventory'] ?? []);
        if (me['position'] != null) {
          _playerX = me['position']['x'];
          _playerY = me['position']['y'];
        }
        if (me['orientation'] is String) {
          _playerOrientation = me['orientation'];
        }
      }
    }
    if (data.containsKey('maze')) {
      final rawMaze = data['maze'];
      if (rawMaze is List) {
        final converted = rawMaze.map((row) {
          if (row is List) {
            return row.map((cell) {
              if (cell is Map) return Map<String, dynamic>.from(cell);
              return <String, dynamic>{};
            }).toList();
          }
          return <Map<String, dynamic>>[];
        }).toList();
        setState(() {
          _fullMapObjects = converted.cast<List<Map<String, dynamic>>>();
        });
      }
    }
    _resetForNewTurn(data);
  }

  void _setupSocketListeners() {
    final gs = widget.gameService;

    gs.onGameInfos((data) {
      final playersData = data['players'] ?? [];
      if (playersData is List) {
        _totalPlayers = playersData.length;
        final me = playersData.firstWhere((p) => p['playerId'] == widget.playerId, orElse: () => null);
        if (me != null) {
          _myBerries = me['berries'] ?? 0;
          _myRank = me['rank'] ?? 1;
          _myAvatarBase64 = me['avatarBase64'] ?? '';
          if (me['position'] != null) {
            _playerX = me['position']['x'] ?? _playerX;
            _playerY = me['position']['y'] ?? _playerY;
          }
        }
        final activeName = data['activePlayerName'] as String?;
        _activePlayerName = activeName;
        _isPlayerActive =
            (activeName?.trim().toLowerCase() == widget.playerName.trim().toLowerCase());
      }
      setState(() {});
    });

    gs.onPositionUpdate((data) {
      setState(() {
        if (data['position'] != null) {
          _playerX = data['position']['x'] ?? _playerX;
          _playerY = data['position']['y'] ?? _playerY;
        }
        if (data['orientation'] != null) {
          _playerOrientation = data['orientation'];
        }
        // Le déverrouillage est géré par le Timer de _setMoveLockFor
      });
    });

    gs.onTurnStarted((data) {
      _resetForNewTurn(data);
    });
    gs.onActivePlayerChanged((data) {
      _resetForNewTurn(data);
    });
    gs.onCardDrawn((data) {
      setState(() {
        _activePlayerName = data['activePlayerName'];
        _isPlayerActive =
            (_activePlayerName?.trim().toLowerCase() == widget.playerName.trim().toLowerCase());
        _cardName = data['cardName'];
        _cardImage = data['cardImage'];
        _cardCategory = data['cardCategory'];
        _cardDescription = _isPlayerActive
            ? data['cardDescription']
            : data['cardDescriptionPassive'];
        _turnState = data['turnState'] ?? _turnState;
        final rawBetOptions = data['betOptions'];
        if (rawBetOptions is List) {
          _betOptions = rawBetOptions.map((e) => e.toString()).toList();
        } else {
          _betOptions = [];
        }
        if (_cardCategory == 'Quiz') {
          final rawTheme = data['cardTheme'];
          if (rawTheme is String) {
            _quizThemes = rawTheme.isNotEmpty
                ? rawTheme.split(';').map((s) => s.trim()).toList()
                : [];
          } else if (rawTheme is List) {
            _quizThemes = rawTheme.map((e) => e.toString().trim()).toList();
          } else {
            _quizThemes = [];
          }
        } else {
          _quizThemes = [];
        }
      });
    });
    gs.onTurnStateChanged((data) {
      setState(() {
        _turnState = data['turnState'] ?? _turnState;
        final rawBetOptions = data['betOptions'];
        if (rawBetOptions is List) {
          _betOptions = rawBetOptions.map((e) => e.toString()).toList();
        }
        if (data.containsKey('majorityVote')) {
          _majorityVote = data['majorityVote'];
          gs.majorityVote = data['majorityVote'];
        }
      });
    });
    gs.onValidMovesReceived((moves) {
      setState(() {
        _validMoves = moves;
      });
    });
    gs.onBetPlaced((data) {
      if (_isPlayerActive) {
        final bet = data['bet'];
        final pName = data['playerName'];
        final idx = _betOptions.indexOf(bet);
        String msg;
        if (idx == 0) {
          msg = "$pName doesn't believe in you at all.";
        } else if (idx == _betOptions.length - 1) {
          msg = "$pName bets everything on you!";
        } else {
          msg = "$pName believes in you averagely.";
        }
        _showTransientMessage(pName, msg);
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
              orElse: () => null);
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

  void _showTransientMessage(String playerName, String message) {
    final freeSlot = _slotsOccupied.indexWhere((occupied) => !occupied);
    if (freeSlot == -1) return;
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

  // Ajout d'une commande de téléportation pour tests
  void _showTeleportDialog() {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Teleport Test"),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: "Enter coordinate (e.g. A1)"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                String coord = _controller.text.trim().toUpperCase();
                widget.gameService.teleportPlayer(widget.gameId, widget.playerId, coord);
                Navigator.of(ctx).pop();
              },
              child: const Text("Teleport"),
            ),
          ],
        );
      },
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
            fullMapObjects: _fullMapObjects,
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showTeleportDialog,
        child: const Icon(Icons.send),
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
