import 'package:flutter/material.dart';
import 'dart:typed_data';

enum HoldRole { start, middle, hand, foot, finish }

class ClimbingHold {
  final String id;
  Offset position;
  final double confidence;
  double width;
  double height;
  bool isSelected;
  HoldRole role;
  int? selectionOrder; // null if not part of the sequence
  ClimbingHold copy() {
    return ClimbingHold(
      id: id,
      position: Offset(position.dx, position.dy), // ensure new instance
      confidence: confidence,
      width: width,
      height: height,
      isSelected: isSelected,
      role: role,
      selectionOrder: selectionOrder,
    );
  }
  ClimbingHold({
    required this.id,
    required this.position,
    required this.confidence,
    this.width = 40.0,
    this.height = 40.0,
    this.isSelected = false,
    this.role = HoldRole.middle,
    this.selectionOrder
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'position_dx': position.dx,
    'position_dy': position.dy,
    'confidence': confidence,
    'width': width,
    'height': height,
    'is_selected': isSelected ? 1 : 0,
    'role': role.name,
    'selectionOrder': selectionOrder,
  };


  factory ClimbingHold.fromMap(Map<String, dynamic> map) => ClimbingHold(
    id: map['id'],
    position: Offset(map['position_dx'], map['position_dy']),
    confidence: map['confidence'],
    width: map['width'],
    height: map['height'],
    isSelected: map['is_selected'] == 1,
    role: HoldRole.values.byName(map['role']),
    selectionOrder: map['selectionOrder'] as int?,
  );
}

class ClimbingRoute {
  final String id;
  final String name;
  final String imagePath;
  final Uint8List? imageBytes;
  final Size? imageSize;  // fixed: belongs here, not super
  final List<ClimbingHold> allHolds;
  final List<ClimbingHold> selectedHolds;
  final DateTime createdAt;
  final String difficulty;
  final bool isSequenceClimb;

  ClimbingRoute({
    required this.id,
    required this.name,
    required this.imagePath,
    this.imageBytes,
    this.imageSize,
    required this.allHolds,
    required this.selectedHolds,
    required this.createdAt,
    this.difficulty = 'V0',
    this.isSequenceClimb = false,
  });
}