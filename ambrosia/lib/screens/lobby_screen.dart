// lib/screens/lobby_screen.dart

import 'dart:io';
import 'dart:convert'; // pour base64Encode, base64Decode
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/game_service.dart';
import '../styles/app_theme.dart';
import 'tutorial_screen.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final GameService gameService; // Injection du GameService
  final String gameId;
  final String playerName;
  final bool isHost;
  final String avatarBase64; // Avatar déjà existant (compte connecté) ou vide
  final String playerId;

  const LobbyScreen({
    Key? key,
    required this.gameService,
    required this.gameId,
    required this.playerId,
    required this.playerName,
    this.isHost = false,
    this.avatarBase64 = '', 
  }) : super(key: key);

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final GameService _gameService;
  final ImagePicker _imagePicker = ImagePicker();

  // Données joueurs
  List<String> _playerIds = [];
  Map<String, String> _playerNames = {};
  Map<String, bool> _readyStatus = {};
  Map<String, String> _avatars = {};

  File? _playerImage;
  int readyCount = 0;

  @override
  void initState() {
    super.initState();
    _gameService = widget.gameService;

    print('LobbyScreen: Init pour gameId=${widget.gameId} '
        'avec playerName=${widget.playerName}, playerId=${widget.playerId}');

    // Connexion Socket.IO
    _gameService.connectToGame(widget.gameId);
    _setupSocketListeners();
    _gameService.joinRoom(widget.gameId);

    // Si on a déjà un avatarBase64, on le stocke et on l’envoie au serveur
    if (widget.avatarBase64.isNotEmpty) {
      _avatars[widget.playerId] = widget.avatarBase64;
      _gameService.updateAvatar(widget.gameId, widget.playerId, widget.avatarBase64);
    }
  }

  void _setupSocketListeners() {
    // Liste complète de joueurs déjà présents
    _gameService.socket.on('currentPlayers', (data) {
      // print('LobbyScreen: currentPlayers => $data');
      setState(() {
        // On réinitialise
        _playerIds.clear();
        _playerNames.clear();
        _readyStatus.clear();
        _avatars.clear();
        readyCount = 0;

        // data est un tableau d’objets (un par joueur)
        for (var p in data) {
          final pid = p['playerId'] as String;
          final pname = p['playerName'] as String;
          final isReady = p['ready'] as bool? ?? false;
          final avatarB64 = p['avatarBase64'] as String? ?? '';

          _playerIds.add(pid);
          _playerNames[pid] = pname;
          _readyStatus[pid] = isReady;
          _avatars[pid] = avatarB64;
          if (isReady) readyCount++;
        }
      });
    });

    // Nouvel arrivant
    _gameService.socket.on('playerJoined', (data) {
      // print('LobbyScreen: playerJoined => $data');
      setState(() {
        final pid = data['playerId'];
        final pname = data['playerName'] ?? '???';
        _playerIds.add(pid);
        _playerNames[pid] = pname;
        _readyStatus[pid] = false;
        _avatars[pid] = data['avatarBase64'] ?? '';
      });
    });

    // MàJ ready status
    _gameService.socket.on('readyStatusUpdate', (data) {
      final pName = data['playerName'];
      final isReady = data['isReady'] as bool;

      // Retrouver le playerId correspondant
      final pid = _playerIds.firstWhere(
        (candidatePid) => _playerNames[candidatePid] == pName,
        orElse: () => '',
      );

      if (pid.isEmpty) {
        print("ERROR: readyStatusUpdate => inconnu, pName=$pName");
        return;
      }

      setState(() {
        _readyStatus[pid] = isReady;
        readyCount = _readyStatus.values.where((r) => r).length;
      });
    });

    // Tous prêts
    _gameService.socket.on('allPlayersReady', (_) {
      print('LobbyScreen: allPlayersReady => tous prêts !');
      if (widget.isHost) _showStartGameDialog();
    });

    // Démarrage de la partie (-> tutorial)
    _gameService.socket.on('startGame', (data) {
      // print('LobbyScreen: startGame => data=$data');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TutorialScreen(
            gameId: widget.gameId,
            playerName: widget.playerName,
            playerId: widget.playerId,
            gameService: _gameService,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    // On ne déconnecte pas ici le socket si on poursuit la partie
    super.dispose();
  }

  // ---------------------------------------------------
  // PHOTO
  // ---------------------------------------------------
  Future<void> _takePhoto() async {
    final XFile? picked = await _imagePicker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64Str = base64Encode(bytes);
    print("LobbyScreen: Photo prise => base64 length=${base64Str.length}");

    // Envoyer au serveur
    if (widget.playerId.isNotEmpty) {
      print("DEBUG: Emitting updateAvatar with playerId=${widget.playerId}");
      _gameService.updateAvatar(widget.gameId, widget.playerId, base64Str);
      setState(() {
        _avatars[widget.playerId] = base64Str;
      });
    }

    setState(() {
      _playerImage = File(picked.path);
    });
  }

  // ---------------------------------------------------
  // TOGGLE READY
  // ---------------------------------------------------
  void _toggleReadyStatus(bool isReady) {
    print('LobbyScreen: setReadyStatus($isReady) for playerId=${widget.playerId} => name=${widget.playerName}');
    _gameService.setReadyStatus(widget.gameId, widget.playerName, isReady);

    setState(() {
      _readyStatus[widget.playerId] = isReady;
      readyCount = _readyStatus.values.where((r) => r == true).length;
    });
  }

  // ---------------------------------------------------
  // START GAME (HOST)
  // ---------------------------------------------------
  void _showStartGameDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tous les joueurs sont prêts !"),
        content: const Text("Souhaitez-vous lancer la partie ?"),
        actions: [
          TextButton(
            onPressed: () {
              print('LobbyScreen: L’hôte annule le startGame');
              _toggleReadyStatus(false);
              Navigator.pop(ctx);
            },
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              print('LobbyScreen: L’hôte confirme le startGame');
              _gameService.startGame(widget.gameId);
              Navigator.pop(ctx);
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // BUILD
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isReady = _readyStatus[widget.playerId] ?? false;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Fond
          Container(decoration: AppTheme.backgroundDecoration()),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.05),

                // Code de la partie
                Text(
                  'Game code:',
                  style: Theme.of(context).textTheme.bodyText1?.copyWith(
                        fontSize: 20,
                        color: AppTheme.greenButton,
                      ),
                ),
                Text(
                  widget.gameId,
                  style: Theme.of(context).textTheme.headline6?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // Avatar
                GestureDetector(
                  // Si on a déjà un avatar passé par l'utilisateur connecté,
                  // on désactive la prise de photo. Sinon => _takePhoto
                  onTap: widget.avatarBase64.isNotEmpty ? null : _takePhoto,
                  child: Container(
                    width: screenHeight * 0.15,
                    height: screenHeight * 0.15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.lightMint,
                      border: Border.all(color: AppTheme.greenButton, width: 2),
                      image: _playerImage != null
                          ? DecorationImage(
                              image: FileImage(_playerImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _buildAvatarChild(screenHeight),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),

                // Nom du joueur
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightMint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.playerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.greenButton,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // Nombre de joueurs prêts
                Text(
                  'Players ready: $readyCount/${_playerIds.length}',
                  style: Theme.of(context).textTheme.bodyText1?.copyWith(fontSize: 18),
                ),
                SizedBox(height: screenHeight * 0.03),

                // Liste des joueurs
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.lightMint,
                      border: Border.all(color: AppTheme.greenButton, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: _playerIds.length,
                      itemBuilder: (context, index) {
                        final pid = _playerIds[index];
                        final pname = _playerNames[pid] ?? '???';
                        final pReady = _readyStatus[pid] ?? false;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              pname,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: pReady ? Colors.green : Colors.red,
                              ),
                            ),
                            Icon(
                              pReady ? Icons.check_circle : Icons.cancel,
                              color: pReady ? Colors.green : Colors.red,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // Bouton Ready / Unready
                AppTheme.customButton(
                  label: isReady ? "Unready" : "Ready!",
                  onPressed: () => _toggleReadyStatus(!isReady),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Petit helper pour afficher la photo / avatar / icône
  Widget _buildAvatarChild(double screenHeight) {
    // 1) S’il y a déjà un `_playerImage` => on affiche l’image camera
    if (_playerImage != null) {
      return ClipOval(
        child: Image.file(
          _playerImage!,
          fit: BoxFit.cover,
          width: screenHeight * 0.15,
          height: screenHeight * 0.15,
        ),
      );
    }

    // 2) Sinon, si on a un avatar dans _avatars pour ce player
    final currentAvatarB64 = _avatars[widget.playerId] ?? '';
    if (currentAvatarB64.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          base64Decode(currentAvatarB64),
          fit: BoxFit.cover,
          width: screenHeight * 0.15,
          height: screenHeight * 0.15,
        ),
      );
    }

    // 3) Sinon on affiche l’icône par défaut (caméra)
    return Icon(
      Icons.camera_alt_outlined,
      size: screenHeight * 0.07,
      color: AppTheme.greenButton,
    );
  }
}
