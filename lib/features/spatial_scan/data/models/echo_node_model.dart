import '../../domain/entities/echo_node.dart';

/// Wire-format representation of an [EchoNode]. Keeps (de)serialization
/// concerns out of the domain entity so a future REST/BLE payload shape can
/// change without touching business logic.
class EchoNodeModel extends EchoNode {
  const EchoNodeModel({
    required super.id,
    required super.label,
    required super.category,
    required super.angleRadians,
    required super.distance,
    required super.depth,
    required super.intensity,
    super.latitude,
    super.longitude,
    super.isLocked,
    super.lockedLabel,
    super.distanceMeters,
    super.audioFilePath,
  });

  factory EchoNodeModel.fromJson(Map<String, dynamic> json) {
    return EchoNodeModel(
      id: json['id'] as String,
      label: json['label'] as String,
      category: EchoCategory.values.byName(json['category'] as String),
      angleRadians: (json['angleRadians'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      depth: (json['depth'] as num).toDouble(),
      intensity: (json['intensity'] as num).toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isLocked: json['isLocked'] as bool? ?? false,
      lockedLabel: json['lockedLabel'] as String?,
      audioFilePath: json['audioFilePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'category': category.name,
        'angleRadians': angleRadians,
        'distance': distance,
        'depth': depth,
        'intensity': intensity,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'isLocked': isLocked,
        if (lockedLabel != null) 'lockedLabel': lockedLabel,
        if (audioFilePath != null) 'audioFilePath': audioFilePath,
      };
}
