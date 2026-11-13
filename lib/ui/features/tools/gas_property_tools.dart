import '../../core/planner_dialog.dart';
import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../plan/level_editor.dart';
import 'auxiliary_tools.dart';
import 'mixing_tools.dart';
import '../../../data/models/planner_document.dart';
import '../plan/planner_view_model.dart';

enum GasPropertyTool { modEnd, density, customMix }

class GasPropertyTools extends StatelessWidget {
  const GasPropertyTools({
    super.key,
    required this.model,
    this.tanks = const [],
  });
  final List<TankPreset> tanks;
  final PlannerViewModel model;
  @override
  Widget build(BuildContext context) =>
      _PropertyForm(model: model, tanks: tanks);
}

class _PropertyForm extends StatefulWidget {
  const _PropertyForm({required this.model, required this.tanks});
  final List<TankPreset> tanks;
  final PlannerViewModel model;
  @override
  State<_PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends State<_PropertyForm> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  GasPropertyTool tool = GasPropertyTool.modEnd;
  late DisplayUnits inputUnits;
  double narcosis = 1;
  Map<String, double?>? result;
  Gas? calculatedGas;
  String? error, resultPressure;
  bool stale = false;
  String? loadedDraft;
  String get draftSignature => jsonEncode({
    for (final entry in model.toolDraft.entries)
      if (entry.key.startsWith(prefix)) entry.key: entry.value,
  });
  PlannerViewModel get model => widget.model;
  String get prefix => 'properties:${tool.name}:';
  bool get custom => tool == GasPropertyTool.customMix;
  List<String> get fieldNames => [
    if (!custom) ...['oxygen', 'helium'],
    'depth',
    if (tool != GasPropertyTool.density) ...[
      'maximumPo2',
      if (!custom) 'minimumPo2' else 'end',
    ],
  ];
  PressureContext get pressure {
    final settings = model.selected.settings, original = settings.pressure;
    return PressureContext(
      surfaceBar: settings.altitude.enabled
          ? barometricPressureBar(
              settings.altitude.diveAltitudeMetres,
              seaLevelBar: settings.altitude.seaLevelBar,
            )
          : original.surfaceBar,
      barPerMetre: original.barPerMetre,
      waterVapourBar: original.waterVapourBar,
    );
  }

  String get pressureSignature => jsonEncode([
    pressure.surfaceBar,
    pressure.barPerMetre,
    pressure.waterVapourBar,
  ]);
  bool get current {
    try {
      return result != null && !stale && resultPressure == pressureSignature;
    } on CalculationFailure {
      return false;
    }
  }

  String get pressureLabel {
    try {
      return 'Поверхностное давление ${pressure.surfaceBar.toStringAsFixed(5)} bar · условия выбранного погружения';
    } on CalculationFailure {
      return 'Поверхностное давление недоступно: проверьте высоту и параметры давления.';
    }
  }

  String resultDepth(double metres) {
    try {
      return '${(model.units == DisplayUnits.metric ? metres : Units.metresToFeet(metres)).toStringAsFixed(1)} ${depthUnit(model.units)}';
    } on CalculationFailure {
      return 'Вне числового диапазона ${depthUnit(model.units)}';
    }
  }

  @override
  void initState() {
    super.initState();
    load();
    model.addListener(changed);
  }

  void load() {
    inputUnits = model.toolDraft['${prefix}units'] == 'imperial'
        ? DisplayUnits.imperial
        : model.toolDraft['${prefix}units'] == 'metric'
        ? DisplayUnits.metric
        : model.units;
    narcosis =
        double.tryParse(model.toolDraft['${prefix}narcosis'] ?? '1') ?? 1;
    if (![0.0, .3, 1.0, 2.0].contains(narcosis)) narcosis = 1;
    final metric = inputUnits == DisplayUnits.metric;
    final defaults = {
      'oxygen': tool == GasPropertyTool.modEnd
          ? model.toolDraft['oxygen'] ?? '21'
          : '21',
      'helium': tool == GasPropertyTool.modEnd
          ? model.toolDraft['helium'] ?? '0'
          : '35',
      'depth': number(metric ? 45 : Units.metresToFeet(45)),
      'end': number(metric ? 30 : Units.metresToFeet(30)),
      'maximumPo2': number(
        metric
            ? Units.ataToBar(custom ? 1.3 : 1.4)
            : custom
            ? 1.3
            : 1.4,
      ),
      'minimumPo2': number(metric ? .18 : Units.barToAta(.18)),
    };
    for (final entry in defaults.entries) {
      fields[entry.key] = TextEditingController(
        text: model.toolDraft['$prefix${entry.key}'] ?? entry.value,
      );
    }
    syncUnits();
    loadedDraft = draftSignature;
  }

  void persist() {
    for (final entry in fields.entries) {
      model.toolDraft['$prefix${entry.key}'] = entry.value.text;
    }
    model.toolDraft['${prefix}units'] = inputUnits.name;
    model.toolDraft['${prefix}narcosis'] = narcosis.toString();
    loadedDraft = draftSignature;
  }

