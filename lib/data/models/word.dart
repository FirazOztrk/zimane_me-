class Word {
  const Word({
    required this.id,
    required this.kurdish,
    required this.image,
    required this.audio,
  });

  final String id;
  final String kurdish;
  final String image;
  final String audio;

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as String,
      kurdish: json['kurdish'] as String,
      image: json['image'] as String,
      audio: json['audio'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'kurdish': kurdish, 'image': image, 'audio': audio};
  }

  Word copyWith({String? id, String? kurdish, String? image, String? audio}) {
    return Word(
      id: id ?? this.id,
      kurdish: kurdish ?? this.kurdish,
      image: image ?? this.image,
      audio: audio ?? this.audio,
    );
  }
}
