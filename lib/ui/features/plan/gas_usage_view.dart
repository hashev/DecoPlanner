import '../../core/planner_dialog.dart';
import '../../core/form_validation.dart';
import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import 'level_editor.dart';
import '../../../data/models/planner_document.dart';

String usageVolume(double litres, DisplayUnits units) =>
    units == DisplayUnits.metric
    ? '${litres.toStringAsFixed(1)} L'
    : '${Units.litresToCubicFeet(litres).toStringAsFixed(2)} cu ft';
String usagePressure(double bar, DisplayUnits units) {
  final value = units == DisplayUnits.metric ? bar : bar / Units.barPerPsi;
  return value.isFinite
      ? '${value.toStringAsFixed(1)} ${units == DisplayUnits.metric ? 'bar' : 'PSI'}'
      : 'Вне числового диапазона PSI';
}

String _tankPressureInput(double bar, DisplayUnits units) {
  final value = units == DisplayUnits.metric ? bar : bar / Units.barPerPsi;
  return value.isFinite ? number(value) : '';
}

String usageGas(GasUseTotal gas) => gas.kind == GasUseKind.ccrOxygen
    ? 'Кислород CCR'
    : 'OC ${(gas.gas.oxygen * 100).toStringAsFixed(1)}/${(gas.gas.helium * 100).toStringAsFixed(1)}';
String ratioText(TimeRatio ratio) => ratio.exact == null
    ? 'Недоступно: нулевое время уровней'
    : '${ratio.percent!.toStringAsFixed(2)} % · ${number(ratio.roundedBottomUnits!)}:${number(ratio.roundedComparedUnits!)}${ratio.roundedUnderestimates ? ' · округление занижает отношение' : ''}';

Future<TankRequirement?> editTankParameters(
  BuildContext context, {
  double waterLitres = 12,
  int cylinderCount = 1,
  double workingBar = 232,
  double freeLitres = 0,
  bool editableCount = true,
  bool nominalCapacity = false,
  required DisplayUnits units,
}) => showPlannerDialog<TankRequirement>(
  context: context,
  builder: (_) => _TankEditor(
    size: waterLitres,
    count: cylinderCount,
    working: workingBar,
    litres: freeLitres,
    editableCount: editableCount,
    nominalCapacity: nominalCapacity,
    units: units,
  ),
);