  double read(String key) =>
      double.parse(fields[key]!.text.replaceAll(',', '.'));
  double depth(String key) => inputUnits == DisplayUnits.metric
      ? read(key)
      : Units.feetToMetres(read(key));
  double po2(String key) =>
      inputUnits == DisplayUnits.metric ? read(key) : Units.ataToBar(read(key));
  void syncUnits() {
    if (inputUnits == model.units) return;
    final dimensional = fieldNames.where(
      (key) => ['depth', 'end', 'maximumPo2', 'minimumPo2'].contains(key),
    );
    for (final key in dimensional) {
      final value = double.tryParse(fields[key]!.text.replaceAll(',', '.'));
      if (value == null || !value.isFinite || value < 0) return;
    }
    final converted = <String, double>{};
    try {
      for (final key in dimensional) {
        final value = read(key);
        final isDepth = key == 'depth' || key == 'end';
        final number = isDepth
            ? (inputUnits == DisplayUnits.metric
                  ? Units.metresToFeet(value)
                  : Units.feetToMetres(value))
            : (inputUnits == DisplayUnits.metric
                  ? Units.barToAta(value)
                  : Units.ataToBar(value));
        if (!number.isFinite) return;
        converted[key] = number;
      }
    } on CalculationFailure {
      return;
    }
    for (final entry in converted.entries) {
      fields[entry.key]!.text = number(entry.value);
    }
    inputUnits = model.units;
    persist();
  }

