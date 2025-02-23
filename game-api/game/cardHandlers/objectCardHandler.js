const redisClient = require('../../config/redis');
const GenericCardHandler = require('./genericCardHandler');

class ObjectCardHandler extends GenericCardHandler {
  constructor(gameId, io) {
    super(gameId, io);
  }

  async handleCard(playerId, card) {
    // 1) Appeler super.handleCard pour la logique "générique" 
    await super.handleCard(playerId, card);

    console.log(`ObjectCardHandler: Object card drawn -> ${card.card_name} for player ${playerId}`);

    // On attend que le joueur clique "Ramasser"
  }

  async pickUpObject(gameId, playerId, cardName) {
    try {
      const inventoryKey = `inventory:${gameId}:${playerId}`;

      // 1) Ajouter l'objet à l'inventaire dans Redis
      await redisClient.sadd(inventoryKey, cardName);

      // 2) Envoyer une confirmation au frontend
      this.io.to(gameId).emit('objectPickedUp', {
        playerId: playerId,
        objectName: cardName,
      });

      console.log(`ObjectCardHandler: ${cardName} ajouté à l'inventaire du joueur ${playerId}.`);
    } catch (error) {
      console.error(`ObjectCardHandler: Erreur lors de l'ajout de ${cardName} à l'inventaire du joueur ${playerId}:`, error);
    }
  }
}

module.exports = ObjectCardHandler;
