import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String jobId;
  final String description;
  final double amount;
  final DateTime date;
  final String userId;
  final String? userName;
  final String? receiptUrl;

  Expense({
    required this.id,
    required this.jobId,
    required this.description,
    required this.amount,
    required this.date,
    required this.userId,
    this.userName,
    this.receiptUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'userId': userId,
      'userName': userName,
      'receiptUrl': receiptUrl,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      jobId: json['jobId'],
      description: json['description'],
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      userId: json['userId'],
      userName: json['userName'],
      receiptUrl: json['receiptUrl'],
    );
  }

  static Expense fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: data['id'] ?? doc.id,
      jobId: data['jobId'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      date:
          data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.parse(data['date']),
      userId: data['userId'] ?? '',
      userName: data['userName'],
      receiptUrl: data['receiptUrl'],
    );
  }

  Expense copyWith({
    String? id,
    String? jobId,
    String? description,
    double? amount,
    DateTime? date,
    String? userId,
    String? userName,
    String? receiptUrl,
  }) {
    return Expense(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }
}
