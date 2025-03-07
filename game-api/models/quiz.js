// models/quiz.js
const db = require('../config/db'); 

async function getThreeQuestions(category, difficultyChoice) {
  let allowedDifficulties = [];
  if (difficultyChoice === "Débutant") {
    allowedDifficulties = [1, 2];
  } else if (difficultyChoice === "Expert") {
    allowedDifficulties = [2, 3];
  } else {
    allowedDifficulties = [1, 2, 3];
  }
  // On force la conversion de question_difficulty en entier pour éviter des problèmes de type
  const placeholders = allowedDifficulties.map(() => '?').join(',');
  const query = `
    SELECT * FROM questions
    WHERE question_category = ?
    AND CAST(question_difficulty AS UNSIGNED) IN (${placeholders})
    ORDER BY RAND()
    LIMIT 3
  `;
  const params = [category, ...allowedDifficulties];
  const [rows] = await db.query(query, params);
  return rows;
}

module.exports = {
  getThreeQuestions,
};
