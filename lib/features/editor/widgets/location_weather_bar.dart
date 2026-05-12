import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/entry_location.dart';
import '../../../data/models/weather_snapshot.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/services/weather_service.dart';

/// 编辑器底部第二行元数据条：位置 chip + 天气 chip。
///
/// - 点击位置 chip → 底部 sheet：一键定位 / 手填地点。
/// - 点击天气 chip → 底部 sheet：手填条件 + 温度，或"按当前位置刷新"。
/// - 长按任一 chip 清空对应字段。
///
/// 自动抓取由父 widget 在新建模式下负责（[autoFetchOnce]）；本组件只负责呈现 + 编辑。
class LocationWeatherBar extends ConsumerWidget {
  const LocationWeatherBar({
    super.key,
    required this.location,
    required this.weather,
    required this.onLocationChanged,
    required this.onWeatherChanged,
    this.busy = false,
  });

  final EntryLocation? location;
  final WeatherSnapshot? weather;
  final void Function(EntryLocation?) onLocationChanged;
  final void Function(WeatherSnapshot?) onWeatherChanged;

  /// 是否正在自动抓取（父 widget 控制）。busy 时 chip 显示一个小转圈。
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final locText = location?.placeName?.trim().isNotEmpty == true
        ? location!.placeName!.trim()
        : '加位置';
    final hasLoc = location?.placeName?.trim().isNotEmpty == true;

    final hasWx = weather != null;
    final wxText = hasWx
        ? '${weather!.condition.displayLabel} '
            '${weather!.tempCelsius.toStringAsFixed(0)}°'
        : '加天气';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Chip(
            icon: busy
                ? const _Spinner()
                : const Icon(Icons.place_outlined, size: 14),
            label: locText,
            active: hasLoc,
            color: scheme.primary,
            onTap: () => _openLocationSheet(context, ref),
            onLongPress: hasLoc ? () => onLocationChanged(null) : null,
          ),
          _Chip(
            icon: busy
                ? const _Spinner()
                : Icon(_iconForCondition(weather?.condition), size: 14),
            label: wxText,
            active: hasWx,
            color: scheme.primary,
            onTap: () => _openWeatherSheet(context, ref),
            onLongPress: hasWx ? () => onWeatherChanged(null) : null,
          ),
        ],
      ),
    );
  }

  IconData _iconForCondition(WeatherCondition? c) {
    switch (c) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny_outlined;
      case WeatherCondition.cloudy:
        return Icons.cloud_outlined;
      case WeatherCondition.rainy:
        return Icons.water_drop_outlined;
      case WeatherCondition.snowy:
        return Icons.ac_unit;
      case WeatherCondition.fog:
        return Icons.foggy;
      case WeatherCondition.windy:
        return Icons.air;
      case WeatherCondition.unknown:
      case null:
        return Icons.cloud_outlined;
    }
  }

  Future<void> _openLocationSheet(
      BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<EntryLocation?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LocationSheet(initial: location),
    );
    // sheet 用 Navigator.pop(null) 表示"清空"——但这跟"用户没做选择"
    // 撞了。所以 sheet 用一个 sentinel：见 _LocationSheet 实现里的语义。
    if (result == null) return; // 用户取消
    if (result.placeName == null && !result.hasCoordinates) {
      onLocationChanged(null); // 清空
    } else {
      onLocationChanged(result);
    }
  }

  Future<void> _openWeatherSheet(
      BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_WeatherSheetResult?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WeatherSheet(
        initial: weather,
        location: location,
      ),
    );
    if (result == null) return;
    if (result.cleared) {
      onWeatherChanged(null);
      return;
    }
    if (result.snapshot != null) {
      onWeatherChanged(result.snapshot);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  final Widget icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = active ? color : theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final bg = active
        ? color.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: fg),
              child: icon,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 12,
      height: 12,
      child: CircularProgressIndicator(strokeWidth: 1.5),
    );
  }
}

// =================== 位置 sheet ===================

class _LocationSheet extends ConsumerStatefulWidget {
  const _LocationSheet({required this.initial});
  final EntryLocation? initial;

