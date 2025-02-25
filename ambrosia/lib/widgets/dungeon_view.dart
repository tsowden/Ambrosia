// lib/widgets/dungeon_view.dart

import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

/// Représente un widget "9x9" affichant la portion du donjon autour du joueur.
/// - [mapBool] : booléen[y][x], true => accessible, false => mur
/// - [playerX], [playerY], [playerOrientation]
/// - [cellSize] : taille d'une case
/// - [stepMessage] : phrase style "Vous tournez à gauche"
/// - [onAnimationDone] : callback quand l'animation de déplacement est finie (facultatif).
class Dungeon9x9 extends StatefulWidget {
  final List<List<bool>> mapBool;
  final int playerX;
  final int playerY;
  final String playerOrientation;
  final double cellSize;
  final String stepMessage;
  final VoidCallback? onAnimationDone;

  const Dungeon9x9({
    Key? key,
    required this.mapBool,
    required this.playerX,
    required this.playerY,
    required this.playerOrientation,
    this.cellSize = 32.0,
    this.stepMessage = '',
    this.onAnimationDone,
  }) : super(key: key);

  @override
  State<Dungeon9x9> createState() => _Dungeon9x9State();
}

class _Dungeon9x9State extends State<Dungeon9x9> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _moveProgress = 1.0; // 1 => stable, 0 => animation départ

  @override
  void initState() {
    super.initState();
    // Contrôleur pour animer sur ~500ms
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        setState(() {
          _moveProgress = _animController.value;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // animation terminée
          if (widget.onAnimationDone != null) {
            widget.onAnimationDone!();
          }
        }
      });
    // Si on a un stepMessage, on lance l'anim => l'effet “vous tournez…”
    if (widget.stepMessage.isNotEmpty) {
      _animController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant Dungeon9x9 oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si le stepMessage change, on relance l’anim
    if (widget.stepMessage.isNotEmpty && widget.stepMessage != oldWidget.stepMessage) {
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On construit la grille 9×9
    final matrix = _buildMatrix9x9();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.stepMessage.isNotEmpty) ...[
          // Petit message (tourner à gauche, etc.)
          Opacity(
            opacity: 1.0 - _moveProgress, // le message disparaît quand l'anim progresse
            child: Text(
              widget.stepMessage,
              style: AppTheme.nunitoTextStyle(color: Colors.black, fontSize: 20, bold: true),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // La grille
        _buildGrid(matrix),
      ],
    );
  }

  Widget _buildGrid(List<List<_CellInfo>> matrix) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(9, (row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(9, (col) {
            final cell = matrix[row][col];
            return _buildOneCell(cell);
          }),
        );
      }),
    );
  }

  Widget _buildOneCell(_CellInfo cell) {
    // On calcule l'opacité => plus c'est loin, plus c'est transparent
    final distManhattan = (cell.gridRow - 4).abs() + (cell.gridCol - 4).abs();
    final maxDist = 8.0; // environ
    double alpha = 1.0 - (distManhattan / maxDist) * 0.6;
    alpha = alpha.clamp(0.3, 1.0);

    // Si c'est "derrière" le joueur => on l'assombrit comme un brouillard
    if (!cell.inFront) {
      alpha = 0.2; 
    }

    Color color;
    if (cell.isPlayer) {
      // Joueur
      color = Colors.orangeAccent;
    } else if (!cell.accessible) {
      // Mur
      color = Colors.blueGrey.shade700;
    } else {
      // Chemin
      color = Colors.white;
    }

    // "En marge" => icône exit
    final isEdge = (cell.gridRow == 0 || cell.gridRow == 8 || cell.gridCol == 0 || cell.gridCol == 8);

    return Container(
      width: widget.cellSize,
      height: widget.cellSize,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: color.withOpacity(alpha),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: cell.isPlayer
          ? const Icon(Icons.person, color: Colors.white)
          : isEdge && cell.accessible
              ? const Icon(Icons.exit_to_app, color: Colors.red, size: 18)
              : null,
    );
  }

  /// Construit le tableau 9×9
  List<List<_CellInfo>> _buildMatrix9x9() {
    // Centre => (4,4)
    // On parcourt row=0..8, col=0..8
    final matrix = List.generate(9, (row) => List.generate(9, (col) {
      return _CellInfo(row, col, false, false, false, true);
    }));

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final dx = col - 4; 
        final dy = row - 4; 
        final mapX = widget.playerX + dx;
        final mapY = widget.playerY + dy;

        bool accessible = false;
        if (_inBounds(mapX, mapY)) {
          accessible = widget.mapBool[mapY][mapX];
        }
        // Est-ce le joueur lui-même ?
        final isPlayer = (mapX == widget.playerX && mapY == widget.playerY);

        // Savoir si c’est dans le champ de vision (pas derrière)
        final inFront = _isInFront(mapX, mapY);

        matrix[row][col] = _CellInfo(row, col, isPlayer, accessible, inFront, true);
      }
    }
    return matrix;
  }

  bool _inBounds(int x, int y) {
    return (y >= 0 && y < widget.mapBool.length && x >= 0 && x < widget.mapBool[0].length);
  }

  bool _isInFront(int x, int y) {
    final dx = x - widget.playerX;
    final dy = y - widget.playerY;
    final ori = widget.playerOrientation;
    // ex: si orientation="north", tout ce qui est plus bas (dy>0) => derrière
    if (ori == 'north' && dy > 0) return false;
    if (ori == 'south' && dy < 0) return false;
    if (ori == 'east'  && dx < 0) return false;
    if (ori == 'west'  && dx > 0) return false;

    return true;
  }
}

/// Juste un container interne
class _CellInfo {
  final int gridRow; 
  final int gridCol;
  final bool isPlayer;
  final bool accessible;
  final bool inFront;
  final bool visible; 
  _CellInfo(this.gridRow, this.gridCol, this.isPlayer, this.accessible, this.inFront, this.visible);
}
