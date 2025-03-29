import 'package:flutter/material.dart';

class Job {
  final String id;
  final String name;
  final Color color;
  final String? description;
  final bool isShared;
  final bool isPublic;
  final String? connectionCode;
  final String? creatorId;
  final List<String>? connectedUsers;

  Job({
    required this.id,
    required this.name,
    required this.color,
    this.description,
    this.isShared = false,
    this.isPublic = true,
    this.connectionCode,
    this.creatorId,
    this.connectedUsers,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'description': description,
      'isShared': isShared,
      'isPublic': isPublic,
      'connectionCode': connectionCode,
      'creatorId': creatorId,
      'connectedUsers': connectedUsers,
    };
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      name: json['name'],
      color: Color(json['color']),
      description: json['description'],
      isShared: json['isShared'] ?? false,
      isPublic: json['isPublic'] ?? true,
      connectionCode: json['connectionCode'],
      creatorId: json['creatorId'],
      connectedUsers:
          json['connectedUsers'] != null
              ? List<String>.from(json['connectedUsers'])
              : null,
    );
  }

  Job copyWith({
    String? id,
    String? name,
    Color? color,
    String? description,
    bool? isShared,
    bool? isPublic,
    String? connectionCode,
    String? creatorId,
    List<String>? connectedUsers,
  }) {
    return Job(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      description: description ?? this.description,
      isShared: isShared ?? this.isShared,
      isPublic: isPublic ?? this.isPublic,
      connectionCode: connectionCode ?? this.connectionCode,
      creatorId: creatorId ?? this.creatorId,
      connectedUsers: connectedUsers ?? this.connectedUsers,
    );
  }
}
