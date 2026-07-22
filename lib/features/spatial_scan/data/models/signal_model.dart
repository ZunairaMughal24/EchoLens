import '../../domain/entities/signal.dart';

/// Wire-format representation of a [Signal] — kept separate from the domain
/// entity for the same reason as [EchoNodeModel]: (de)serialization is a
/// data-layer concern.
class SignalModel extends Signal {
  const SignalModel({
    required super.id,
    required super.label,
    required super.latitude,
    required super.longitude,
    required super.audioFilePath,
    required super.recordedAt,
  });

  factory SignalModel.fromJson(Map<String, dynamic> json) {
    return SignalModel(
      id: json['id'] as String,
      label: json['label'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      audioFilePath: json['audioFilePath'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'audioFilePath': audioFilePath,
        'recordedAt': recordedAt.toIso8601String(),
      };
}
