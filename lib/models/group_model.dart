class GroupModel {
  final String id;
  final String name;
  final String currentLink;
  final String previousLink;
  final String imageUrl;
  final String category;
  final String subcategory;
  final String country;
  final String state;
  final String city;
  final String language;
  final String description;
  final String rules;
  final String ownerContact;
  final bool showOwnerContact;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.currentLink,
    this.previousLink = '',
    required this.imageUrl,
    required this.category,
    required this.subcategory,
    required this.country,
    required this.state,
    required this.city,
    required this.language,
    required this.description,
    required this.rules,
    this.ownerContact = '',
    this.showOwnerContact = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'currentLink': currentLink,
    'previousLink': previousLink,
    'imageUrl': imageUrl,
    'category': category,
    'subcategory': subcategory,
    'country': country,
    'state': state,
    'city': city,
    'language': language,
    'description': description,
    'rules': rules,
    'ownerContact': ownerContact,
    'showOwnerContact': showOwnerContact,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    String readString(String key, {String? fallback}) {
      final value = json[key];
      if (value is String) return value;
      if (fallback != null) return fallback;
      throw FormatException('Invalid or missing field: $key');
    }

    final rawDate = json['createdAt'];
    final createdAt = rawDate is String ? DateTime.tryParse(rawDate) : null;

    if (createdAt == null) {
      throw const FormatException('Invalid or missing createdAt');
    }

    final rawShowContact = json['showOwnerContact'];
    if (rawShowContact != null && rawShowContact is! bool) {
      throw const FormatException('Invalid showOwnerContact value');
    }

    return GroupModel(
      id: readString('id'),
      name: readString('name'),
      currentLink: readString('currentLink'),
      previousLink: readString('previousLink', fallback: ''),
      imageUrl: readString('imageUrl'),
      category: readString('category'),
      subcategory: readString('subcategory'),
      country: readString('country'),
      state: readString('state'),
      city: readString('city'),
      language: readString('language'),
      description: readString('description'),
      rules: readString('rules'),
      ownerContact: readString('ownerContact', fallback: ''),
      showOwnerContact: rawShowContact as bool? ?? false,
      createdAt: createdAt,
    );
  }
}
