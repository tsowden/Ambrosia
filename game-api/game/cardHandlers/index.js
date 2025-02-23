// game/cardHandlers/index.js

const ChallengeCardHandler = require('./challengeCardHandler');
const GenericCardHandler = require('./genericCardHandler');
const QuizCardHandler = require('./quizCardHandler');
const ObjectCardHandler = require('./objectCardHandler');


function getCardHandlerForCategory(gameId, io, cardCategory) {
  switch (cardCategory) {
    case 'Challenge':
      return new ChallengeCardHandler(gameId, io);
    case 'Quiz': 
      return new QuizCardHandler(gameId, io);
    case 'Object':
      return new ObjectCardHandler(gameId, io);
    default:
      return new GenericCardHandler(gameId, io);
  }
}

module.exports = { getCardHandlerForCategory };
