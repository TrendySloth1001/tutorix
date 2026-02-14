class WardModel {
  final String id;
  final String name;
  final String? picture;
  final String parentId;

  const WardModel({
    required this.id,
    required this.name,
    this.picture,
    required this.parentId,
  });

  factory WardModel.fromJson(Map<String, dynamic> json) {
    return WardModel(
      id: json['id'] as String,
      name: json['name'] as String,
      picture: json['picture'] as String?,
      parentId: json['parentId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'picture': picture,
    'parentId': parentId,
  };
}
