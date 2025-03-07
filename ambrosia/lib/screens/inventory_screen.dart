// lib/screens/inventory_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final GameService gameService;
  final List<Map<String, dynamic>> initialInventory; // Inventaire préchargé

  const InventoryScreen({
    Key? key,
    required this.gameId,
    required this.playerId,
    required this.gameService,
    required this.initialInventory,
  }) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _myInventory = [];
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    print("InventoryScreen: Initialized for game ${widget.gameId}");

    // Initialisation avec l'inventaire préchargé
    _myInventory = widget.initialInventory;

    widget.gameService.onGameInfos((data) {
      if (!mounted) return;
      final playersData = data['players'] ?? [];
      if (playersData is List) {
        final me = playersData.firstWhere(
          (p) => p['playerId'] == widget.playerId,
          orElse: () => null,
        );
        if (me != null && me is Map) {
          final newInventory = me['inventory'] ?? [];
          setState(() {
            _myInventory = List<Map<String, dynamic>>.from(newInventory);
            _hasLoaded = true;
          });
        } else {
          setState(() {
            _hasLoaded = true;
          });
        }
      } else {
        setState(() {
          _hasLoaded = true;
        });
      }
    });

    // Demande d'actualisation dès l'ouverture
    widget.gameService.socket.emit('requestGameInfos', {
      'gameId': widget.gameId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: AppTheme.backgroundDecoration(),
        child: Column(
          children: [
            // Titre de la page
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                "Inventory",
                style: AppTheme.themeData.textTheme.displayLarge?.copyWith(
                  fontSize: 36,
                  color: AppTheme.accentYellow,
                ),
              ),
            ),
            Expanded(child: _buildInventoryContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryContent() {
    if (!_hasLoaded) {
      return Center(child: CircularProgressIndicator());
    }
    if (_myInventory.isEmpty) {
      return Center(
        child: Text(
          "Your inventory is empty",
          style: AppTheme.themeData.textTheme.bodyLarge,
        ),
      );
    }
    return ListView.builder(
      itemCount: _myInventory.length,
      itemBuilder: (context, index) {
        final item = _myInventory[index];
        return _buildInventoryItem(item);
      },
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    return Card(
      // Couleur de fond personnalisée pour la tuile
      color: Color.fromRGBO(220, 232, 233, 1).withOpacity(0.8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildItemLeading(item),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['name'] ?? 'Unknown item',
                    style: AppTheme.themeData.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Affichage de la description en italique (texte fixe pour les objets spéciaux)
            Text(
              _getCustomDescription(item),
              style: AppTheme.themeData.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bouton "Utiliser" sans encadrement
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Using ${item['name']}... "),
                      ),
                    );
                    final itemId = item['itemId'] as int;
                    widget.gameService.useObject(widget.gameId, widget.playerId, itemId);
                  },
                  child: Text(
                    "Use",
                    style: TextStyle(fontSize: 16, color: Color.fromARGB(196, 64, 147, 63)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton "Jeter" sans encadrement
                TextButton(
                  onPressed: () => _confirmDiscard(item),
                  child: Text(
                    "Discard",
                    style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 212, 18, 18)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// Retourne une description personnalisée pour les objets spéciaux
  String _getCustomDescription(Map<String, dynamic> item) {
    final int itemId = item['itemId'];
    switch (itemId) {
      case 10:
        return "Consommez pour jouer un tour supplémentaire.";
      case 11:
        return "Utilisez pour tenter de voler une baie (75% de réussite, risque de perdre 3 baies).";
      case 12:
        return "Force les 2 prochains tirages à être des cartes liées à des thèmes historiques.";
      default:
        return "";
    }
  }

  Widget _buildItemLeading(Map<String, dynamic> item) {
    if (item['image'] != null && (item['image'] as String).isNotEmpty) {
      return Image.asset(
        'assets/images/${item['image']}',
        width: 80, // Image légèrement agrandie
        height: 80,
        fit: BoxFit.contain,
      );
    }
    return const Icon(Icons.collections, color:Color.fromARGB(196, 64, 147, 63));
  }

  void _confirmDiscard(Map<String, dynamic> item) {
    final itemId = item['itemId'];
    final itemName = item['name'] ?? 'this item';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          title: Text(
            'Discard item?',
            style: AppTheme.themeData.textTheme.bodyLarge,
          ),
          content: Text(
            'Are you sure you want to discard $itemName?',
            style: AppTheme.themeData.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Color.fromARGB(196, 64, 147, 63))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Discard', style: TextStyle(color:  Color.fromARGB(196, 64, 147, 63))),
              onPressed: () {
                Navigator.of(context).pop();
                widget.gameService.discardObject(widget.gameId, widget.playerId, itemId);
              },
            ),
          ],
        );
      },
    );
  }
}