  @override
  ConsumerState<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<_LocationSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial?.placeName ?? '');
  bool _detecting = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    setState(() {
      _detecting = true;
      _error = null;
    });
    try {
      final loc =
          await ref.read(locationServiceProvider).fetchCurrent();
      if (!mounted) return;
      if (loc.placeName?.isNotEmpty == true) _ctrl.text = loc.placeName!;
      Navigator.of(context).pop(loc);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _error = '定位失败：$e';
      });
    }
  }

  void _saveManual() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      // 空字符串 = 清空。用 placeName == null && !hasCoordinates 标识。
      Navigator.of(context).pop(const EntryLocation());
      return;
    }
    // 手填只保留地点名，丢弃旧坐标——避免坐标和地点名不匹配。
    Navigator.of(context).pop(EntryLocation(placeName: text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined),
              const SizedBox(width: 8),
              Text('设置位置', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (widget.initial?.placeName?.isNotEmpty == true)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const EntryLocation()),
                  child: const Text('清空'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: _detecting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, size: 18),
            label: Text(_detecting ? '定位中…' : '一键定位'),
            onPressed: _detecting ? null : _detect,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: '手填地点',
              hintText: '如：杭州市西湖区',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveManual(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                // pop 不带值 = 用户取消。
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _detecting ? null : _saveManual,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =================== 天气 sheet ===================

class _WeatherSheetResult {
  _WeatherSheetResult._({this.snapshot, this.cleared = false});
  factory _WeatherSheetResult.set(WeatherSnapshot s) =>
      _WeatherSheetResult._(snapshot: s);
  factory _WeatherSheetResult.clear() => _WeatherSheetResult._(cleared: true);

  final WeatherSnapshot? snapshot;
  final bool cleared;
}

class _WeatherSheet extends ConsumerStatefulWidget {
  const _WeatherSheet({required this.initial, required this.location});

  final WeatherSnapshot? initial;
  final EntryLocation? location;

  @override
  ConsumerState<_WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends ConsumerState<_WeatherSheet> {
  late WeatherCondition _condition =
      widget.initial?.condition ?? WeatherCondition.sunny;
  late final _tempCtrl = TextEditingController(
    text: widget.initial?.tempCelsius.toStringAsFixed(0) ?? '',
  );
  bool _refreshing = false;
  String? _error;

  @override
  void dispose() {
    _tempCtrl.dispose();
    super.dispose();
  }

  /// 按当前 location 重抓一次。uapis.cn 不收坐标，所以优先用 placeName 查；
  /// placeName 也没有时用默认城市；最后兜底让 uapis 服务端按 IP 自动定位。
  Future<void> _refreshFromNetwork() async {
    final loc = widget.location;
    final defaultCity = ref.read(defaultCityProvider).asData?.value ?? '';

    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      WeatherSnapshot? snap;
      final wx = ref.read(weatherServiceProvider);
      if (loc?.hasName == true) {
        snap = await wx.fetchByCityName(loc!.placeName!);
      } else if (defaultCity.isNotEmpty) {
        snap = await wx.fetchByCityName(defaultCity);
      } else {
        // uapis 服务端按客户端 IP 反查城市并返回天气。
        snap = await wx.fetchByIp();
      }

      if (snap == null) {
        if (!mounted) return;
        setState(() {
          _refreshing = false;
          _error = '抓取失败，可手填温度和天气';
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(_WeatherSheetResult.set(snap));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = '抓取失败：$e';
      });
    }
  }

  void _saveManual() {
    final t = double.tryParse(_tempCtrl.text.trim());
    if (t == null) {
      setState(() => _error = '温度需要是数字');
      return;
    }
    Navigator.of(context).pop(
      _WeatherSheetResult.set(WeatherSnapshot(
        condition: _condition,
        tempCelsius: t,
        cityName: widget.location?.placeName,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined),
              const SizedBox(width: 8),
              Text('设置天气', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (widget.initial != null)
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pop(_WeatherSheetResult.clear()),
                  child: const Text('清空'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: _refreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_refreshing ? '抓取中…' : '按当前位置刷新'),
            onPressed: _refreshing ? null : _refreshFromNetwork,
          ),
          const SizedBox(height: 16),
          Text('或手填', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in WeatherCondition.values)
                if (c != WeatherCondition.unknown)
                  ChoiceChip(
                    label: Text(c.displayLabel),
                    selected: _condition == c,
                    onSelected: (_) => setState(() => _condition = c),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tempCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                signed: true, decimal: true),
            decoration: const InputDecoration(
              labelText: '温度（°C）',
              border: OutlineInputBorder(),
              suffixText: '°C',
            ),
            onSubmitted: (_) => _saveManual(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _refreshing ? null : _saveManual,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
