// lib/services/game_service.dart

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class GameService {
  late IO.Socket socket;
  String? majorityVote;

  /// Callback pour positionUpdate côté front
  Function(Map<String, dynamic>)? _onPositionUpdateCallback;

  // ----------------------------------------------------------------
  // DEBUG
  // ----------------------------------------------------------------

  void teleportPlayer(String gameId, String playerId, String coordinate) {
    print("GameService: Teleporting player $playerId to $coordinate");
    socket.emit('teleportPlayer', {
      'gameId': gameId,
      'playerId': playerId,
      'coordinate': coordinate,
    });
  }

  // ----------------------------------------------------------------
  // CONSTRUCTOR & SOCKET INITIALIZATION
  // ----------------------------------------------------------------
  GameService() {
    socket = IO.io(
      'http://192.168.1.168:3000', // ou votre URL
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
  }

  // ----------------------------------------------------------------
  // CONNECTION & ROOM
  // ----------------------------------------------------------------
  void connectToGame(String gameId) {
    print('GameService: Connecting to game $gameId');
    socket.on('connect', (_) {
      print('GameService: Connected to Socket.IO server');
      joinRoom(gameId);
    });

    socket.on('disconnect', (_) {
      print('GameService: Disconnected from Socket.IO server');
    });

    socket.connect();
  }

  void joinRoom(String gameId) {
    print("GameService: Joining room with gameId: $gameId");
    socket.emit('joinRoom', gameId);
  }

  void disconnect() {
    print("GameService: Disconnecting from Socket.IO server");
    socket.disconnect();
  }

  // ----------------------------------------------------------------
  // LOBBY / READY STATUS
  // ----------------------------------------------------------------
  void setReadyStatus(String gameId, String playerName, bool isReady) {
    print("GameService: Updating ready status for $playerName in game $gameId: $isReady");
    socket.emit('playerReady', {
      'gameId': gameId,
      'playerName': playerName,
      'isReady': isReady,
    });
  }

  void updateAvatar(String gameId, String playerId, String base64Image) {
    print("GameService: Updating avatar for player $playerId in game $gameId");
    socket.emit('updateAvatar', {
      'gameId': gameId,
      'playerId': playerId,
      'avatarBase64': base64Image,
    });
  }

  // ----------------------------------------------------------------
  // GAME START / END
  // ----------------------------------------------------------------
  void finishTutorial(String gameId, String playerId) {
    print("GameService: Player $playerId finished tutorial in game $gameId");
    socket.emit('finishTutorial', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }


  void startGame(String gameId) {
    print("GameService: Requesting to start game for $gameId");
    socket.emit('startGame', {'gameId': gameId});
  }

  void onStartGame(Function(Map<String, dynamic>) callback) {
    socket.on('startGame', (data) {
      print('[Front] onStartGame => data: $data');
      // => data = { maze: [...], players: [...], activePlayerName: "Tom" }
      callback(Map<String, dynamic>.from(data));
    });
  }

  void endTurn(String gameId) {
    print("GameService: Ending turn for game $gameId");
    socket.emit('endTurn', gameId);
  }

  // ----------------------------------------------------------------
  // TURN & ACTIVE PLAYER
  // ----------------------------------------------------------------
  void playerDrawCard(String gameId, String playerId) {
    print("GameService: Player $playerId requests to draw a card in game $gameId");
    socket.emit('playerDrawCard', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void onTurnStarted(Function(Map<String, dynamic>) callback) {
    socket.on('turnStarted', (data) {
      print("GameService: Turn started event received");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onTurnStateChanged(Function(Map<String, dynamic>) callback) {
    socket.on('turnStateChanged', (data) {
      print("GameService: Turn state changed => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onActivePlayerChanged(Function(Map<String, dynamic>) callback) {
    socket.on('activePlayerChanged', (data) {
      _logPlayerPosition(data);
      callback(Map<String, dynamic>.from(data));
    });
  }

  void getActivePlayer(String gameId) {
    print("GameService: Requesting active player for game $gameId...");
    socket.emit('getActivePlayer', {'gameId': gameId});
  }

  void onActivePlayerReceived(Function(String) callback) {
    socket.on('activePlayer', (data) {
      print("GameService: Received activePlayer: ${data['activePlayerName']}");
      _logPlayerPosition(data);
      callback(data['activePlayerName']);
    });
  }

  // ----------------------------------------------------------------
  // PLAYERS INFO
  // ----------------------------------------------------------------
  void onCurrentPlayers(Function(List<dynamic>) callback) {
    socket.on('currentPlayers', (data) {
      print("GameService: Current players received => $data");
      callback(List<dynamic>.from(data));
    });
  }

  void onGameInfos(Function(Map<String, dynamic>) callback) {
    socket.on('gameInfos', (data) {
      print("[Front] onGameInfos => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ----------------------------------------------------------------
  // MOVEMENT
  // ----------------------------------------------------------------
  void movePlayer(String gameId, String playerId, String move) {
    print("GameService: Player $playerId moving $move in game $gameId");
    socket.emit('playerMove', {
      'gameId': gameId,
      'playerId': playerId,
      'move': move,
    });
  }

  /// Abonnement à "positionUpdate"
  void onPositionUpdate(Function(Map<String, dynamic>) callback) {
    _onPositionUpdateCallback = callback;
    socket.on('positionUpdate', (data) {
      final parsed = Map<String, dynamic>.from(data);
      print("[Front] *** positionUpdate *** => $parsed"); // AJOUT: log
      if (parsed['position'] != null && parsed['position'] is Map) {
        int px = parsed['position']['x'] ?? 0;
        final py = parsed['position']['y'] ?? 0;
        final colLetter = String.fromCharCode(65 + px);
        final rowNumber = py + 1;
        print("[Front] -> position: ${colLetter}${rowNumber}, orientation=${parsed['orientation']}");
      }
      // snippet si besoin
      if (_onPositionUpdateCallback != null) {
        _onPositionUpdateCallback!(parsed);
      }
    });
  }
  void onMoveError(Function(String) callback) {
    socket.on('moveError', (data) {
      print("GameService: Move error => $data");
      callback(data['message']);
    });
  }

  // ----------------------------------------------------------------
  // VALID MOVES
  // ----------------------------------------------------------------
  void getValidMoves(String gameId, String playerId, Function(Map<String, bool>) callback) {
    print("GameService: Requesting valid moves for $playerId in $gameId");
    socket.emit('getValidMoves', {'gameId': gameId, 'playerId': playerId});
    socket.once('validMoves', (data) {
      if (data != null && data is Map) {
        print("GameService: Received valid moves => $data");
        callback(Map<String, bool>.from(data));
      } else {
        print("GameService: Error getting valid moves");
        callback({
          'canMoveForward': false,
          'canMoveLeft': false,
          'canMoveRight': false,
        });
      }
    });
  }

  /// Si vous l'utilisez : abonner à l'event 'validMoves'
  void onValidMovesReceived(Function(Map<String, bool>) callback) {
    socket.on('validMoves', (data) {
      print("GameService: validMoves => $data");
      callback({
        'canMoveForward': data['canMoveForward'] ?? false,
        'canMoveLeft': data['canMoveLeft'] ?? false,
        'canMoveRight': data['canMoveRight'] ?? false,
      });
    });
  }

  // ----------------------------------------------------------------
  // CARD DRAW
  // ----------------------------------------------------------------
  /// Si vous l'utilisez pour un event "cardDrawn"
  void onCardDrawn(Function(Map<String, dynamic>) callback) {
    socket.on('cardDrawn', (data) {
      print("GameService: cardDrawn => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ----------------------------------------------------------------
  // CHALLENGE (BETS)
  // ----------------------------------------------------------------
  void startBetting(String gameId, String playerId) {
    print("GameService: startBetting => $playerId in $gameId");
    socket.emit('startBetting', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void onBettingEnded(Function() callback) {
    socket.on('bettingEnded', (_) {
      print("GameService: Betting phase ended");
      callback();
    });
  }

  void placeBet(String gameId, String playerId, String bet) {
    print("GameService: placeBet => $bet by $playerId in $gameId");
    socket.emit('placeBet', {
      'gameId': gameId,
      'playerId': playerId,
      'bet': bet,
    });
  }

  void onBetPlaced(Function(Map<String, dynamic>) callback) {
    socket.on('betPlaced', (data) {
      print("GameService: betPlaced => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onChallengeStarted(Function() callback) {
    socket.on('challengeStarted', (_) {
      print("GameService: challengeStarted");
      callback();
    });
  }

  void onChallengeResult(Function(Map<String, dynamic>) callback) {
    socket.on('challengeResult', (data) {
      print("GameService: challengeResult => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void startChallenge(String gameId, String playerId) {
    print("GameService: startChallenge => $playerId in $gameId");
    socket.emit('startChallenge', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void sendChallengeResult(String gameId, String playerId, String result) {
    print("GameService: sendChallengeResult => $result");
    socket.emit('challengeResult', {
      'gameId': gameId,
      'playerId': playerId,
      'result': result,
    });
  }

  void placeChallengeVote(String gameId, String playerId, String vote) {
    print("GameService: placeChallengeVote => $vote by $playerId in $gameId");
    socket.emit('placeChallengeVote', {
      'gameId': gameId,
      'playerId': playerId,
      'vote': vote,
    });
  }

  void onChallengeVotesUpdated(Function(Map<String, dynamic>) callback) {
    socket.on('challengeVotesUpdated', (data) {
      print("GameService: challengeVotesUpdated => $data");
      if (data['isMajorityReached'] == true) {
        majorityVote = data['majorityVote'];
      }
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ----------------------------------------------------------------
  // QUIZ
  // ----------------------------------------------------------------
  void startQuiz(String gameId, String playerId, String chosenTheme) {
    print("GameService: startQuiz => theme=$chosenTheme");
    socket.emit('startQuiz', {
      'gameId': gameId,
      'playerId': playerId,
      'chosenTheme': chosenTheme,
    });
  }

  void quizAnswer(String gameId, String playerId, String answer) {
    print("GameService: quizAnswer => $answer by $playerId");
    socket.emit('quizAnswer', {
      'gameId': gameId,
      'playerId': playerId,
      'answer': answer,
    });
  }

  void onQuizStarted(Function(Map<String, dynamic>) callback) {
    socket.on('quizStarted', (data) {
      print("GameService: quizStarted => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onQuizQuestion(Function(Map<String, dynamic>) callback) {
    socket.on('quizQuestion', (data) {
      print("GameService: quizQuestion => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onQuizAnswerResult(Function(Map<String, dynamic>) callback) {
    socket.on('quizAnswerResult', (data) {
      print("GameService: quizAnswerResult => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onQuizEnd(Function(Map<String, dynamic>) callback) {
    socket.on('quizEnd', (data) {
      print("GameService: quizEnd => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ----------------------------------------------------------------
  // INVENTORY
  // ----------------------------------------------------------------
  void pickUpObject(String gameId, String playerId) {
    print("GameService: pickUpObject => $playerId in $gameId");
    socket.emit('pickUpObject', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void onObjectPickedUp(Function(Map<String, dynamic>) callback) {
    socket.on('objectPickedUp', (data) {
      print("GameService: objectPickedUp => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void discardObject(String gameId, String playerId, int itemId) {
    print("GameService: discardObject => itemId=$itemId by $playerId");
    socket.emit('discardObject', {
      'gameId': gameId,
      'playerId': playerId,
      'itemId': itemId,
    });
  }

  void onObjectDiscarded(Function(Map<String, dynamic>) callback) {
    socket.on('objectDiscarded', (data) {
      print("GameService: objectDiscarded => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void useObject(String gameId, String playerId, int itemId) {
    print("GameService: useObject => itemId=$itemId by $playerId");
    socket.emit('useObject', {
      'gameId': gameId,
      'playerId': playerId,
      'itemId': itemId,
    });
  }

  void onObjectUsed(Function(Map<String, dynamic>) callback) {
    socket.on('objectUsed', (data) {
      print("GameService: objectUsed => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ----------------------------------------------------------------
  // UTILITIES
  // ----------------------------------------------------------------
  Future<String?> getPlayerId(String gameId, String playerName) async {
    final completer = Completer<String?>();
    socket.emit('getPlayerId', {'gameId': gameId, 'playerName': playerName});

    socket.once('playerId', (data) {
      if (data != null && data['playerId'] != null) {
        completer.complete(data['playerId']);
      } else {
        completer.completeError('Player ID not found.');
      }
    });

    return completer.future;
  }

  void _logPlayerPosition(Map<String, dynamic> data) {
    if (data.containsKey('position') && data['position'] is Map) {
      final pos = data['position'];
      int x = pos['x'] ?? 0;
      final y = pos['y'] ?? 0;
      final col = String.fromCharCode(65 + x);
      final row = y + 1;
      print("GameService: Player's current position: $col$row");
    }
  }
}