  void changed() {
    if (loadedDraft != draftSignature) {
      for (final controller in fields.values) {
        controller.dispose();
      }
      fields.clear();
      result = null;
      calculatedGas = null;
      error = null;
      stale = false;
      load();
    }
    syncUnits();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(changed);
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void switchTool(GasPropertyTool value) {
    if (tool == value) return;
    persist();
    for (final controller in fields.values) {
      controller.dispose();
    }
    fields.clear();
    setState(() {
      tool = value;
      result = null;
      calculatedGas = null;
      error = null;
      stale = false;
      load();
    });
  }

  void calculate() {
    error = null;
    if (!form.currentState!.validate()) {
      setState(() {
        stale = true;
        error = 'Исправьте отмеченные поля.';
      });
      return;
    }
    try {
      final context = pressure, at = depth('depth');
      final gas = custom
          ? GasProperties.customMix(
              depthMetres: at,
              oxygenBar: po2('maximumPo2'),
              maximumEndMetres: depth('end'),
              oxygenNarcosis: narcosis,
              pressure: context,
            )
          : Gas(oxygen: read('oxygen') / 100, helium: read('helium') / 100);
      final values = switch (tool) {
        GasPropertyTool.modEnd => <String, double?>{
          'Минимальная глубина': GasProperties.minimumDepthMetres(
            gas,
            po2('minimumPo2'),
            context,
          ),
          'MOD': GasProperties.maximumDepthMetres(
            gas,
            po2('maximumPo2'),
            context,
          ),
          'END': GasProperties.equivalentNarcoticDepthMetres(
            gas,
            at,
            narcosis,
            context,
          ),
        },
        GasPropertyTool.density => <String, double?>{
          'Плотность': GasProperties.densityGramsPerLitre(gas, at, context),
          'Эквивалентная глубина воздуха':
              GasProperties.equivalentAirDensityDepthMetres(gas, at, context),
        },
        GasPropertyTool.customMix => <String, double?>{
          'O₂': gas.oxygen * 100,
          'He': gas.helium * 100,
          'N₂': gas.nitrogen * 100,
        },
      };
      setState(() {
        result = values;
        calculatedGas = gas;
        stale = false;
        resultPressure = pressureSignature;
      });
    } on CalculationFailure catch (_) {
      setState(() {
        stale = true;
        error = custom
            ? 'Невозможно получить физическую смесь с этими PO₂ и END. Измените ограничения.'
            : 'Условия вне численной области модели. Проверьте значения.';
      });
    }
  }

  String label(String key) => switch (key) {
    'oxygen' => 'Кислород O₂, %',
    'helium' => 'Гелий He, %',
    'depth' => 'Глубина, ${depthUnit(inputUnits)}',
    'end' => 'Максимальный END, ${depthUnit(inputUnits)}',
    'maximumPo2' =>
      'Максимальный PO₂, ${inputUnits == DisplayUnits.metric ? 'bar' : 'ATA'}',
    _ =>
      'Минимальный PO₂, ${inputUnits == DisplayUnits.metric ? 'bar' : 'ATA'}',
  };
  String? validate(String key, String? text) {
    final value = double.tryParse((text ?? '').replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0) {
      return 'Введите конечное число не меньше нуля';
    }
    if (key.contains('Po2') && value == 0) return 'PO₂ должен быть больше нуля';
    if (key == 'oxygen' || key == 'helium') {
      if (value > 100) return 'Доля должна быть от0до100%';
      final other = double.tryParse(
        fields[key == 'oxygen' ? 'helium' : 'oxygen']!.text.replaceAll(
          ',',
          '.',
        ),
      );
      if (other != null && value + other > 100) {
        return 'O₂ + He не должны превышать100%';
      }
    }
    if (key == 'maximumPo2' && !custom) {
      final minimum = double.tryParse(
        fields['minimumPo2']!.text.replaceAll(',', '.'),
      );
      if (minimum != null && value <= minimum) {
        return 'Максимальный PO₂ должен быть больше минимального';
      }
    }
    return null;
  }

  Future<void> transfer() async {
    if (!current || !custom) return;
    final source = model.selected,
        revision = model.planRequest.revision,
        gas = calculatedGas!;
    var index = 0;
    final accepted = await showPlannerDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: const Text('Применить газ к уровню?'),
          content: DropdownButtonFormField<int>(
            initialValue: index,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Уровень погружения'),
            items: [
              for (var i = 0; i < source.levels.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    'Уровень ${i + 1} · ${depthText(source.levels[i].depthMetres, model.units)} ${depthUnit(model.units)}',
                  ),
                ),
            ],
            onChanged: (value) => update(() => index = value!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отменить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Применить газ'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted || !current) return;
    if (model.selected.id != source.id ||
        model.planRequest.revision != revision) {
      return;
    }
    try {
      final levels = [...source.levels], old = levels[index];
      levels[index] = Level(
        depthMetres: old.depthMetres,
        durationMin: old.durationMin,
        breathing: old.breathing.mode == BreathingMode.oc
            ? BreathingGas.oc(gas)
            : BreathingGas.ccr(gas, old.breathing.setpointBar!),
      );
      model.replaceLevels(levels);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Газ применён к уровню ${index + 1}')),
      );
    } on CalculationFailure catch (_) {
      setState(
        () => error =
            'Газ неприменим к выбранному режиму уровня. Входы плана сохранены.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Газовые инструменты',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        MixingToolView(model: model, tanks: widget.tanks),
                  ),
                ),
                child: const Text('Смешивание газов'),
              ),
              for (final tool in AuxiliaryTool.values)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          AuxiliaryToolView(model: model, tool: tool),
                    ),
                  ),
                  child: Text(auxiliaryTitle(tool)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<GasPropertyTool>(
            initialValue: tool,
            decoration: const InputDecoration(labelText: 'Инструмент'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: GasPropertyTool.modEnd,
                child: Text('MOD и END'),
              ),
              DropdownMenuItem(
                value: GasPropertyTool.density,
                child: Text('Плотность газа'),
              ),
              DropdownMenuItem(
                value: GasPropertyTool.customMix,
                child: Text('Подбор смеси'),
              ),
            ],
            onChanged: (value) => switchTool(value!),
          ),
          const SizedBox(height: 16),
          Text(pressureLabel),
          if (inputUnits != model.units)
            const Text(
              'Единицы полей сохранены: исправьте неверное значение для преобразования.',
            ),
          const SizedBox(height: 16),
          Form(
            key: form,
            child: Column(
              children: [
                for (final key in fieldNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      key: ValueKey('$prefix$key'),
                      controller: fields[key],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: label(key)),
                      validator: (text) => validate(key, text),
                      onChanged: (_) {
                        persist();
                        stale = true;
                        error = null;
                        model.setToolDraft('${prefix}units', inputUnits.name);
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (tool != GasPropertyTool.density)
            DropdownButtonFormField<double>(
              key: ValueKey('${prefix}narcosis'),
              initialValue: narcosis,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Наркотичность O₂ относительно N₂',
              ),
              items: [
                for (final value in [0.0, .3, 1.0, 2.0])
                  DropdownMenuItem(value: value, child: Text(number(value))),
              ],
              onChanged: (value) {
                narcosis = value!;
                persist();
                stale = true;
                model.setToolDraft('${prefix}narcosis', narcosis.toString());
              },
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: calculate,
            child: Text(
              tool == GasPropertyTool.modEnd ? 'Рассчитать MOD' : 'Рассчитать',
            ),
          ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (result != null) ...[
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              child: Text(
                current
                    ? 'Результат актуален'
                    : 'Предыдущий результат · пересчитайте',
              ),
            ),
            for (final entry in result!.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                subtitle: Text(
                  entry.value == null
                      ? 'Недоступно для этих условий'
                      : custom
                      ? '${entry.value!.toStringAsFixed(3)} %'
                      : entry.key == 'Плотность'
                      ? '${entry.value!.toStringAsFixed(4)} г/л'
                      : resultDepth(entry.value!),
                ),
              ),
            if (custom)
              OutlinedButton(
                onPressed: current ? transfer : null,
                child: const Text('Добавить газ в план'),
              ),
          ],
        ],
      ),
    ),
  );
}
