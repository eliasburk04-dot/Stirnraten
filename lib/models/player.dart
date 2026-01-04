import 'package:flutter/material.dart';

enum PlayerRole { normal, detective, accomplice }

/// Represents a player in the game
class Player {
  final String id;
  final String name;
  final bool isHost;
  final bool isLiar;
  final PlayerRole role;
  final String? answer;
  final String? votedFor; // Player ID they voted for
  final bool isConnected;
  final Color avatarColor;

  const Player({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isLiar = false,
    this.role = PlayerRole.normal,
    this.answer,
    this.votedFor,
    this.isConnected = true,
    this.avatarColor = Colors.blue,
  });

  /// Create a copy with updated fields
  Player copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? isLiar,
    PlayerRole? role,
    String? answer,
    String? votedFor,
    bool? isConnected,
    Color? avatarColor,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isLiar: isLiar ?? this.isLiar,
      role: role ?? this.role,
      answer: answer ?? this.answer,
      votedFor: votedFor ?? this.votedFor,
      isConnected: isConnected ?? this.isConnected,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  /// Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isHost': isHost,
      'isLiar': isLiar,
      'role': role.name,
      'answer': answer,
      'votedFor': votedFor,
      'isConnected': isConnected,
      'avatarColor': avatarColor.value,
    };
  }

  /// Create from Map (from Firebase)
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as String,
      name: map['name'] as String,
      isHost: map['isHost'] as bool? ?? false,
      isLiar: map['isLiar'] as bool? ?? false,
      role: PlayerRole.values.firstWhere((e) => e.name == (map['role'] as String? ?? 'normal'), orElse: () => PlayerRole.normal),
      answer: map['answer'] as String?,
      votedFor: map['votedFor'] as String?,
      isConnected: map['isConnected'] as bool? ?? true,
      avatarColor: Color(map['avatarColor'] as int? ?? Colors.blue.value),
    );
  }

  /// Get initials for avatar
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 
        ? name.substring(0, 2).toUpperCase() 
        : name.toUpperCase();
  }

  /// Check if player has submitted an answer
  bool get hasAnswered => answer != null && answer!.isNotEmpty;

  /// Check if player has voted
  bool get hasVoted => votedFor != null && votedFor!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Player(id: $id, name: $name, isHost: $isHost, isLiar: $isLiar)';
}

/// Predefined avatar colors
final List<Color> avatarColors = [
  const Color(0xFF6C63FF), // Purple
  const Color(0xFFFF6B6B), // Red
  const Color(0xFF4ECDC4), // Teal
  const Color(0xFFFFE66D), // Yellow
  const Color(0xFF95E1D3), // Mint
  const Color(0xFFF38181), // Coral
  const Color(0xFFAA96DA), // Lavender
  const Color(0xFF67C7EB), // Sky Blue
  const Color(0xFFFFB347), // Orange
  const Color(0xFF87CEAB), // Sage
];

/// Get a random avatar color
Color getRandomAvatarColor() {
  avatarColors.shuffle();
  return avatarColors.first;
}
