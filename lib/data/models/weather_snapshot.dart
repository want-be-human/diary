enum WeatherCondition { sunny, cloudy, rainy, snowy, fog, windy, unknown }

extension WeatherConditionX on WeatherCondition {
  String get wireValue => name;

  String get displayLabel {
    switch (this) {
      case WeatherCondition.sunny:
        return '晴';
      case WeatherCondition.cloudy:
        return '多云';
      case WeatherCondition.rainy:
        return '雨';
      case WeatherCondition.snowy:
        return '雪';
      case WeatherCondition.fog:
        return '雾';
      case WeatherCondition.windy:
        return '风';
      case WeatherCondition.unknown:
        return '未知';
    }
  }

  /// Material Icons 名（UI 渲染时按这个找图标）。
  String get iconKey {
    switch (this) {
      case WeatherCondition.sunny:
        return 'wb_sunny_outlined';
      case WeatherCondition.cloudy:
        return 'cloud_outlined';
      case WeatherCondition.rainy:
        return 'water_drop_outlined';
      case WeatherCondition.snowy:
        return 'ac_unit';
      case WeatherCondition.fog:
        return 'foggy';
      case WeatherCondition.windy:
        return 'air';
      case WeatherCondition.unknown:
        return 'help_outline';
    }
  }

  static WeatherCondition fromWire(String? raw) {
    for (final c in WeatherCondition.values) {
      if (c.name == raw) return c;
    }
    return WeatherCondition.unknown;
  }
}

/// 创建日记时刻的天气快照。
/// 数据源：Open-Meteo HTTP API（无 key）。`weather_code` 数值映射到 [WeatherCondition]。
class WeatherSnapshot {
  final WeatherCondition condition;
  final double tempCelsius;
  final String? cityName;

  const WeatherSnapshot({
    required this.condition,
    required this.tempCelsius,
    this.cityName,
  });

  WeatherSnapshot copyWith({
    WeatherCondition? condition,
    double? tempCelsius,
    String? cityName,
    bool clearCityName = false,
  }) {
    return WeatherSnapshot(
      condition: condition ?? this.condition,
      tempCelsius: tempCelsius ?? this.tempCelsius,
      cityName: clearCityName ? null : (cityName ?? this.cityName),
    );
  }

  Map<String, dynamic> toMap() => {
        'condition': condition.wireValue,
        'tempCelsius': tempCelsius,
        if (cityName != null) 'cityName': cityName,
      };

  factory WeatherSnapshot.fromMap(Map<String, dynamic> map) {
    return WeatherSnapshot(
      condition: WeatherConditionX.fromWire(map['condition'] as String?),
      tempCelsius: (map['tempCelsius'] as num?)?.toDouble() ?? 0.0,
      cityName: map['cityName'] as String?,
    );
  }
}
