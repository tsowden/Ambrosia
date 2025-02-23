class QuestionModel {
  final int id;
  final String description;
  final List<String> options;
  final int difficulty;

  QuestionModel({required this.id, required this.description, required this.options, required this.difficulty});

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'],
      description: json['description'],
      options: List<String>.from(json['options']),
      difficulty: json['difficulty'],
    );
  }
}
