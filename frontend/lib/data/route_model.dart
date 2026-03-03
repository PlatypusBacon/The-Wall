import 'dart:convert';
import 'dart:typed_data';
import 'climbing_models.dart';
import 'package:flutter/painting.dart';

class SavedRoute extends ClimbingRoute {
  final String? annotatedImagePath;

  SavedRoute({
    required super.id,
    required super.name,
    required super.imagePath,
    super.imageBytes,
    super.imageSize,
    required super.allHolds,
    required super.selectedHolds,
    required super.createdAt,
    super.difficulty,
    super.isSequenceClimb,
    this.annotatedImagePath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'difficulty': difficulty,
    'all_holds': jsonEncode(allHolds.map((h) => h.toMap()).toList()),
    'selected_holds': jsonEncode(selectedHolds.map((h) => h.toMap()).toList()),
    'image_path': imagePath,
    // Store bytes as base64 string so they survive the DB round-trip
    'image_bytes': imageBytes != null ? base64Encode(imageBytes!) : null,
    'annotated_image_path': annotatedImagePath,
    'created_at': createdAt.toIso8601String(),
    'image_width': imageSize?.width ?? 0,
    'image_height': imageSize?.height ?? 0,
    'is_sequence_climb': isSequenceClimb ? 1 : 0,
  };

  factory SavedRoute.fromMap(Map<String, dynamic> map) {
    // Decode base64 bytes if present
    Uint8List? imageBytes;
    final bytesStr = map['image_bytes'] as String?;
    if (bytesStr != null && bytesStr.isNotEmpty) {
      imageBytes = base64Decode(bytesStr);
    }

    return SavedRoute(
      id: map['id'],
      name: map['name'],
      difficulty: map['difficulty'],
      allHolds: (jsonDecode(map['all_holds'] as String? ?? '[]') as List)
          .map((h) => ClimbingHold.fromMap(h as Map<String, dynamic>))
          .toList(),
      selectedHolds: (jsonDecode(map['selected_holds']) as List)
          .map((h) => ClimbingHold.fromMap(h as Map<String, dynamic>))
          .toList(),
      imagePath: map['image_path'],
      imageBytes: imageBytes,
      annotatedImagePath: map['annotated_image_path'],
      createdAt: DateTime.parse(map['created_at']),
      imageSize: Size(
        (map['image_width'] as num).toDouble(),
        (map['image_height'] as num).toDouble(),
      ),
      isSequenceClimb: map['is_sequence_climb'] == 1,
    );
  }
}