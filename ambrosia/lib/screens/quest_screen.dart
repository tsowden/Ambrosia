// lib/screens/quest_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';

class QuestScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final GameService gameService;

  const QuestScreen({
    Key? key,
    required this.gameId,
    required this.playerId,
    required this.gameService,
  }) : super(key: key);

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  int _berries = 0;
  bool _hasExitedForest = false;

  @override
  void initState() {
    super.initState();
    // Écoute des infos de la partie pour mettre à jour le nombre de baies
    widget.gameService.onGameInfos((data) {
      if (!mounted) return;
      final playersData = data['players'] ?? [];
      if (playersData is List) {
        final me = playersData.firstWhere(
          (p) => p['playerId'] == widget.playerId,
          orElse: () => null,
        );
        if (me != null && me is Map) {
          final newBerries = me['berries'] ?? 0;
          setState(() {
            _berries = newBerries;
          });
        }
      }
    });
    // Demande explicite d'actualisation des infos dès l'ouverture de l'écran
    widget.gameService.socket.emit('requestGameInfos', {
      'gameId': widget.gameId,
    });
  }

  Widget _buildQuestContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Alignement à gauche pour les items
        children: [
          // Titre "Quests" centré
          Center(
            child: Text(
              'Quests',
              style: AppTheme.themeData.textTheme.displayLarge?.copyWith(
                fontSize: 36,
                color: AppTheme.accentYellow,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          // Image du renard, centrée
          Center(
            child: Image.asset(
              'assets/images/renard-malice.png',
              height: 180,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          // Titre "Objectifs principaux :" aligné à gauche
          Text(
            'Objectifs principaux :',
            style: AppTheme.themeData.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          // Objectif 1 : Collecter 30 baies
          _buildQuestItem(
            label: 'Collecter 30 baies : $_berries/30',
            isCompleted: (_berries >= 30),
          ),
          // Objectif 2 : Sortir de la forêt
          _buildQuestItem(
            label: 'Sortir de la forêt',
            isCompleted: _hasExitedForest,
            onTap: () {
              setState(() {
                _hasExitedForest = !_hasExitedForest;
              });
            },
          ),
          const SizedBox(height: 20),
          // Titre "Objectifs annexes :" aligné à gauche
          Text(
            'Objectifs annexes :',
            style: AppTheme.themeData.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          // Texte en italique
          Text(
            'Aucune quête annexe en cours',
            style: AppTheme.themeData.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestItem({
    required String label,
    required bool isCompleted,
    VoidCallback? onTap,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      checkColor: Colors.white,
      activeColor: AppTheme.primaryColor,
      value: isCompleted,
      onChanged: (val) {
        if (onTap != null) onTap();
      },
      title: Text(
        label,
        style: AppTheme.themeData.textTheme.bodyMedium,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    // L'écran prend toute la largeur et hauteur
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: AppTheme.backgroundDecoration(),
      child: SafeArea(
        child: SingleChildScrollView(
          child: _buildQuestContent(context),
        ),
      ),
    );
  }
}
