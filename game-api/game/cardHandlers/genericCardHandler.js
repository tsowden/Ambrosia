// cardHandlers/GenericCardHandler.js
const redisClient = require('../../config/redis');

class GenericCardHandler {
  constructor(gameId, io) {
    this.gameId = gameId;
    this.io = io;
  }

  /**
   * handleCard : logique minimale d'affichage/stockage commune à tous les types de cartes
   */
  async handleCard(playerId, card) {
    try {
      // 1) Mettre à jour l'état du tour
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'cardDrawn');

      // 2) Récupérer le joueur actif
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const activePlayer = players.find((p) => p.playerId === playerId);

      if (!activePlayer) {
        console.error(`GenericCardHandler: Active player with ID ${playerId} not found.`);
        return;
      }

      // 3) Préparer la description “passive”
      const cardDescriptionPassive = card.card_description_passif
        ? card.card_description_passif.replaceAll('{activePlayerName}', activePlayer.playerName)
        : 'Aucune description passive.';

      // 4) Gérer les options de pari (si pertinent)
      const betOptions = card.card_choice ? card.card_choice.split(';') : [];
      const rewardOptions = card.card_reward ? card.card_reward.split(';') : [];

      // 5) Stocker la carte courante dans Redis
      await redisClient.hSet(`game:${this.gameId}`, 'currentCard', JSON.stringify({
        ...card,
        validBets: betOptions,
        rewardOptions: rewardOptions,
      }));

      

      // 6) Notifier tous les joueurs (émission “cardDrawn”)
      console.log('DEBUG - Emitting cardDrawn with:', {
        cardCategory: card.card_category,
        cardTheme: card.card_choice,
      });
      this.io.to(this.gameId).emit('cardDrawn', {
        activePlayerName: activePlayer.playerName,
        cardDescription: card.card_description || 'Aucune description disponible.',
        cardDescriptionPassive: cardDescriptionPassive,
        cardName: card.card_name || 'Carte inconnue',
        cardImage: card.card_image || null,
        cardTheme: card.card_choice || '',
        cardSubheading: card.card_subheading || '', 
        cardCategory: card.card_category || 'Catégorie inconnue',
        turnState: 'cardDrawn',
        betOptions: betOptions || null,
      });


      console.log(`GenericCardHandler: Card "${card.card_name}" drawn for ${activePlayer.playerName} in game ${this.gameId}.`);
    } catch (error) {
      console.error(`GenericCardHandler: Error handling card for player ${playerId} in game ${this.gameId}:`, error);
    }
  }
}

module.exports = GenericCardHandler;
