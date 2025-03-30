import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String>? pendingRequests;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.pendingRequests,
    this.createdAt,
    this.updatedAt,
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
      'pendingRequests': pendingRequests,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
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
      pendingRequests:
          json['pendingRequests'] != null
              ? List<String>.from(json['pendingRequests'])
              : null,
      createdAt:
          json['createdAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
              : null,
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
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
    List<String>? pendingRequests,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      pendingRequests: pendingRequests ?? this.pendingRequests,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Job fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Job',
      color: Color(data['color'] ?? 0xFF2196F3),
      description: data['description'],
      isShared: data['isShared'] ?? false,
      isPublic: data['isPublic'] ?? true,
      connectionCode: data['connectionCode'],
      creatorId: data['creatorId'],
      connectedUsers:
          data['connectedUsers'] != null
              ? List<String>.from(data['connectedUsers'])
              : null,
      pendingRequests:
          data['pendingRequests'] != null
              ? List<String>.from(data['pendingRequests'])
              : null,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Job && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
