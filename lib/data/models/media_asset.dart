/// 媒体类型。
enum MediaType { image, video }

extension MediaTypeX on MediaType {
  String get wireValue => name;

  static MediaType fromWire(String? raw) {
    switch (raw) {
      case 'video':
        return MediaType.video;
      case 'image':
      default:
        return MediaType.image;
    }
  }
}

/// 媒体来源。
enum MediaSource { firebaseStorage, googleDrive, youtube }

extension MediaSourceX on MediaSource {
  String get wireValue {
    switch (this) {
      case MediaSource.firebaseStorage:
        return 'firebase_storage';
      case MediaSource.googleDrive:
        return 'google_drive';
      case MediaSource.youtube:
        return 'youtube';
    }
  }

  static MediaSource fromWire(String? raw) {
    switch (raw) {
      case 'google_drive':
        return MediaSource.googleDrive;
      case 'youtube':
        return MediaSource.youtube;
      case 'firebase_storage':
      default:
        return MediaSource.firebaseStorage;
    }
  }
}

/// 内嵌于日记的媒体资产。
/// 图片走 Firebase Storage；视频走 Drive（用户已有 2TB）或 YouTube 链接。
class MediaAsset {
  final String id;
  final MediaType type;
  final String url;          // CDN 地址 / Drive 文件 ID / YouTube URL
  final MediaSource source;
  final String? localPath;   // 本地缓存路径（可空）
  final int sizeBytes;

  const MediaAsset({
    required this.id,
    required this.type,
    required this.url,
    required this.source,
    required this.sizeBytes,
    this.localPath,
  });

  MediaAsset copyWith({
    String? id,
    MediaType? type,
    String? url,
    MediaSource? source,
    String? localPath,
    int? sizeBytes,
    bool clearLocalPath = false,
  }) {
    return MediaAsset(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
      source: source ?? this.source,
      localPath: clearLocalPath ? null : (localPath ?? this.localPath),
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.wireValue,
        'url': url,
        'source': source.wireValue,
        'localPath': localPath,
        'sizeBytes': sizeBytes,
      };

  factory MediaAsset.fromMap(Map<String, dynamic> map) {
    return MediaAsset(
      id: map['id'] as String? ?? '',
      type: MediaTypeX.fromWire(map['type'] as String?),
      url: map['url'] as String? ?? '',
      source: MediaSourceX.fromWire(map['source'] as String?),
      localPath: map['localPath'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}
