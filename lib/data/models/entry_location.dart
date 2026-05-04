/// 条目地理位置。
/// 移动端通常由 GPS + 反向地理编码自动填，桌面端通常用户手填 [placeName]，
/// 经纬度可空（手填情况下没必要打到坐标级别）。
class EntryLocation {
  final double? latitude;
  final double? longitude;
  final String? placeName;

  const EntryLocation({
    this.latitude,
    this.longitude,
    this.placeName,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasName => (placeName ?? '').trim().isNotEmpty;

  EntryLocation copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
    bool clearCoordinates = false,
    bool clearName = false,
  }) {
    return EntryLocation(
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      placeName: clearName ? null : (placeName ?? this.placeName),
    );
  }

  Map<String, dynamic> toMap() => {
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
        if (placeName != null) 'placeName': placeName,
      };

  factory EntryLocation.fromMap(Map<String, dynamic> map) {
    return EntryLocation(
      latitude: (map['lat'] as num?)?.toDouble(),
      longitude: (map['lng'] as num?)?.toDouble(),
      placeName: map['placeName'] as String?,
    );
  }
}
