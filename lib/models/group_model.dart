class GroupModel {
  final String id;
  final String name;
  final String currentLink;
  final String previousLink;
  final String imageUrl;
  final String category;

  // Retained only for compatibility with older local data.
  final String subcategory;

  final String country;
  final String state;
  final String city;
  final String language;
  final String description;
  final String rules;
  final String ownerContact;
  final bool showOwnerContact;

  final String ownerUid;
  final String approvalStatus;
  final String verificationStatus;
  final int viewCount;
  final int joinClickCount;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.currentLink,
    this.previousLink = '',
    required this.imageUrl,
    required this.category,
    this.subcategory = '',
    required this.country,
    required this.state,
    required this.city,
    required this.language,
    required this.description,
    required this.rules,
    this.ownerContact = '',
    this.showOwnerContact = false,
    this.ownerUid = '',
    this.approvalStatus = 'pending',
    this.verificationStatus = 'pending',
    this.viewCount = 0,
    this.joinClickCount = 0,
    required this.createdAt,
    this.updatedAt,
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
    'ownerUid': ownerUid,
    'approvalStatus': approvalStatus,
    'verificationStatus': verificationStatus,
    'viewCount': viewCount,
    'joinClickCount': joinClickCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    String readString(String key, {String fallback = ''}) {
      final value = json[key];
      return value is String ? value : fallback;
    }

    int readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    DateTime? readDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);

      // Supports Firestore Timestamp without coupling this model to Firestore.
      if (value != null && value.runtimeType.toString() == 'Timestamp') {
        try {
          return (value as dynamic).toDate() as DateTime;
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final createdAt = readDate(json['createdAt']);
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
      previousLink: readString('previousLink'),
      imageUrl: readString('imageUrl'),
      category: readString('category'),
      subcategory: readString('subcategory'),
      country: readString('country'),
      state: readString('state'),
      city: readString('city'),
      language: readString('language'),
      description: readString('description'),
      rules: readString('rules'),
      ownerContact: readString('ownerContact'),
      showOwnerContact: rawShowContact as bool? ?? false,
      ownerUid: readString('ownerUid'),
      approvalStatus: readString('approvalStatus', fallback: 'pending'),
      verificationStatus: readString('verificationStatus', fallback: 'pending'),
      viewCount: readInt('viewCount'),
      joinClickCount: readInt('joinClickCount'),
      createdAt: createdAt,
      updatedAt: readDate(json['updatedAt']),
    );
  }
}
