import 'package:flutter/material.dart';

class Job {
  final String id;
  final String name;
  final String? description;
  final Color color;
  final String? creatorId;
  final String? connectionCode;
  final bool isShared;
  final List<String>? connectedUsers;
  final bool isPublic;

  Job({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.creatorId,
    this.connectionCode,
    this.isShared = false,
    this.connectedUsers,
    this.isPublic = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color.value,
      'creatorId': creatorId,
      'connectionCode': connectionCode,
      'isShared': isShared,
      'connectedUsers': connectedUsers,
      'isPublic': isPublic,
    };
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      color: Color(json['color']),
      creatorId: json['creatorId'],
      connectionCode: json['connectionCode'],
      isShared: json['isShared'] ?? false,
      connectedUsers:
          json['connectedUsers'] != null
              ? List<String>.from(json['connectedUsers'])
              : null,
      isPublic: json['isPublic'] ?? true,
    );
  }

  Job copyWith({
    String? id,
    String? name,
    String? description,
    Color? color,
    String? creatorId,
    String? connectionCode,
    bool? isShared,
    List<String>? connectedUsers,
    bool? isPublic,
  }) {
    return Job(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      creatorId: creatorId ?? this.creatorId,
      connectionCode: connectionCode ?? this.connectionCode,
      isShared: isShared ?? this.isShared,
      connectedUsers: connectedUsers ?? this.connectedUsers,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}
