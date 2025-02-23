class CardModel {
  final int id;
  final String name;
  final String description;
  final String image;

  CardModel({required this.id, required this.name, required this.description, required this.image});

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      image: json['image'],
    );
  }
}
