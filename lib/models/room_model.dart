import 'package:equatable/equatable.dart';

class RoomModel extends Equatable {
  final String id;
  final String title;
  final String hostUid;
  final String hostName;
  final String hostAvatar;
  final int maxSeats; // 2, 4, 6
  final int likes;
  final String backgroundTheme; // e.g., 'nebula', 'ocean', 'sunset'
  final Map<String, dynamic> seats; // index -> uid
  final bool isEnded;
  final int createdAt;

  const RoomModel({
    required this.id,
    required this.title,
    required this.hostUid,
    required this.hostName,
    this.hostAvatar = '',
    this.maxSeats = 6,
    this.likes = 0,
    this.backgroundTheme = 'glass',
    this.seats = const {},
    this.isEnded = false,
    required this.createdAt,
  });

  factory RoomModel.fromJson(Map<dynamic, dynamic> json, String id) {
    return RoomModel(
      id: id,
      title: json['title'] as String? ?? 'Untitled Room',
      hostUid: json['hostUid'] as String? ?? '',
      hostName: json['hostName'] as String? ?? 'Admin',
      hostAvatar: json['hostAvatar'] as String? ?? '',
      maxSeats: json['maxSeats'] as int? ?? 6,
      likes: json['likes'] as int? ?? 0,
      backgroundTheme: json['backgroundTheme'] as String? ?? 'glass',
      seats: (json['seats'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {},
      isEnded: json['isEnded'] as bool? ?? false,
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'hostUid': hostUid,
      'hostName': hostName,
      'hostAvatar': hostAvatar,
      'maxSeats': maxSeats,
      'likes': likes,
      'backgroundTheme': backgroundTheme,
      'seats': seats,
      'isEnded': isEnded,
      'createdAt': createdAt,
    };
  }

  @override
  List<Object?> get props => [id, title, hostUid, likes, isEnded];
}
