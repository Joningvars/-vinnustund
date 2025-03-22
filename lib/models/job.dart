import 'package:flutter/material.dart';
import 'dart:convert';

class Job {
  final String id;
  final String name;
  final String? description;
  final Color color;

  Job({String? id, required this.name, this.description, required this.color})
    : id = id ?? UniqueKey().toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color.value,
    };
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      color: Color(json['color']),
    );
  }
}
