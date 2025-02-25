// lib/widgets/dungeon_view.dart

import 'dart:math';
import 'package:flutter/material.dart';

/// Représente la cellule calculée
class _CellInfo {
  final bool isPlayer;
  final bool accessible;
  final bool isEdge; // Bord de la grande map
  final String edgeSide; // "top", "bottom", "left", "right", ou ""
  final double fadeFactor;

  _CellInfo({
    required this.isPlayer,
    required this.accessible,
    required this.isEdge,
    required this.edgeSide,
    required this.fadeFactor,
  });
}

/// Widget qui affiche un carré 5×5 autour du joueur
class Dungeon7x7 extends StatelessWidget {
  final List<List<Map<String, dynamic>>> mapObjects;
  final int playerX;
  final int playerY;
  final String playerOrientation;
  final double cellSize;
  final String stepMessage;

  // Couleurs custom
  static const accessibleColor = Color(0xFFCFD8DC); // bleu-gris clair
  static const inaccessibleColor = Color(0xFF455A64); // bleu-gris foncé

  const Dungeon7x7({
    Key? key,
    required this.mapObjects,
    required this.playerX,
    required this.playerY,
    required this.playerOrientation,
    this.cellSize = 50.0,
    this.stepMessage = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final matrix = _buildMatrix();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stepMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              stepMessage,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (row) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (col) {
                final cell = matrix[row][col];
                return _buildOneCell(cell);
              }),
            );
          }),
        ),
      ],
    );
  }

  List<List<_CellInfo>> _buildMatrix() {
    const size = 5;
    const center = 2;
    final maxRows = mapObjects.length;
    final maxCols = (maxRows > 0) ? mapObjects[0].length : 0;
    final matrix = List.generate(
      size,
      (_) => List.generate(
        size,
        (_) => _CellInfo(isPlayer: false, accessible: false, isEdge: false, edgeSide: '', fadeFactor: 1.0),
      ),
    );

    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        final dx = col - center;
        final dy = row - center;
        final mapX = playerX + dx;
        final mapY = playerY + dy;
        bool accessible = false;
        bool isPlayer = false;
        bool isEdge = false;
        String edgeSide = '';
        double fadeFactor = 1.0;

        final dist = sqrt(pow(col - center, 2) + pow(row - center, 2));
        fadeFactor = (1.0 - dist * 0.15).clamp(0.2, 1.0);

        if (mapY >= 0 && mapY < maxRows && mapX >= 0 && mapX < maxCols) {
          final obj = mapObjects[mapY][mapX];
          accessible = (obj['accessible'] == true);
          if (mapX == playerX && mapY == playerY) {
            isPlayer = true;
          }
          if (mapY == 0) {
            isEdge = true;
            edgeSide = 'top';
          } else if (mapY == maxRows - 1) {
            isEdge = true;
            edgeSide = 'bottom';
          } else if (mapX == 0) {
            isEdge = true;
            edgeSide = 'left';
          } else if (mapX == maxCols - 1) {
            isEdge = true;
            edgeSide = 'right';
          }
        }
        matrix[row][col] = _CellInfo(
          isPlayer: isPlayer,
          accessible: accessible,
          isEdge: isEdge,
          edgeSide: edgeSide,
          fadeFactor: fadeFactor,
        );
      }
    }
    return matrix;
  }

  Widget _buildOneCell(_CellInfo cell) {
    final baseColor = cell.accessible ? accessibleColor : inaccessibleColor;
    final color = baseColor.withOpacity(cell.fadeFactor);
    return Container(
      margin: const EdgeInsets.all(1.0),
      width: cellSize,
      height: cellSize,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: color)),
          if (cell.isPlayer)
            Center(
              child: Transform.rotate(
                angle: _rotationAngleForOrientation(playerOrientation),
                child: Icon(
                  Icons.navigation, // flèche du joueur
                  color: Colors.white.withOpacity(cell.fadeFactor),
                  size: cellSize * 0.6,
                ),
              ),
            ),
          if (cell.isEdge && !cell.isPlayer)
            Positioned(
              right: 2,
              bottom: 2,
              child: _buildEdgeArrow(cell.edgeSide, cell.fadeFactor),
            ),
        ],
      ),
    );
  }

  double _rotationAngleForOrientation(String orientation) {
    switch (orientation.toLowerCase()) {
      case 'north':
        return 0.0;
      case 'east':
        return pi / 2;
      case 'south':
        return pi;
      case 'west':
        return -pi / 2;
      default:
        return 0.0;
    }
  }

  Widget _buildEdgeArrow(String side, double fade) {
    IconData icon;
    switch (side) {
      case 'top':
        icon = Icons.arrow_upward;
        break;
      case 'bottom':
        icon = Icons.arrow_downward;
        break;
      case 'left':
        icon = Icons.arrow_back;
        break;
      case 'right':
        icon = Icons.arrow_forward;
        break;
      default:
        icon = Icons.exit_to_app;
        break;
    }
    return Icon(
      icon,
      color: Colors.white.withOpacity(fade),
      size: cellSize * 0.4,
    );
  }
}
