import 'package:equatable/equatable.dart';

/// Represents a Zuumeet user stored in Firebase Realtime Database.
class UserModel extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String gender;
  final List<String> interestedIn;
  final String country;
  final String countryCode;
  final bool isOnline;
  final bool isSearching;
  final int createdAt;
  final int lastActive;
  final List<String> blockedUsers;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.gender = '',
    this.interestedIn = const [],
    this.country = '',
    this.countryCode = '',
    this.isOnline = false,
    this.isSearching = false,
    required this.createdAt,
    required this.lastActive,
    this.blockedUsers = const [],
  });

  factory UserModel.fromJson(Map<dynamic, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      gender: json['gender'] as String? ?? '',
      interestedIn: (json['interestedIn'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      country: json['country'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      isOnline: json['isOnline'] as bool? ?? false,
      isSearching: json['isSearching'] as bool? ?? false,
      createdAt: json['createdAt'] as int? ?? 0,
      lastActive: json['lastActive'] as int? ?? 0,
      blockedUsers: (json['blockedUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'gender': gender,
      'interestedIn': interestedIn,
      'country': country,
      'countryCode': countryCode,
      'isOnline': isOnline,
      'isSearching': isSearching,
      'createdAt': createdAt,
      'lastActive': lastActive,
      'blockedUsers': blockedUsers,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? gender,
    List<String>? interestedIn,
    String? country,
    String? countryCode,
    bool? isOnline,
    bool? isSearching,
    int? lastActive,
    List<String>? blockedUsers,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      isOnline: isOnline ?? this.isOnline,
      isSearching: isSearching ?? this.isSearching,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }

  /// Converts a country code to a flag emoji.
  String get flagEmoji {
    if (countryCode.isEmpty || countryCode.length != 2) return '🌍';
    final code = countryCode.toUpperCase();
    return String.fromCharCodes([
      code.codeUnitAt(0) + 0x1F1A5,
      code.codeUnitAt(1) + 0x1F1A5,
    ]);
  }

  /// Returns initials for avatar placeholder.
  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  List<Object?> get props => [uid, name, email, gender, country];
}
