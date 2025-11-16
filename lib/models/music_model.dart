import 'package:flutter/material.dart';
class MusicCategory {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Color color;
  final List<MusicTrack> tracks;

  MusicCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.tracks = const [],
  });
}

class MusicTrack {
  final String id;
  final String title;
  final String? artist;
  final String filePath;
  final Duration duration;
  final String category;
  final DateTime dateAdded;

  MusicTrack({
    required this.id,
    required this.title,
    required this.filePath,
    required this.duration,
    required this.category,
    this.artist,
    required this.dateAdded,
  });

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'filePath': filePath,
      'duration': duration.inSeconds,
      'category': category,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  // Create from map
  factory MusicTrack.fromMap(Map<String, dynamic> map) {
    return MusicTrack(
      id: map['id'],
      title: map['title'],
      artist: map['artist'],
      filePath: map['filePath'],
      duration: Duration(seconds: map['duration']),
      category: map['category'],
      dateAdded: DateTime.parse(map['dateAdded']),
    );
  }
}