// cardHandlers/quizCardHandler.js
const redisClient = require('../../config/redis');
const GenericCardHandler = require('./genericCardHandler');
const quizModel = require('../../models/quiz');

class QuizCardHandler extends GenericCardHandler {
  constructor(gameId, io) {
    super(gameId, io);
  }

  async handleCard(playerId, card) {
    await super.handleCard(playerId, card);
    console.log("QuizCardHandler: Quiz card drawn. Waiting for 'startQuiz'...");
    // On attend l'événement 'startQuiz'
  }

  /**
   * startQuiz : démarre le quiz en récupérant 3 questions selon le thème et la difficulté choisis
   */
  async startQuiz(playerId, chosenTheme, chosenDifficulty) {
    try {
      // 1) On passe le turnState à "quizInProgress"
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'quizInProgress');

      // 2) Récupérer 3 questions pour le thème et la difficulté sélectionnée
      const questions = await quizModel.getThreeQuestions(chosenTheme, chosenDifficulty);
      console.log("QuizCardHandler: Questions récupérées, difficultés =", questions.map(q => q.question_difficulty));

      // 3) Créer l'état quizState et le stocker
      const quizState = {
        questions,                 // Liste de 3 questions
        currentQuestion: 0,        // Index de la question courante
        correctAnswers: 0,         // nombre de réponses correctes du joueur actif
        earnedBerries: 0,         // (éventuel usage ultérieur)
        chosenTheme,               // Thème choisi
        chosenDifficulty,          // "Débutant" ou "Expert"
        nonActiveAnswers: {},      // Pour stocker les réponses des joueurs passifs
      };
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));

      // 4) Informer le front que le quiz est démarré
      this.io.to(this.gameId).emit('quizStarted', {
        chosenTheme,
        chosenDifficulty,
      });

      // 5) Envoyer la première question
      await this.sendNextQuestion();
    } catch (error) {
      console.error('QuizCardHandler: Error starting quiz:', error);
    }
  }

  /**
   * Envoi de la question courante, ou fin du quiz si on a épuisé les questions
   */
  async sendNextQuestion() {
    try {
      const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
      const quizState = JSON.parse(quizStateJson || '{}');

      // Si on a déjà dépassé le nombre de questions, on termine
      if (quizState.currentQuestion >= quizState.questions.length) {
        console.log('QuizCardHandler: All questions answered. Ending quiz.');
        await this.endQuiz();
        return;
      }

      // Empêche un double passage à la question suivante
      quizState.hasMovedOn = false;
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));

      // Récupère la question courante
      const question = quizState.questions[quizState.currentQuestion];

      // Émet la question sur la room
      this.io.to(this.gameId).emit('quizQuestion', {
        questionIndex: quizState.currentQuestion,
        questionId: question.question_id,
        questionDescription: question.question_description,
        questionImage: question.question_image,
        questionOptions: JSON.parse(question.question_options),  // un array d'options
        questionDifficulty: parseInt(question.question_difficulty, 10),
        questionCategory: question.question_category,
      });

      console.log(`QuizCardHandler: Sending question #${quizState.currentQuestion + 1} (difficulty ${question.question_difficulty})`);
    } catch (error) {
      console.error('QuizCardHandler: Error sending next question:', error);
    }
  }

  /**
   * handleAnswer : traitement de la réponse d'un joueur
   */
  async handleAnswer(playerId, givenAnswer) {
    try {
      // Récupère l'état du quiz
      const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
      const quizState = JSON.parse(quizStateJson || '{}');
      const currentQIndex = quizState.currentQuestion;
      const question = quizState.questions[currentQIndex];
      if (!question) {
        console.log('QuizCardHandler: No question found => maybe quiz ended?');
        return;
      }

      const isCorrect = (givenAnswer === question.question_answer);

      // Récupération du joueur actif
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const activePlayerId = gameData.activePlayerId;

      if (playerId === activePlayerId) {
        // (1) Réponse du joueur actif
        if (givenAnswer !== 'TIMED_OUT' && isCorrect) {
          quizState.correctAnswers += 1;
        }

        // Notifie tout le monde de la réponse
        this.io.to(this.gameId).emit('quizAnswerResult', {
          questionIndex: currentQIndex,
          correctAnswer: question.question_answer,
          givenAnswer,
          isCorrect,
          playerId,
        });

        // Passe à la question suivante (avec un setTimeout pour laisser 1 seconde d'affichage)
        if (!quizState.hasMovedOn) {
          quizState.currentQuestion += 1;
          quizState.hasMovedOn = true;
          await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));
          setTimeout(() => {
            this.sendNextQuestion();
          }, 1000);
        }
      } else {
        // (2) Réponse d'un joueur non actif
        if (!quizState.nonActiveAnswers[playerId]) {
          quizState.nonActiveAnswers[playerId] = { correct: 0, total: 0 };
        }
        quizState.nonActiveAnswers[playerId].total += 1;
        if (givenAnswer !== 'TIMED_OUT' && isCorrect) {
          quizState.nonActiveAnswers[playerId].correct += 1;
        }

        // Notifie seulement ce joueur (le passif) de son feedback
        this.io.to(playerId).emit('quizAnswerResult', {
          questionIndex: currentQIndex,
          correctAnswer: question.question_answer,
          givenAnswer,
          isCorrect,
          playerId,
        });
      }

      // Sauvegarde l'état quizState
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));
      console.log(`QuizCardHandler: Player ${playerId} answered: correct? ${isCorrect}`);
    } catch (error) {
      console.error('QuizCardHandler: Error handling quiz answer:', error);
    }
  }

  /**
   * endQuiz : calcule les récompenses, modifie le joueur actif, envoie quizEnd
   */
  async endQuiz() {
    try {
      console.log('QuizCardHandler: Ending quiz...');
      const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
      const quizState = JSON.parse(quizStateJson || '{}');
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'quizResult');

      const difficulty = quizState.chosenDifficulty; // "Débutant" / "Expert"
      const activeCorrect = quizState.correctAnswers;

      // Détermine la reward du joueur actif
      let activeReward = 0;
      if (difficulty === "Débutant") {
        if (activeCorrect === 0) activeReward = -1;
        else if (activeCorrect === 1) activeReward = 0;
        else if (activeCorrect === 2) activeReward = 1;
        else if (activeCorrect === 3) activeReward = 2;
      } else if (difficulty === "Expert") {
        if (activeCorrect === 0) activeReward = 0;
        else if (activeCorrect === 1) activeReward = 1;
        else if (activeCorrect === 2) activeReward = 2;
        else if (activeCorrect === 3) activeReward = 3;
      }

      // Mise à jour du joueur actif
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const activePlayer = players.find(p => p.playerId === gameData.activePlayerId);

      let activeResultMessage = "";
      if (activePlayer) {
        activePlayer.berries = (activePlayer.berries || 0) + activeReward;

        // Message "intemporel" (existant déjà dans votre code)
        if (difficulty === "Débutant") {
          if (activeCorrect === 0) activeResultMessage = "Malheureusement, vous avez échoué et perdez 1 Faveur Divine.";
          else if (activeCorrect === 1) activeResultMessage = "Vous avez 1 bonne réponse, ce qui ne vous rapporte rien.";
          else if (activeCorrect === 2) activeResultMessage = "Bon travail ! 2 bonnes réponses vous rapportent 1 Faveur Divine.";
          else if (activeCorrect === 3) activeResultMessage = "Excellent ! Vous avez toutes les réponses correctes et obtenez 2 Faveurs Divines.";
        } else {
          // Expert
          if (activeCorrect === 0) activeResultMessage = "Vous n'avez aucune bonne réponse, aucune Faveur Divine n'est accordée.";
          else if (activeCorrect === 1) activeResultMessage = "Vous avez 1 bonne réponse et gagnez 1 Faveur Divine.";
          else if (activeCorrect === 2) activeResultMessage = "Bien joué ! 2 bonnes réponses vous rapportent 2 Faveurs Divines.";
          else if (activeCorrect === 3) activeResultMessage = "Parfait ! Vous avez toutes les réponses correctes et obtenez 3 Faveurs Divines.";
        }
      }

      // Calcul des récompenses pour les joueurs non actifs
      const nonActiveResults = [];
      if (quizState.nonActiveAnswers && typeof quizState.nonActiveAnswers === 'object') {
        for (const pId in quizState.nonActiveAnswers) {
          const result = quizState.nonActiveAnswers[pId]; // { correct, total }
          let nonActiveReward = 0;

          // En mode "Expert", 3/3 correct => 50% chance +1
          if (difficulty === "Expert" && result.correct === 3) {
            nonActiveReward = (Math.random() < 0.5) ? 1 : 0;
          }

          // Message "intemporel" déjà existant
          let message = `Vous avez obtenu ${result.correct} bonne(s) réponse(s).`;
          message += nonActiveReward > 0 ? " Vous gagnez 1 Faveur Divine !" : " Aucune Faveur Divine n'est accordée.";

          // Mise à jour du player passif
          const nonActivePlayer = players.find(p => p.playerId === pId);
          if (nonActivePlayer) {
            nonActivePlayer.berries = (nonActivePlayer.berries || 0) + nonActiveReward;
          }

          // On push dans nonActiveResults
          nonActiveResults.push({
            playerId: pId,
            correct: result.correct,
            total: result.total,
            reward: nonActiveReward,
            message,
          });
        }
      }

      await redisClient.hSet(`game:${this.gameId}`, 'players', JSON.stringify(players));

      // Émission de l'événement final quizEnd
      this.io.to(this.gameId).emit('quizEnd', {
        activePlayerId: activePlayer ? activePlayer.playerId : null,
        chosenDifficulty: difficulty, // <-- On inclut la difficulté pour l'affichage front
        activeResult: {
          correctAnswers: activeCorrect,
          totalQuestions: quizState.questions.length,
          reward: activeReward,
          message: activeResultMessage,
        },
        nonActiveResults,
      });
    } catch (error) {
      console.error('QuizCardHandler: Error ending quiz:', error);
    }
  }
}

module.exports = QuizCardHandler;
