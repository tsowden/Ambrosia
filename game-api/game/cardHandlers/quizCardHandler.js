// game/cardHandlers/quizCardHandler.js

const redisClient = require('../../config/redis');
const GenericCardHandler = require('./genericCardHandler');
const quizModel = require('../../models/quiz');

class QuizCardHandler extends GenericCardHandler {
  constructor(gameId, io) {
    super(gameId, io);
  }

  async handleCard(playerId, card) {
    await super.handleCard(playerId, card);

    console.log(`QuizCardHandler: Quiz card drawn. Waiting for 'startQuiz'...`);
    // Ici, on ne commence pas le quiz tout de suite. 
    // On attend l'événement socket "startQuiz" que le front enverra
    // lorsque le joueur aura cliqué sur un thème.
  }

  /**
   * startQuiz : appelé lorsqu'on reçoit l'événement 'startQuiz'
   *   - On va chercher 3 questions dans la DB pour le thème choisi
   *   - On stocke tout ça + le "reward pattern" dans quizState
   *   - On émet un événement 'quizStarted' et on enchaîne la première question
   */
  async startQuiz(playerId, chosenTheme) {
    try {
      // 1) On récupère la carte courante
      const cardJson = await redisClient.hGet(`game:${this.gameId}`, 'currentCard');
      const currentCard = JSON.parse(cardJson || '{}');

      // 2) On récupère le reward pattern (ex. "1b;2b;3b") et on le parse
      const cardRewardString = currentCard.card_reward || '1b;2b;3b';
      const rewardPattern = cardRewardString.split(';').map(r => parseInt(r.replace('b', ''), 10));
      // ex: [1, 2, 3]

      // 3) On passe le turnState à "quizInProgress"
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'quizInProgress');

      // 4) Récupérer 3 questions pour le thème choisi
      //    (on suppose un helper quizModel.getThreeQuestions(chosenTheme))
      const questions = await quizModel.getThreeQuestions(chosenTheme);

      // 5) Créer l'état "quizState" et le stocker
      const quizState = {
        questions,           // liste de 3 questions
        currentQuestion: 0,  // index sur la question courante
        correctAnswers: 0,
        earnedBerries: 0,
        rewardPattern,       // ex: [1, 2, 3]
        chosenTheme,         // "Explorers history" ou "Exotic Nature"
      };
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));

      // 6) Émettre un événement "quizStarted" => 
      //    le front saura qu'on a choisi <chosenTheme> et qu'on démarre 
      this.io.to(this.gameId).emit('quizStarted', {
        chosenTheme,
      });

      // 7) Envoyer la première question
      await this.sendNextQuestion();
    } catch (error) {
      console.error('QuizCardHandler: Error starting quiz:', error);
    }
  }

  async sendNextQuestion() {
    try {
      const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
      const quizState = JSON.parse(quizStateJson || '{}');
  
      if (quizState.currentQuestion >= quizState.questions.length) {
        console.log('QuizCardHandler: All questions answered. Ending quiz.');
        await this.endQuiz();
        return;
      }
  
      // Remettre hasMovedOn = false pour permettre l'incrément à la question suivante
      quizState.hasMovedOn = false; 
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));
  
      const question = quizState.questions[quizState.currentQuestion];
  
      this.io.to(this.gameId).emit('quizQuestion', {
        questionIndex: quizState.currentQuestion,
        questionId: question.question_id,
        questionDescription: question.question_description,
        questionImage: question.question_image,
        questionOptions: JSON.parse(question.question_options),
        questionDifficulty: question.question_difficulty,
        questionCategory: question.question_category,
      });
  
      console.log(`QuizCardHandler: Sending question #${quizState.currentQuestion + 1} in theme "${quizState.chosenTheme}"`);
    } catch (error) {
      console.error('QuizCardHandler: Error sending next question:', error);
    }
  }
  


  /**
   * handleAnswer : quand le joueur actif répond
   */
  async handleAnswer(playerId, givenAnswer) {
    try {
      const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
      const quizState = JSON.parse(quizStateJson || '{}');
  
      const currentQIndex = quizState.currentQuestion;
      const question = quizState.questions[currentQIndex];
      if (!question) {
        console.log('QuizCardHandler: No question found => maybe quiz ended?');
        return;
      }
  
      // Si la réponse n'est pas "TIMED_OUT" ET qu'elle est correcte => on incrémente correctAnswers
      const isCorrect = (givenAnswer === question.question_answer);
      if (givenAnswer !== 'TIMED_OUT' && isCorrect) {
        quizState.correctAnswers += 1;
        // On ajoute la récompense associée
        const questionReward = quizState.rewardPattern[currentQIndex] || 0;
        quizState.earnedBerries += questionReward;
      }
  
      // On stocke l'état mis à jour
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));
  
      // On émet "quizAnswerResult"
      this.io.to(this.gameId).emit('quizAnswerResult', {
        questionIndex: currentQIndex,
        correctAnswer: question.question_answer,
        givenAnswer,
        isCorrect,
      });
  
      console.log(`QuizCardHandler: Player ${playerId} => correct? ${isCorrect}`);
  
      // -------------------------------
      // ÉVITER LE "DOUBLE INCRÉMENT"
      // -------------------------------
      // Au lieu d'incrémenter systématiquement currentQuestion,
      // on peut soit :
      //  1) Le faire qu'une seule fois
      //  2) Ajouter un flag "alreadyMovedOn"
      //  3) Ou conditionner à "givenAnswer !== 'TIMED_OUT'"
      //
      // Ex. si on veut passer à la question suivante
      // même en cas de "TIMED_OUT", on peut le faire
      // UNE seule fois :
  
      if (!quizState.hasMovedOn) {   // Flag pour éviter l'incrément multiple
        quizState.currentQuestion += 1;
        quizState.hasMovedOn = true; // On mémorise qu'on a avancé
        await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));
  
        setTimeout(() => {
          this.sendNextQuestion();
        }, 1000);
      }
  
    } catch (error) {
      console.error('QuizCardHandler: Error handling quiz answer:', error);
    }
  }
  

  async endQuiz() {
    try {
        console.log('QuizCardHandler: Ending quiz...');
        const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
        const quizState = JSON.parse(quizStateJson || '{}');

        await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'quizResult');

        // Mise à jour du joueur actif dans Redis
        const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
        const players = JSON.parse(gameData.players || '[]');
        const activePlayer = players.find((p) => p.playerId === gameData.activePlayerId);

        if (activePlayer) {
            // Ajout des berries gagnés uniquement au joueur actif
            activePlayer.berries = (activePlayer.berries || 0) + quizState.earnedBerries;
            await redisClient.hSet(`game:${this.gameId}`, 'players', JSON.stringify(players));

            console.log(`QuizCardHandler: ${activePlayer.playerName} earned ${quizState.earnedBerries} berries.`);
        }

        // Émettre "quizEnd" avec les données du joueur actif
        this.io.to(this.gameId).emit('quizEnd', {
            playerId: activePlayer?.playerId,
            correctAnswers: quizState.correctAnswers,
            totalQuestions: quizState.questions.length,
            earnedBerries: quizState.earnedBerries,
        });

    } catch (error) {
        console.error('QuizCardHandler: Error ending quiz:', error);
    }
  }

}

module.exports = QuizCardHandler;
