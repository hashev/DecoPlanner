import '../../core/planner_dialog.dart';
import '../../../domain/planner_report.dart';
import '../export/report_view.dart';
import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../../../data/services/range_worker.dart';
import '../plan/level_editor.dart';
import '../plan/planner_view_model.dart';
import 'range_cell_view.dart';
import 'range_view_model.dart';

String rangeVariantLabel(RangeVariant value) => switch (value) {
  RangeVariant.base => 'Базовый',
  RangeVariant.noAdditionalGases => 'Без дополнительных OC-газов',
  RangeVariant.noSwitches => 'Без переключений',
};

class RangeView extends StatefulWidget {
  const RangeView({
    super.key,
    required this.model,
    required this.sourceId,
    this.bailoutId,
    this.viewModel,
  });
  final PlannerViewModel model;
  final String sourceId;
  final String? bailoutId;
  final RangeViewModel? viewModel;
  @override
  State<RangeView> createState() => _RangeViewState();
}

class _RangeViewState extends State<RangeView> {
  late final vm = widget.viewModel ?? RangeViewModel();
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final variants = <RangeVariant>{RangeVariant.base};
  late DisplayUnits inputUnits;
  late String observedPlan;
  String? loadedDraft;
  String get draftSignature => jsonEncode({
    for (final entry in model.toolDraft.entries)
      if (entry.key.startsWith(prefix)) entry.key: entry.value,
  });
  String? error;
  bool matrix = false;
  RangeVariant matrixVariant = RangeVariant.base;
  PlannerViewModel get model => widget.model;
  String get prefix =>
      'range:${widget.sourceId}:${widget.bailoutId ?? 'main'}:';
  DiveRequest get source {
    final index = model.dives.indexWhere((d) => d.id == widget.sourceId);
    if (index < 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Source dive was removed.',
      );
    }
    final dive = model.dives[index];
    if (index > 0 &&
        model.snapshotFor(model.dives[index - 1].id).status !=
            PlanStatus.ready) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Calculate the preceding dive first.',
      );
    }
    return DiveRequest(
      id: dive.id,
      settings: dive.settings,
      levels: dive.levels,
      switches: dive.switches,
      surfaceIntervalMin: dive.surfaceIntervalMin,
      initialState: index == 0
          ? dive.initialState
          : model.snapshotFor(model.dives[index - 1].id).result!.finalState,
    );
  }

  BailoutRequest? get bailout {
    if (widget.bailoutId == null) return null;
    final value = model.bailouts
        .where((b) => b.id == widget.bailoutId)
        .firstOrNull;
    if (value == null) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Bailout was removed.',
      );
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    observedPlan = jsonEncode(model.planRequest.toJson());
    load();
    model.addListener(changed);
  }

  void load() {
    inputUnits = switch (model.toolDraft['${prefix}units']) {
      'metric' => DisplayUnits.metric,
      'imperial' => DisplayUnits.imperial,
      _ => model.units,
    };
    final dive = model.dives.firstWhere((d) => d.id == widget.sourceId),
        last = dive.levels.last;
    for (final entry in {
      'depthFrom': last.depthMetres,
      'depthTo': last.depthMetres,
      'depthStep': dive.settings.stopGrid.stepMetres,
      'timeFrom': last.durationMin,
      'timeTo': last.durationMin,
      'timeStep': 1.0,
    }.entries) {
      fields[entry.key] = TextEditingController(
        text:
            model.toolDraft['$prefix${entry.key}'] ??
            number(
              entry.key.startsWith('depth') &&
                      inputUnits == DisplayUnits.imperial
                  ? Units.metresToFeet(entry.value)
                  : entry.value,
            ),
      );
    }
    final saved = model.toolDraft['${prefix}variants'];
    variants.clear();
    if (saved != null) {
      variants.addAll(
        RangeVariant.values.where((v) => saved.split(',').contains(v.name)),
      );
    } else {
      variants.add(RangeVariant.base);
    }
    syncUnits();
    loadedDraft = draftSignature;
  }

  void persist() {
    for (final e in fields.entries) {
      model.toolDraft['$prefix${e.key}'] = e.value.text;
    }
    model.toolDraft['${prefix}units'] = inputUnits.name;
    model.toolDraft['${prefix}variants'] = variants
        .map((v) => v.name)
        .join(',');
    loadedDraft = draftSignature;
  }

  void syncUnits() {
    if (inputUnits == model.units) return;
    final converted = <String, double>{};
    try {
      for (final key in fields.keys.where((key) => key.startsWith('depth'))) {
        final n = double.tryParse(fields[key]!.text.replaceAll(',', '.'));
        if (n == null || !n.isFinite || n < 0) return;
        converted[key] = inputUnits == DisplayUnits.metric
            ? Units.metresToFeet(n)
            : Units.feetToMetres(n);
      }
    } on CalculationFailure {
      return;
    }
    for (final e in converted.entries) {
      fields[e.key]!.text = number(e.value);
    }
    inputUnits = model.units;
    persist();
  }

  void changed() {
    final plan = jsonEncode(model.planRequest.toJson());
    if (observedPlan != plan) {
      observedPlan = plan;
      vm.invalidate();
    }
    if (loadedDraft != draftSignature &&
        model.dives.any((value) => value.id == widget.sourceId)) {
      for (final field in fields.values) {
        field.dispose();
      }
      fields.clear();
      load();
      vm.invalidate();
    }
    syncUnits();
    if (mounted) setState(() {});
  }

  void edited() {
    error = null;
    persist();
    vm.invalidate();
    model.setToolDraft('${prefix}units', inputUnits.name);
  }

  @override
  void dispose() {
    model.removeListener(changed);
    if (widget.viewModel == null) vm.dispose();
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  double read(String key) =>
      double.parse(fields[key]!.text.replaceAll(',', '.'));
  double depth(String key) => inputUnits == DisplayUnits.metric
      ? read(key)
      : Units.feetToMetres(read(key));
  Future<void> calculate() async {
    if (!form.currentState!.validate()) {
      setState(() => error = 'Исправьте отмеченные поля.');
      return;
    }
    try {
      final depths = RangeAxis(
        first: depth('depthFrom'),
        last: depth('depthTo'),
        step: depth('depthStep'),
      );
      final times = RangeAxis(
        first: read('timeFrom'),
        last: read('timeTo'),
        step: read('timeStep'),
      );
      final total = depths.length * times.length * variants.length;
      if (total == 0 || total > 1000) {
        setState(() => error = 'Выберите варианты и не более1000сценариев.');
        return;
      }
      final request = source,
          branch = bailout,
          revision = model.planRequest.revision;
      if (total > 100) {
        final accepted = await showPlannerDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Рассчитать $total сценариев?'),
            content: const Text(
              'Общий предел:1000ячеек,5миллионов итераций и60секунд. Расчёт можно отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отменить'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Построить'),
              ),
            ],
          ),
        );
        if (accepted != true ||
            !mounted ||
            revision != model.planRequest.revision) {
          return;
        }
      }
      setState(() => error = null);
      await vm.calculate(
        source: request,
        bailout: branch,
        depths: depths,
        durations: times,
        variants: variants.toList(),
        inputRevision: revision,
        dependencyVersion: 'plan:$revision:${widget.sourceId}',
      );
    } on CalculationFailure {
      if (mounted) {
        setState(
          () => error =
              'Проверьте диапазон: от≤до, шаг>0, оба конца попадают на сетку. Для повторного погружения сначала рассчитайте предыдущее.',
        );
      }
    }
  }

  String label(String key) => switch (key) {
    'depthFrom' => 'Глубина от, ${depthUnit(inputUnits)}',
    'depthTo' => 'Глубина до, ${depthUnit(inputUnits)}',
    'depthStep' => 'Шаг глубины, ${depthUnit(inputUnits)}',
    'timeFrom' => 'Время от, мин',
    'timeTo' => 'Время до, мин',
    _ => 'Шаг времени, мин',
  };
  void open(RangeSummary cell) {
    if (!vm.inputsCurrent || cell.failure != null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RangeCellView(cell: cell, range: vm, model: model),
      ),
    );
  }

  Widget header(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Погружение ${widget.sourceId}${widget.bailoutId == null ? '' : ' · bailout ${widget.bailoutId}'}',
      ),
      const Text(
        'Изменяется только последний введённый уровень. Остальные уровни, настройки, газы и поверхностный интервал сохраняются. Диапазон не меняет исходный план.',
      ),
      if (inputUnits != model.units)
        const Text(
          'Единицы полей сохранены: исправьте неверную глубину для преобразования.',
        ),
      const SizedBox(height: 16),
      Form(
        key: form,
        child: Column(
          children: [
            for (final key in fields.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: fields[key],
                  decoration: InputDecoration(labelText: label(key)),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (text) {
                    final n = double.tryParse(
                      (text ?? '').replaceAll(',', '.'),
                    );
                    return n == null ||
                            !n.isFinite ||
                            n < 0 ||
                            (key.endsWith('Step') && n == 0)
                        ? 'Введите допустимое конечное число'
                        : null;
                  },
                  onChanged: (_) => edited(),
                ),
              ),
          ],
        ),
      ),
      for (final variant in RangeVariant.values)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(rangeVariantLabel(variant)),
          subtitle: variant == RangeVariant.noAdditionalGases
              ? const Text(
                  'CCR diluent/setpoint сохраняются; в bailout отключены ветвевые switches.',
                )
              : null,
          value: variants.contains(variant),
          onChanged: (value) {
            if (value == true) {
              variants.add(variant);
            } else {
              variants.remove(variant);
            }
            edited();
          },
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: vm.status == RangeStatus.calculating ? null : calculate,
            child: const Text('Построить таблицы'),
          ),
          if (vm.status == RangeStatus.calculating)
            TextButton(
              onPressed: vm.cancel,
              child: const Text('Отменить диапазон'),
            ),
        ],
      ),
      if (error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (vm.status == RangeStatus.calculating)
        LinearProgressIndicator(
          value: vm.total == 0 ? null : vm.cells.length / vm.total,
          semanticsLabel: 'Сценариев ${vm.cells.length} из ${vm.total}',
        ),
      Semantics(
        liveRegion: true,
        child: Text(switch (vm.status) {
          RangeStatus.draft => 'Диапазон ещё не рассчитан',
          RangeStatus.calculating =>
            'Расчёт: ${vm.cells.length} из ${vm.total}',
          RangeStatus.complete =>
            'Диапазон готов: ${vm.cells.length} из ${vm.total}',
          RangeStatus.cancelled =>
            'Расчёт отменён: ${vm.cells.length} из ${vm.total}',
          RangeStatus.stale => 'Предыдущий диапазон неактуален · пересчитайте',
          RangeStatus.error =>
            'Диапазон не завершён: ${vm.cells.length} из ${vm.total}',
        }),
      ),
      if (vm.failure != null)
        Text(
          'Причина: ${vm.failure!.kind.name}${vm.failure!.calculationFailure == null ? '' : ' · ${vm.failure!.calculationFailure!.code.name}'}',
        ),
      if (vm.cells.isNotEmpty) ...[
        OutlinedButton.icon(
          onPressed: !vm.inputsCurrent || vm.status == RangeStatus.calculating
              ? null
              : () {
                  final revision = vm.inputRevision;
                  final capturedCells = vm.cells;
                  final report = PlannerReport.range(
                    cells: capturedCells,
                    depths: vm.depths!,
                    durations: vm.durations!,
                    variants: vm.variants,
                    units: model.units,
                    status: vm.status.name,
                    total: vm.total,
                  );
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ReportView(
                        report: report,
                        changes: Listenable.merge([model, vm]),
                        isCurrent: () =>
                            vm.inputsCurrent &&
                            vm.inputRevision == revision &&
                            vm.status != RangeStatus.calculating &&
                            vm.cells.length == capturedCells.length &&
                            identical(vm.cells.first, capturedCells.first) &&
                            model.planRequest.revision == revision,
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Печатный вид диапазона'),
        ),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Матрица вместо списка'),
          value: matrix,
          onChanged: (value) => setState(() => matrix = value),
        ),
        if (matrix)
          DropdownButtonFormField<RangeVariant>(
            key: ValueKey(matrixVariant),
            initialValue: vm.variants.contains(matrixVariant)
                ? matrixVariant
                : vm.variants.first,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Вариант матрицы'),
            items: [
              for (final v in vm.variants)
                DropdownMenuItem(value: v, child: Text(rangeVariantLabel(v))),
            ],
            onChanged: (value) => setState(() => matrixVariant = value!),
          ),
      ],
      const SizedBox(height: 16),
    ],
  );
  String summary(RangeSummary cell) => cell.failure != null
      ? 'Ошибка: ${cell.failure!.code.name}'
      : 'Runtime ${cell.runtimeMin!.toStringAsFixed(2)} мин · deco ${cell.decompressionMin!.toStringAsFixed(2)} мин';
  Widget grid() {
    final selected = vm.variants.contains(matrixVariant)
        ? matrixVariant
        : vm.variants.first;
    final records = {
      for (final cell in vm.cells.where((c) => c.variant == selected))
        '${cell.depthMetres}/${cell.durationMin}': cell,
    };
    final depths = vm.depths!, times = vm.durations!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMaxHeight: double.infinity,
        columns: [
          const DataColumn(label: Text('Глубина / время')),
          for (var ti = 0; ti < times.length; ti++)
            DataColumn(label: Text('${times.at(ti)} мин')),
        ],
        rows: [
          for (var di = 0; di < depths.length; di++)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    '${depthText(depths.at(di), model.units)} ${depthUnit(model.units)}',
                  ),
                ),
                for (var ti = 0; ti < times.length; ti++)
                  DataCell(
                    Builder(
                      builder: (context) {
                        final cell =
                            records['${depths.at(di)}/${times.at(ti)}'];
                        return cell == null
                            ? const Text('Ожидает')
                            : TextButton(
                                onPressed:
                                    vm.inputsCurrent && cell.failure == null
                                    ? () => open(cell)
                                    : null,
                                child: Text(
                                  cell.failure != null
                                      ? 'Ошибка: ${cell.failure!.code.name}'
                                      : '${cell.decompressionMin!.toStringAsFixed(2)} мин deco',
                                ),
                              );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Таблицы диапазонов')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount:
                  1 + (matrix && vm.cells.isNotEmpty ? 1 : vm.cells.length),
              itemBuilder: (context, index) {
                if (index == 0) return header(context);
                if (matrix) return grid();
                final cell = vm.cells[index - 1];
                return Card(
                  child: ListTile(
                    title: Text(
                      '${depthText(cell.depthMetres, model.units)} ${depthUnit(model.units)} · ${cell.durationMin} мин · ${rangeVariantLabel(cell.variant)}',
                    ),
                    subtitle: Text(summary(cell)),
                    onTap: vm.inputsCurrent && cell.failure == null
                        ? () => open(cell)
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
