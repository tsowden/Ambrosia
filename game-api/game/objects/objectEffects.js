// game/objects/objectEffects.js
const redisClient = require('../../config/redis');
const TurnManager = require('../turnManager'); // si besoin

/**
 * useObjectEffect
 * @param {string} gameId
 * @param {string} playerId
 * @param {object} item  (ex: { itemId, name, image, description })
 * @param {Array} players  la liste players de gameData
 * @param {object} gameData  le hash complet (contient activePlayerId, etc.)
 */
async function useObjectEffect(gameId, playerId, item, players, gameData) {
  const itemId = item.itemId;
  console.log(`useObjectEffect: itemId=${itemId}, name=${item.name}`);

  switch (itemId) {
    case 10: // Monster
      await handleMonsterUse(gameId, playerId, players, gameData);
      break;

    case 11: // Anneau unique
      await handleAnneauUse(gameId, playerId, players, gameData);
      break;

    case 12: // Licence d'histoire
      await handleLicenceUse(gameId, playerId, players, gameData);
      break;

    default:
      console.log(`No specific effect for itemId=${itemId}.`);
      break;
  }
}

async function handleMonsterUse(gameId, playerId, players, gameData) {
  console.log("Handling Monster use => double turn logic...");
  // 1) Stocker dans Redis un flag "doubleTurnPending" pour ce joueur
  const doubleTurnKey = `doubleTurn:${gameId}:${playerId}`;
  await redisClient.set(doubleTurnKey, '1');
  // 2) Retirer l'objet de l'inventaire (usage unique)
  removeItemFromInventory(players, playerId, 10);
  // 3) Sauvegarder players
  await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
  console.log("Monster effect: Next time the turn ends for this player, he continues once again!");
}

async function handleAnneauUse(gameId, playerId, players, gameData) {
  console.log("Handling Anneau unique => try to steal a berry...");
  if (gameData.activePlayerId !== playerId) {
    console.log("Anneau unique can only be used on your turn!");
    return;
  }
  const otherPlayers = players.filter(p => p.playerId !== playerId);
  if (otherPlayers.length === 0) return;
  const randomIndex = Math.floor(Math.random() * otherPlayers.length);
  const target = otherPlayers[randomIndex];
  const roll = Math.random();
  if (roll < 0.75) {
    if ((target.berries || 0) > 0) {
      target.berries -= 1;
      const me = players.find(p => p.playerId === playerId);
      if (me) me.berries = (me.berries || 0) + 1;
      console.log(`Anneau unique => success stealing from ${target.playerName}`);
    } else {
      console.log("Anneau unique => target has no berries => no effect");
    }
  } else {
    console.log("Anneau unique => fail => lose ring + 3 berries!");
    removeItemFromInventory(players, playerId, 11);
    const me = players.find(p => p.playerId === playerId);
    if (me) {
      me.berries = Math.max(0, (me.berries || 0) - 3);
    }
  }
  await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
}

async function handleLicenceUse(gameId, playerId, players, gameData) {
  console.log("Handling Licence d'histoire => forcing next draws among card IDs [2,3,6] for a number of turns...");

  await redisClient.set(`forcedDraw:${gameId}:${playerId}`, '2,3,6');   // force les prochaines pioches
  await redisClient.set(`forcedDrawCount:${gameId}:${playerId}`, '2');   // nombre de tours avec pioche forcée
  
  // retirer la licence de l'inventaire
  removeItemFromInventory(players, playerId, 12);

  await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
  console.log("Licence d'histoire: Forced draw activated for 2 draws among IDs [2,3].");
}

// supprime l'item (par itemId) de l'inventaire du joueur
function removeItemFromInventory(players, playerId, itemId) {
  const plyr = players.find(p => p.playerId === playerId);
  if (!plyr || !plyr.inventory) return;
  plyr.inventory = plyr.inventory.filter(i => i.itemId !== itemId);
}

module.exports = { useObjectEffect };