class GasUsageView extends StatelessWidget {
  const GasUsageView({
    super.key,
    required this.report,
    required this.units,
    required this.drafts,
    required this.onDraft,
    this.tanks = const [],
  });
  final GasUsageReport report;
  final DisplayUnits units;
  final Map<String, String> drafts;
  final void Function(String, String) onDraft;
  final List<TankPreset> tanks;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Расход газа и баллоны')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Один дайвер · без резервов'),
              const Text(
                'Давление расхода — линейная оценка. Начальное давление и минимальный газ не рассчитаны.',
              ),
              if (report.hasCcr)
                const Text(
                  'CCR: только метаболический кислород. Дилюент, промывки и утечки не рассчитаны.',
                ),
              const SizedBox(height: 16),
              Text('Время уровней ${report.bottomMin.toStringAsFixed(2)} мин'),
              Text(
                'Подъём с остановками ${report.ascentMin.toStringAsFixed(2)} мин',
              ),
              Text(
                'Только остановки ${report.decompressionMin.toStringAsFixed(2)} мин',
              ),
              Text(
                'Остановки / уровни: ${ratioText(report.decompressionRatio)}',
              ),
              Text('Подъём / уровни: ${ratioText(report.ascentRatio)}'),
              for (final gas in report.gases)
                _GasCard(
                  key: ValueKey(
                    '${gas.kind.name}:${gas.gas.oxygen}:${gas.gas.helium}:${units.name}',
                  ),
                  gas: gas,
                  tanks: tanks,
                  units: units,
                  drafts: drafts,
                  onDraft: onDraft,
                ),
              const SizedBox(height: 16),
              Text(
                'Группы остановок',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (report.stopGroups.isEmpty)
                const Text('Декомпрессионных остановок нет'),
              for (final group in report.stopGroups)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${depthText(group.deepestMetres, units)}–${depthText(group.shallowestMetres, units)} ${depthUnit(units)}',
                        ),
                        Text(
                          '${group.durationMin.toStringAsFixed(2)} мин · остановок ${group.stopCount} · среднее ${group.averageMinPerStop.toStringAsFixed(2)} мин',
                        ),
                        Text(ratioText(group.ratio)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GasCard extends StatefulWidget {
  const _GasCard({
    super.key,
    required this.gas,
    required this.units,
    required this.drafts,
    required this.onDraft,
    this.tanks = const [],
  });
  final GasUseTotal gas;
  final DisplayUnits units;
  final Map<String, String> drafts;
  final void Function(String, String) onDraft;
  final List<TankPreset> tanks;
  @override
  State<_GasCard> createState() => _GasCardState();
}

class _GasCardState extends State<_GasCard> {
  late final draftKey =
      'tank:${widget.gas.kind.name}:${widget.gas.gas.oxygen}:${widget.gas.gas.helium}';
  late double size = 12, working = 232;
  late int count = 2;
  @override
  void initState() {
    super.initState();
    final raw = widget.drafts[draftKey];
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map;
      final value = TankRequirement(
        freeLitres: widget.gas.litres,
        waterLitres: (data['litres'] as num).toDouble(),
        cylinderCount: data['count'] as int,
        workingBar: (data['bar'] as num).toDouble(),
      );
      size = value.waterLitres;
      count = value.cylinderCount;
      working = value.workingBar;
    } on Object {
      /* A malformed optional draft keeps the visible defaults. */
    }
  }

  Future<void> edit() async {
    final value = await showPlannerDialog<TankRequirement>(
      context: context,
      builder: (_) => _TankEditor(
        litres: widget.gas.litres,
        size: size,
        count: count,
        working: working,
        units: widget.units,
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      size = value.waterLitres;
      count = value.cylinderCount;
      working = value.workingBar;
    });
    widget.onDraft(
      draftKey,
      jsonEncode({'litres': size, 'count': count, 'bar': working}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gas = widget.gas;
    final tank = TankRequirement(
      freeLitres: gas.litres,
      waterLitres: size,
      cylinderCount: count,
      workingBar: working,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(usageGas(gas), style: Theme.of(context).textTheme.titleMedium),
            Text('Расход ${usageVolume(gas.litres, widget.units)}'),
            Text(
              'Время на газе ${gas.durationMin.toStringAsFixed(2)} мин · остановок ${gas.stopCount}',
            ),
            if (gas.averageMinPerStop != null)
              Text(
                'Среднее время остановки ${gas.averageMinPerStop!.toStringAsFixed(2)} мин',
              ),
            Text('Время на газе / уровни: ${ratioText(gas.ratio)}'),
            Text(
              'Баллоны $count × ${number(size)} L · рабочее ${usagePressure(working, widget.units)}',
            ),
            Text(
              'Давление расхода ${usagePressure(tank.requiredBar, widget.units)}',
            ),
            if (tank.exceedsWorkingPressure)
              const Text('Расход превышает вместимость при рабочем давлении'),
            if (widget.tanks.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Копия баллона из справочника',
                ),
                items: [
                  for (final tank in widget.tanks)
                    DropdownMenuItem(value: tank.id, child: Text(tank.name)),
                ],
                onChanged: (id) {
                  final selected = widget.tanks
                      .where((tank) => tank.id == id)
                      .firstOrNull;
                  if (selected == null) return;
                  setState(() {
                    size = selected.waterLitres;
                    working = selected.workingBar;
                  });
                  widget.onDraft(
                    draftKey,
                    jsonEncode({
                      'litres': size,
                      'count': count,
                      'bar': working,
                    }),
                  );
                },
              ),
            TextButton(
              onPressed: edit,
              child: Text('Выбрать баллон · ${usageGas(gas)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TankEditor extends StatefulWidget {
  const _TankEditor({
    required this.size,
    required this.litres,
    required this.count,
    required this.working,
    required this.units,
    this.editableCount = true,
    this.nominalCapacity = false,
  });
  final bool editableCount;
  final bool nominalCapacity;
  final double size, working, litres;
  final int count;
  final DisplayUnits units;
  @override
  State<_TankEditor> createState() => _TankEditorState();
}

class _TankEditorState extends State<_TankEditor> {
  String? error;
  final form = GlobalKey<FormState>();
  bool get imperialCapacity =>
      widget.nominalCapacity && widget.units == DisplayUnits.imperial;
  String get initialSize {
    try {
      return number(
        imperialCapacity
            ? CylinderCapacity(
                waterLitres: widget.size,
                workingBar: widget.working,
              ).nominalCubicFeet
            : widget.size,
      );
    } on CalculationFailure {
      return '';
    }
  }

  late final size = TextEditingController(text: initialSize);
  late final count = TextEditingController(text: widget.count.toString());
  late final pressure = TextEditingController(
    text: _tankPressureInput(widget.working, widget.units),
  );
  @override
  void dispose() {
    size.dispose();
    count.dispose();
    pressure.dispose();
    super.dispose();
  }

  double? parse(String? raw) =>
      double.tryParse((raw ?? '').replaceAll(',', '.'));
  String? positive(String? raw) {
    final value = parse(raw);
    return value == null || !value.isFinite || value <= 0
        ? 'Введите положительное конечное число'
        : null;
  }

  void save() {
    if (!validatePlannerForm(form)) return;
    try {
      final bar =
          pressure.text == _tankPressureInput(widget.working, widget.units)
          ? widget.working
          : widget.units == DisplayUnits.metric
          ? parse(pressure.text)!
          : Units.psiToBar(parse(pressure.text)!);
      Navigator.pop(
        context,
        TankRequirement(
          freeLitres: widget.litres,
          waterLitres: imperialCapacity
              ? size.text == initialSize &&
                        pressure.text ==
                            _tankPressureInput(widget.working, widget.units)
                    ? widget.size
                    : CylinderCapacity.fromImperial(
                        nominalCubicFeet: parse(size.text)!,
                        workingPsi: Units.barToPsi(bar),
                      ).waterLitres
              : parse(size.text)!,
          cylinderCount: int.parse(count.text),
          workingBar: bar,
        ),
      );
    } on CalculationFailure {
      setState(
        () => error = 'Параметры баллона выходят за числовую область расчёта',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Параметры баллона'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) Semantics(liveRegion: true, child: Text(error!)),
            if (widget.editableCount)
              TextFormField(
                controller: count,
                decoration: const InputDecoration(labelText: 'Число баллонов'),
                keyboardType: TextInputType.number,
                validator: (raw) =>
                    int.tryParse(raw ?? '') == null || int.parse(raw!) <= 0
                    ? 'Введите положительное целое число'
                    : null,
              ),
            TextFormField(
              controller: size,
              decoration: InputDecoration(
                labelText: imperialCapacity
                    ? 'Номинальная ёмкость, CuFt'
                    : 'Водяной объём одного баллона, L',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: positive,
            ),
            TextFormField(
              controller: pressure,
              decoration: InputDecoration(
                labelText:
                    'Рабочее давление, ${widget.units == DisplayUnits.metric ? 'bar' : 'PSI'}',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: positive,
              onFieldSubmitted: (_) => save(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отменить'),
      ),
      FilledButton(onPressed: save, child: const Text('Применить')),
    ],
  );
}
