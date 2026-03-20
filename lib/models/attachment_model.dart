import '../core/app_constants.dart';

enum AttachmentType { image, video, raw, document, audio, unknown }

AttachmentType parseAttachmentType(dynamic raw) {
  if (raw is int) {
    switch (raw) {
      case 0:
        return AttachmentType.image;
      case 1:
        return AttachmentType.video;
      case 2:
        return AttachmentType.raw;
      case 3:
        return AttachmentType.document;
      case 4:
        return AttachmentType.audio;
      default:
        return AttachmentType.unknown;
    }
  }

  final normalized = raw?.toString().trim().toUpperCase();
  switch (raw) {
    case 'IMAGE':
      return AttachmentType.image;
    case 'VIDEO':
      return AttachmentType.video;
    case 'RAW':
      return AttachmentType.raw;
    case 'DOCUMENT':
      return AttachmentType.document;
    case 'AUDIO':
      return AttachmentType.audio;
    default:
      switch (normalized) {
        case 'IMAGE':
          return AttachmentType.image;
        case 'VIDEO':
          return AttachmentType.video;
        case 'RAW':
          return AttachmentType.raw;
        case 'DOCUMENT':
          return AttachmentType.document;
        case 'AUDIO':
          return AttachmentType.audio;
        default:
          return AttachmentType.unknown;
      }
  }
}

String? _resolveAttachmentSource(String? source) {
  final value = source?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return value;
  }

  final base = Uri.tryParse(AppConstants.baseUrl);
  if (base == null || !base.hasScheme || base.host.isEmpty) {
    return value;
  }

  return base.resolve(value).toString();
}

class AttachmentModel {
  const AttachmentModel({
    required this.source,
    required this.type,
  });

  final String? source;
  final AttachmentType type;

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      source: _resolveAttachmentSource(json['source'] as String?),
      type: parseAttachmentType(json['type']),
    );
  }
}
