/// 心情：1-5 分 + emoji + 可选短词。
/// score 用于统计页趋势曲线，emoji 用于 UI 展示，label 是用户自定义短词。
class Mood {
  /// 1..5：1 最差，5 最好。
  final int score;

  /// 单一 emoji 字符，如 😢 / 😔 / 😐 / 🙂 / 😊。
  final String emoji;

  /// 可选自定义短词（如"充实" / "焦虑"）。
  final String? label;

  const Mood({
    required this.score,
    required this.emoji,
    this.label,
  });

  /// 五档预设。供选择器用。
  static const List<Mood> presets = [
    Mood(score: 1, emoji: '😢'),
    Mood(score: 2, emoji: '😔'),
    Mood(score: 3, emoji: '😐'),
    Mood(score: 4, emoji: '🙂'),
    Mood(score: 5, emoji: '😊'),
  ];

  Mood copyWith({
    int? score,
    String? emoji,
    String? label,
    bool clearLabel = false,
  }) {
    return Mood(
      score: score ?? this.score,
      emoji: emoji ?? this.emoji,
      label: clearLabel ? null : (label ?? this.label),
    );
  }

  Map<String, dynamic> toMap() => {
        'score': score,
        'emoji': emoji,
        if (label != null) 'label': label,
      };

  factory Mood.fromMap(Map<String, dynamic> map) {
    final raw = map['score'];
    final s = raw is num ? raw.toInt().clamp(1, 5) : 3;
    return Mood(
      score: s,
      emoji: map['emoji'] as String? ?? '😐',
      label: map['label'] as String?,
    );
  }
}
