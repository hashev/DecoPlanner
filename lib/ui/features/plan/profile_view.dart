import '../../core/planner_dialog.dart';
import 'dart:math' as math;
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../../../data/models/planner_document.dart';
import '../../../domain/profile_data.dart';
import '../documents/catalog_view.dart';
import '../documents/document_session.dart';
import 'gas_usage_view.dart';
import 'level_editor.dart';
import 'planner_view_model.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.data,
    required this.model,
    this.documents,
    this.isCurrent,
  }) : assert(isCurrent == null || documents == null);
  final ProfileData data;
  final PlannerViewModel model;
  final DocumentSession? documents;
  final bool Function()? isCurrent;
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  int selected = 0;
  String? comparison;
  int? tissue;
  bool get ascentOnly => widget.model.toolDraft['profile:ascentOnly'] == 'true';
  bool get current {
    if (widget.isCurrent != null) return widget.isCurrent!();
    final snapshot = widget.model.snapshotFor(widget.data.result.diveId);
    return snapshot.status == PlanStatus.ready &&
        identical(snapshot.result, widget.data.result);
  }

  Future<void> save() async {
    if (!current || widget.documents == null) return;
    final name = await editCatalogName(
      context,
      initial: 'Профиль',
      title: 'Назвать снимок',
      action: 'Сохранить снимок',
    );
    if (name == null || !mounted || !current) return;
    final result = widget.data.result;
    final stored = widget.model.storedResults[result.diveId]!;
    widget.documents!.saveComparison(
      ComparisonSnapshot(
        id: catalogId(),
        name: name,
        capturedAt: DateTime.now().toUtc(),
        plan: widget.model.planRequest,
        results: {result.diveId: stored},
      ),
    );
  }

  Future<void> clear() async {
    final accepted = await showPlannerDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить все снимки сравнения?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отменить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить снимки'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      widget.documents!.clearComparisons();
      setState(() => comparison = null);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.model, widget.documents]),
    builder: (context, _) {
      final data = widget.data, units = widget.model.units;
      final points = data.visiblePoints(ascentOnly: ascentOnly);
      selected = points.isEmpty ? 0 : selected.clamp(0, points.length - 1);
      final point = points.isEmpty ? null : points[selected];
      final options =
          <String, ({ComparisonSnapshot snapshot, CalculationResult result})>{};
      for (final snapshot
          in widget.documents?.document.comparisons ?? <ComparisonSnapshot>[]) {
        for (final entry in snapshot.results.entries) {
          options['${snapshot.id}/${entry.key}'] = (
            snapshot: snapshot,
            result: entry.value.result,
          );
        }
      }
      final compared = options[comparison];
      final comparisonPoints = compared == null
          ? <ProfilePoint>[]
          : ProfileData(
              result: compared.result,
              settings: data.settings,
            ).visiblePoints(ascentOnly: ascentOnly);
      final usage = calculateGasUsage(
        data.result,
        data.settings,
        stopsPerGroup: widget.model.ratioStops,
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Профиль и ткани')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      current
                          ? 'Актуальный снимок'
                          : 'Снимок предыдущего результата · входы изменены',
                    ),
                  ),
                  Text(
                    'Модель ${data.settings.model.name} · ${data.result.modelVersion}',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Только подъём и остановки'),
                    value: ascentOnly,
                    onChanged: (value) {
                      selected = 0;
                      widget.model.setToolDraft(
                        'profile:ascentOnly',
                        value.toString(),
                      );
                    },
                  ),
                  Text(
                    'Сплошная линия — текущий снимок. Глубина растёт вниз, время — вправо. ${depthUnit(units)}, мин.',
                  ),
                  if (compared != null)
                    Text(
                      'Штриховая линия — ${compared.snapshot.name} · ${compared.snapshot.capturedAt.toLocal().toIso8601String()} · ${compared.snapshot.modelVersion}',
                    ),
                  if (points.isEmpty)
                    const Text('Сегментов подъёма нет')
                  else
                    _DepthChart(
                      data: data,
                      points: points,
                      comparison: comparisonPoints,
                      ascentOnly: ascentOnly,
                      units: units,
                      selected: selected,
                      onSelect: (value) => setState(() => selected = value),
                    ),
                  if (options.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey(comparison),
                      initialValue: options.containsKey(comparison)
                          ? comparison
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Сравнить со снимком',
                      ),
                      items: [
                        for (final entry in options.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                              '${entry.value.snapshot.name} · ${entry.value.result.diveId}',
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => comparison = value),
                    ),
                  if (comparison != null)
                    TextButton(
                      onPressed: () => setState(() => comparison = null),
                      child: const Text('Скрыть сравнение'),
                    ),
                  if (widget.documents != null)
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: current ? save : null,
                          child: const Text('Сохранить сравнение'),
                        ),
                        TextButton(
                          onPressed: options.isEmpty ? null : clear,
                          child: const Text('Очистить сравнения'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (point != null) ...[
                    Text(
                      'Точка ${selected + 1} из ${points.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (points.length > 1)
                      Slider(
                        value: selected.toDouble(),
                        max: (points.length - 1).toDouble(),
                        divisions: points.length - 1,
                        label: '${point.runtimeMin.toStringAsFixed(2)} мин',
                        semanticFormatterCallback: (value) =>
                            'Точка ${value.round() + 1} из ${points.length}',
                        onChanged: (value) =>
                            setState(() => selected = value.round()),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: selected == 0
                              ? null
                              : () => setState(() => selected--),
                          child: const Text('Предыдущая точка'),
                        ),
                        TextButton(
                          onPressed: selected >= points.length - 1
                              ? null
                              : () => setState(() => selected++),
                          child: const Text('Следующая точка'),
                        ),
                      ],
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Время ${point.runtimeMin.toStringAsFixed(3)} мин · глубина ${depthText(point.depthMetres, units)} ${depthUnit(units)}',
                      ),
                    ),
                    Text(
                      'CNS ${point.state.oxygen.cnsFraction == null ? 'недоступен: превышена область 1,6 ATA' : '${(point.state.oxygen.cnsFraction! * 100).toStringAsFixed(2)} %'} · OTU ${point.state.oxygen.otu.toStringAsFixed(3)}',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ткани в выбранной точке',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    DropdownButtonFormField<int>(
                      key: ValueKey(tissue ?? 0),
                      initialValue: tissue ?? 0,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Компартменты',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('Все 16 тканей'),
                        ),
                        for (var i = 1; i <= 16; i++)
                          DropdownMenuItem(value: i, child: Text('Ткань $i')),
                      ],
                      onChanged: (value) =>
                          setState(() => tissue = value == 0 ? null : value),
                    ),
                    const Text(
                      'N₂ и He — парциальные давления тканей. M-value — предел Bühlmann при GF100%. Фактический GF может быть отрицательным; это численная характеристика, не настройка GF.',
                    ),
                    if (data.settings.model == DecompressionModel.vpmB)
                      const Text(
                        'M-values и GF неприменимы к VPM-B. Показаны реальные давления тканей.',
                      ),
                    _TissueChart(
                      values: data.tissues(point),
                      units: units,
                      onSelect: (index) => setState(() => tissue = index),
                    ),
                    for (final value
                        in data
                            .tissues(point)
                            .where((v) => tissue == null || tissue == v.index))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ткань ${value.index}'),
                              Text(
                                'N₂ ${usagePressure(value.nitrogenBar, units)} · He ${usagePressure(value.heliumBar, units)}',
                              ),
                              if (value.mValueBar != null)
                                Text(
                                  'M-value ${usagePressure(value.mValueBar!, units)} · GF ${value.gradientFraction == null ? 'недоступен: нулевой диапазон' : '${(value.gradientFraction! * 100).toStringAsFixed(2)} %'}',
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text('Ratios', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    'Остановки / уровни: ${ratioText(usage.decompressionRatio)}',
                  ),
                  for (final group in usage.stopGroups)
                    Text(
                      '${depthText(group.deepestMetres, units)}–${depthText(group.shallowestMetres, units)} ${depthUnit(units)}: ${group.durationMin.toStringAsFixed(2)} мин · ${ratioText(group.ratio)}',
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: points.isEmpty
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(
                                  title: const Text(
                                    'Численная таблица профиля',
                                  ),
                                ),
                                body: SafeArea(
                                  child: ListView.builder(
                                    itemCount: points.length,
                                    itemBuilder: (context, index) {
                                      final value = points[index];
                                      return ListTile(
                                        title: Text(
                                          '${value.runtimeMin.toStringAsFixed(3)} мин · ${depthText(value.depthMetres, units)} ${depthUnit(units)}',
                                        ),
                                        subtitle: Text(
                                          'CNS ${value.state.oxygen.cnsFraction == null ? 'недоступен' : '${(value.state.oxygen.cnsFraction! * 100).toStringAsFixed(2)} %'} · OTU ${value.state.oxygen.otu.toStringAsFixed(3)}',
                                        ),
                                        onTap: () {
                                          setState(() => selected = index);
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                    child: const Text('Численная таблица профиля'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DepthChart extends StatefulWidget {
  const _DepthChart({
    required this.data,
    required this.points,
    required this.comparison,
    required this.ascentOnly,
    required this.units,
    required this.selected,
    required this.onSelect,
  });
  final ProfileData data;
  final List<ProfilePoint> points, comparison;
  final bool ascentOnly;
  final DisplayUnits units;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  State<_DepthChart> createState() => _DepthChartState();
}

class _DepthChartState extends State<_DepthChart> {
  final scroll = ScrollController();
  int zoom = 1;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void move(double direction) {
    if (!scroll.hasClients) return;
    scroll.jumpTo(
      (scroll.offset + direction * scroll.position.viewportDimension * .75)
          .clamp(0.0, scroll.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data,
        points = widget.points,
        comparison = widget.comparison,
        ascentOnly = widget.ascentOnly,
        units = widget.units,
        selected = widget.selected,
        onSelect = widget.onSelect;
    final all = [...points, ...comparison];
    final end = math.max(1.0, all.map((p) => p.runtimeMin).reduce(math.max));
    final depth = math.max(1.0, all.map((p) => p.depthMetres).reduce(math.max));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Глубина 0–${depthText(depth, units)} ${depthUnit(units)} ↓'),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(liveRegion: true, child: Text('Масштаб времени ×$zoom')),
            IconButton(
              tooltip: 'Увеличить масштаб времени',
              onPressed: zoom == 4 ? null : () => setState(() => zoom++),
              icon: const Icon(
                Icons.zoom_in,
                semanticLabel: 'Увеличить масштаб времени',
              ),
            ),
            IconButton(
              tooltip: 'Уменьшить масштаб времени',
              onPressed: zoom == 1 ? null : () => setState(() => zoom--),
              icon: const Icon(
                Icons.zoom_out,
                semanticLabel: 'Уменьшить масштаб времени',
              ),
            ),
            IconButton(
              tooltip: 'Прокрутить профиль влево',
              onPressed: zoom == 1 ? null : () => move(-1),
              icon: const Icon(
                Icons.arrow_back,
                semanticLabel: 'Прокрутить профиль влево',
              ),
            ),
            IconButton(
              tooltip: 'Прокрутить профиль вправо',
              onPressed: zoom == 1 ? null : () => move(1),
              icon: const Icon(
                Icons.arrow_forward,
                semanticLabel: 'Прокрутить профиль вправо',
              ),
            ),
            TextButton(
              onPressed: zoom == 1
                  ? null
                  : () {
                      scroll.jumpTo(0);
                      setState(() => zoom = 1);
                    },
              child: const Text('Весь профиль'),
            ),
          ],
        ),
        Semantics(
          label:
              'График глубины. Для выбора точек используйте ползунок и кнопки ниже.',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 240,
              child: LayoutBuilder(
                builder: (context, viewport) => Scrollbar(
                  controller: scroll,
                  thumbVisibility: zoom > 1,
                  child: SingleChildScrollView(
                    controller: scroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: viewport.maxWidth * zoom,
                      height: 240,
                      child: LayoutBuilder(
                        builder: (context, constraints) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (event) {
                            final time =
                                (event.localPosition.dx / constraints.maxWidth)
                                    .clamp(0, 1) *
                                end;
                            var nearest = 0;
                            for (var i = 1; i < points.length; i++) {
                              if ((points[i].runtimeMin - time).abs() <
                                  (points[nearest].runtimeMin - time).abs()) {
                                nearest = i;
                              }
                            }
                            onSelect(nearest);
                          },
                          child: CustomPaint(
                            painter: _DepthPainter(
                              data: data,
                              points: points,
                              comparison: comparison,
                              ascentOnly: ascentOnly,
                              end: end,
                              depth: depth,
                              selected: selected,
                              color: Theme.of(context).colorScheme.primary,
                              comparedColor: Theme.of(
                                context,
                              ).colorScheme.tertiary,
                              gridColor: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text('Полный диапазон времени 0–${end.toStringAsFixed(2)} мин →'),
      ],
    );
  }
}

class _DepthPainter extends CustomPainter {
  _DepthPainter({
    required this.data,
    required this.points,
    required this.comparison,
    required this.ascentOnly,
    required this.end,
    required this.depth,
    required this.selected,
    required this.color,
    required this.comparedColor,
    required this.gridColor,
  });
  final ProfileData data;
  final List<ProfilePoint> points, comparison;
  final bool ascentOnly;
  final double end, depth;
  final int selected;
  final Color color, comparedColor, gridColor;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    Offset offset(ProfilePoint point) => Offset(
      point.runtimeMin / end * size.width,
      point.depthMetres / depth * size.height,
    );
    Path path(List<ProfilePoint> values, {bool primary = false}) {
      final value = Path();
      for (var i = 0; i < values.length; i++) {
        final point = offset(values[i]);
        if (i == 0 ||
            !values[i].continuesTrace ||
            (primary && !data.connects(values[i], ascentOnly: ascentOnly))) {
          value.moveTo(point.dx, point.dy);
        } else {
          value.lineTo(point.dx, point.dy);
        }
      }
      return value;
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path(points, primary: true), line);
    final dashed = Paint()
      ..color = comparedColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final metric in path(comparison).computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += 12) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 7, metric.length)),
          dashed,
        );
      }
    }
    if (points.isNotEmpty) {
      canvas.drawCircle(offset(points[selected]), 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _DepthPainter old) => true;
}

class _TissueChart extends StatelessWidget {
  const _TissueChart({
    required this.values,
    required this.units,
    required this.onSelect,
  });
  final List<TissuePoint> values;
  final DisplayUnits units;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final maximum = values.fold(
      1.0,
      (current, point) => math.max(
        current,
        math.max(
          point.nitrogenBar,
          math.max(point.heliumBar, point.mValueBar ?? 0),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Сплошная — N₂, штриховая — He, точки — M-value.'),
        Text('Давление 0–${usagePressure(maximum, units)} ↑'),
        Semantics(
          label:
              'График давлений 16 тканей. Выберите ткань в списке для чисел.',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 200,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (event) => onSelect(
                    (event.localPosition.dx / constraints.maxWidth * 15)
                            .round()
                            .clamp(0, 15) +
                        1,
                  ),
                  child: CustomPaint(
                    painter: _TissuePainter(
                      values: values,
                      maximum: maximum,
                      nitrogen: Theme.of(context).colorScheme.primary,
                      helium: Theme.of(context).colorScheme.tertiary,
                      mValue: Theme.of(context).colorScheme.onSurface,
                      grid: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('Ткань 1')),
            Expanded(child: Text('Ткань 16 →', textAlign: TextAlign.end)),
          ],
        ),
      ],
    );
  }
}

class _TissuePainter extends CustomPainter {
  _TissuePainter({
    required this.values,
    required this.maximum,
    required this.nitrogen,
    required this.helium,
    required this.mValue,
    required this.grid,
  });
  final List<TissuePoint> values;
  final double maximum;
  final Color nitrogen, helium, mValue, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    Offset point(int index, double value) => Offset(
      (index - 1) / 15 * size.width,
      size.height * (1 - value / maximum),
    );
    Path path(double Function(TissuePoint) selector) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final at = point(values[i].index, selector(values[i]));
        if (i == 0) {
          path.moveTo(at.dx, at.dy);
        } else {
          path.lineTo(at.dx, at.dy);
        }
      }
      return path;
    }

    canvas.drawPath(
      path((value) => value.nitrogenBar),
      Paint()
        ..color = nitrogen
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final dashed = Paint()
      ..color = helium
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final metric in path((value) => value.heliumBar).computeMetrics()) {
      for (var i = 0.0; i < metric.length; i += 12) {
        canvas.drawPath(
          metric.extractPath(i, math.min(i + 7, metric.length)),
          dashed,
        );
      }
    }
    for (final value in values) {
      if (value.mValueBar != null) {
        canvas.drawCircle(
          point(value.index, value.mValueBar!),
          3,
          Paint()..color = mValue,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TissuePainter old) => true;
}
