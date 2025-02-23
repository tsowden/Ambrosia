// game/cardHandlers/challengeCardHandler.js

const redisClient = require('../../config/redis');
const GenericCardHandler = require('./genericCardHandler');

class ChallengeCardHandler extends GenericCardHandler {
  constructor(gameId, io) {
    super(gameId, io);
  }

  async handleCard(playerId, card) {
    await super.handleCard(playerId, card);
    console.log(`ChallengeCardHandler: Challenge card drawn. Waiting for 'startBetting'...`);
  }

  async startBetting() {
    try {
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'betting');
      await redisClient.hSet(`game:${this.gameId}`, 'bets', JSON.stringify({}));

      const cardJson = await redisClient.hGet(`game:${this.gameId}`, 'currentCard');
      const currentCard = JSON.parse(cardJson || '{}');

      this.io.to(this.gameId).emit('turnStateChanged', {
        turnState: 'betting',
        betOptions: currentCard.validBets ?? [],
      });
    } catch (error) {
      console.error('ChallengeCardHandler: Error starting betting phase:', error);
    }
  }

  async handleBet(playerId, bet) {
    try {
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const currentCard = JSON.parse(gameData.currentCard || '{}');
      const bets = JSON.parse(gameData.bets || '{}');

      const validBets = currentCard.validBets || [];

      if (!validBets.includes(bet)) {
        console.error(`ChallengeCardHandler: Invalid bet "${bet}" from player ${playerId}`);
        return { error: 'Invalid bet' };
      }

      bets[playerId] = bet;
      await redisClient.hSet(`game:${this.gameId}`, 'bets', JSON.stringify(bets));
      console.log(`ChallengeCardHandler: Bet "${bet}" recorded for player ${playerId}.`);

      const players = JSON.parse(gameData.players || '[]');
      const nonActivePlayers = players.filter((p) => p.playerId !== gameData.activePlayerId);
      if (Object.keys(bets).length >= nonActivePlayers.length) {
        console.log(`ChallengeCardHandler: All bets received`);
        setTimeout(async () => {
          console.log(`ChallengeCardHandler: Starting challenge after delay`);
          await this.startChallenge();
        }, 2000);
      }
    } catch (error) {
      console.error(`ChallengeCardHandler: Error handling bet:`, error);
    }
  }

  async startChallenge() {
    try {
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'challengeInProgress');
      await redisClient.hSet(`game:${this.gameId}`, 'votes', JSON.stringify({}));

      const cardJson = await redisClient.hGet(`game:${this.gameId}`, 'currentCard');
      const currentCard = JSON.parse(cardJson || '{}');

      this.io.to(this.gameId).emit('turnStateChanged', {
        turnState: 'challengeInProgress',
        betOptions: currentCard.validBets ?? [], 
      });

      console.log(`ChallengeCardHandler: Challenge started for game ${this.gameId}.`);
    } catch (error) {
      console.error(`ChallengeCardHandler: Error starting challenge:`, error);
    }
  }

  async processChallengeResult(playerId, result) {
    try {
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'result');

      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const bets = JSON.parse(gameData.bets || '{}');
      const players = JSON.parse(gameData.players || '[]');
      const activePlayer = players.find((p) => p.playerId === playerId);

      if (!activePlayer) {
        console.error(`ChallengeCardHandler: Player with ID ${playerId} not found for result processing.`);
        return;
      }

      console.log(`ChallengeCardHandler: Processing result for player ${activePlayer.playerName}. Result: ${result}`);

      // Mise à jour des scores et ajout des baies (berries)
      const currentCard = JSON.parse(gameData.currentCard || '{}');
      const betOptions = currentCard.validBets || [];
      const rewardOptions = currentCard.rewardOptions || [];
      const idx = betOptions.indexOf(result);
      let berryReward = 0;

      if (idx !== -1 && rewardOptions[idx]) {
        berryReward = parseInt(rewardOptions[idx].replace('b', ''), 10);
      }

      for (const [bettingPlayerId, bet] of Object.entries(bets)) {
        const bettingPlayer = players.find((p) => p.playerId === bettingPlayerId);
        if (bettingPlayer && bet === result) {
          bettingPlayer.score = (bettingPlayer.score || 0) + 1;
        }
      }
      if (result === 'success') {
        activePlayer.score = (activePlayer.score || 0) + 2;
      }

      // Ajouter les berries au joueur actif
      activePlayer.berries = (activePlayer.berries || 0) + berryReward;
      await redisClient.hSet(`game:${this.gameId}`, 'players', JSON.stringify(players));

      // Notifier tous les clients
      this.io.to(this.gameId).emit('challengeResult', {
        activePlayerName: activePlayer.playerName,
        result,
        berryReward,
        rewards: players.map((p) => ({
          playerName: p.playerName,
          score: p.score || 0,
          berries: p.berries || 0,
        })),
        majorityVote: result,
      });

      console.log("DEBUG - challengeResult event data:", {
        activePlayerName: activePlayer.playerName,
        result,
        berryReward,
        rewards: players.map((p) => ({
          playerName: p.playerName,
          score: p.score || 0,
          berries: p.berries || 0,
        })),
        majorityVote: result,
      });

      console.log(`ChallengeCardHandler: Challenge result broadcasted (game ${this.gameId}). Berry reward: ${berryReward}`);
    } catch (error) {
      console.error(`ChallengeCardHandler: Error processing challenge result:`, error);
    }
  }

  async handleChallengeVote(playerId, vote) {
    try {
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const votes = JSON.parse(gameData.votes || '{}');
      votes[playerId] = vote;
      await redisClient.hSet(`game:${this.gameId}`, 'votes', JSON.stringify(votes));

      const players = JSON.parse(gameData.players || '[]');
      const nonActivePlayers = players.filter((p) => p.playerId !== gameData.activePlayerId);

      if (Object.keys(votes).length >= Math.ceil(nonActivePlayers.length / 2)) {
        const voteCounts = {};
        Object.values(votes).forEach((v) => {
          voteCounts[v] = (voteCounts[v] || 0) + 1;
        });

        const maxVotes = Math.max(...Object.values(voteCounts));
        const majorityVotes = Object.keys(voteCounts).filter(
          (option) => voteCounts[option] === maxVotes
        );

        if (majorityVotes.length === 1) {
          const majorityVote = majorityVotes[0];
          await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'result');
          await redisClient.hSet(`game:${this.gameId}`, 'majorityVote', majorityVote);
          await this.processChallengeResult(gameData.activePlayerId, majorityVote);
        }
      } else {
        this.io.to(this.gameId).emit('challengeVotesUpdated', { isMajorityReached: false });
      }
    } catch (error) {
      console.error(`ChallengeCardHandler: Error processing challenge vote:`, error);
    }
  }

  async transitionToNextTurn() {
    try {
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      let currentIndex = players.findIndex((p) => p.playerId === gameData.activePlayerId);

      if (currentIndex === -1) {
        console.error(`ChallengeCardHandler: Active player not found in game ${this.gameId}.`);
        return;
      }

      currentIndex = (currentIndex + 1) % players.length;
      const nextPlayer = players[currentIndex];

      await redisClient.hSet(`game:${this.gameId}`, 'activePlayerId', nextPlayer.playerId);

      this.io.to(this.gameId).emit('activePlayerChanged', {
        activePlayerId: nextPlayer.playerId,
        activePlayerName: nextPlayer.playerName,
        turnState: 'movement',
      });
      console.log(`ChallengeCardHandler: Turn ended. Next player: ${nextPlayer.playerName} (game ${this.gameId})`);
    } catch (error) {
      console.error(`ChallengeCardHandler: Error transitioning to next turn:`, error);
    }
  }
}

module.exports = ChallengeCardHandler;
