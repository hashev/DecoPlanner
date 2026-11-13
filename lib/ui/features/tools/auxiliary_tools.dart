import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../plan/level_editor.dart';
import '../plan/planner_view_model.dart';

enum AuxiliaryTool { topOff, equalizer, capacity }

String auxiliaryTitle(AuxiliaryTool tool) => switch (tool) {
  AuxiliaryTool.topOff => 'Дозаправка',
  AuxiliaryTool.equalizer => 'Уравнивание баллонов',
  AuxiliaryTool.capacity => 'Конверсия баллонов',
};

class AuxiliaryToolView extends StatefulWidget {
  const AuxiliaryToolView({super.key, required this.model, required this.tool});
  final PlannerViewModel model;
  final AuxiliaryTool tool;
  @override
  State<AuxiliaryToolView> createState() => _AuxiliaryToolViewState();
}

class _AuxiliaryToolViewState extends State<AuxiliaryToolView> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late DisplayUnits inputUnits;
  String? loadedDraft, error;
  bool stale = false, fromMetric = true;
  Gas? gas;
  double? equalized;
  CylinderCapacity? capacity;
  PlannerViewModel get model => widget.model;
  AuxiliaryTool get tool => widget.tool;
  String get prefix => 'auxiliary:${tool.name}:';
  String get signature => jsonEncode({
    for (final e in model.toolDraft.entries)
      if (e.key.startsWith(prefix)) e.key: e.value,
  });
  bool get metric => inputUnits == DisplayUnits.metric;
  Map<String, double> get defaults => switch (tool) {
    AuxiliaryTool.topOff => {
      'initialOxygen': 21,
      'initialHelium': 0,
      'initialPressure': 50,
      'topUpOxygen': 32,
      'topUpHelium': 0,
      'finalPressure': 200,
    },
    AuxiliaryTool.equalizer => {
      'firstVolume': 12,
      'firstPressure': 50,
      'secondVolume': 50,
      'secondPressure': 200,
    },
    AuxiliaryTool.capacity => {
      'waterLitres': 12,
      'workingBar': 232,
      'nominalCuft': 80,
      'workingPsi': 3000,
    },
  };
  bool get hasResult => gas != null || equalized != null || capacity != null;
  @override
  void initState() {
    super.initState();
    load();
    model.addListener(changed);
  }

  double toDisplay(String key, double canonical, DisplayUnits units) {
    if (units == DisplayUnits.metric || tool == AuxiliaryTool.capacity) {
      return canonical;
    }
    if (key.endsWith('Pressure')) return Units.barToPsi(canonical);
    // Ideal tank factor, free CuFt per100PSI at1ATA. This is not nominal CuFt.
    if (key.endsWith('Volume')) {
      return canonical *
          100 *
          Units.barPerPsi /
          Units.barPerAta /
          Units.litresPerCubicFoot;
    }
    return canonical;
  }

  double toCanonical(String key, double displayed) {
    if (metric || tool == AuxiliaryTool.capacity) return displayed;
    if (key.endsWith('Pressure')) return Units.psiToBar(displayed);
    if (key.endsWith('Volume')) {
      return displayed *
          Units.litresPerCubicFoot *
          Units.barPerAta /
          (100 * Units.barPerPsi);
    }
    return displayed;
  }

  void load() {
    inputUnits = switch (model.toolDraft['${prefix}units']) {
      'metric' => DisplayUnits.metric,
      'imperial' => DisplayUnits.imperial,
      _ => model.units,
    };
    fromMetric = model.toolDraft['${prefix}fromMetric'] != 'false';
    for (final entry in defaults.entries) {
      fields[entry.key] = TextEditingController(
        text:
            model.toolDraft['$prefix${entry.key}'] ??
            number(toDisplay(entry.key, entry.value, inputUnits)),
      );
    }
    syncUnits();
    loadedDraft = signature;
  }

  void persist() {
    for (final entry in fields.entries) {
      model.toolDraft['$prefix${entry.key}'] = entry.value.text;
    }
    model.toolDraft['${prefix}units'] = inputUnits.name;
    model.toolDraft['${prefix}fromMetric'] = fromMetric.toString();
    loadedDraft = signature;
  }

  double read(String key) =>
      double.parse(fields[key]!.text.replaceAll(',', '.'));
  double physical(String key) => toCanonical(key, read(key));
  void syncUnits() {
    if (inputUnits == model.units || tool == AuxiliaryTool.capacity) return;
    final changes = <String, double>{};
    try {
      for (final key in fields.keys.where(
        (k) => k.endsWith('Pressure') || k.endsWith('Volume'),
      )) {
        final value = double.tryParse(fields[key]!.text.replaceAll(',', '.'));
        if (value == null || !value.isFinite || value < 0) return;
        final converted = toDisplay(key, toCanonical(key, value), model.units);
        if (!converted.isFinite) return;
        changes[key] = converted;
      }
    } on CalculationFailure {
      return;
    }
    for (final e in changes.entries) {
      fields[e.key]!.text = number(e.value);
    }
    inputUnits = model.units;
    persist();
  }

  void changed() {
    if (loadedDraft != signature) {
      for (final field in fields.values) {
        field.dispose();
      }
      fields.clear();
      gas = null;
      equalized = null;
      capacity = null;
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
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String label(String key) => switch (key) {
    'initialOxygen' => 'Исходный O₂, %',
    'initialHelium' => 'Исходный He, %',
    'topUpOxygen' => 'Добавляемый O₂, %',
    'topUpHelium' => 'Добавляемый He, %',
    'initialPressure' => 'Исходное давление, ${metric ? 'bar' : 'PSI'}',
    'finalPressure' => 'Итоговое давление, ${metric ? 'bar' : 'PSI'}',
    'firstPressure' => 'Давление баллона 1, ${metric ? 'bar' : 'PSI'}',
    'secondPressure' => 'Давление баллона 2, ${metric ? 'bar' : 'PSI'}',
    'firstVolume' =>
      'Баллон 1, ${metric ? 'водяной объём L' : 'tank factor CuFt/100 PSI'}',
    'secondVolume' =>
      'Баллон 2, ${metric ? 'водяной объём L' : 'tank factor CuFt/100 PSI'}',
    'waterLitres' => 'Водяной объём, L',
    'workingBar' => 'Рабочее давление, bar',
    'nominalCuft' => 'Номинальная ёмкость, CuFt',
    _ => 'Рабочее давление, PSI',
  };
  List<String> get activeFields => tool != AuxiliaryTool.capacity
      ? fields.keys.toList()
      : fromMetric
      ? ['waterLitres', 'workingBar']
      : ['nominalCuft', 'workingPsi'];
  String? validate(String key, String? text) {
    final value = double.tryParse((text ?? '').replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0) {
      return 'Введите конечное число не меньше нуля';
    }
    if ((key.endsWith('Volume') ||
            tool == AuxiliaryTool.capacity ||
            key == 'finalPressure') &&
        value == 0) {
      return 'Значение должно быть больше нуля';
    }
    if (key.endsWith('Oxygen') || key.endsWith('Helium')) {
      if (value > 100) return 'Доля должна быть от0до100%';
      final otherKey = key.endsWith('Oxygen')
          ? key.replaceFirst('Oxygen', 'Helium')
          : key.replaceFirst('Helium', 'Oxygen');
      final other = double.tryParse(
        fields[otherKey]!.text.replaceAll(',', '.'),
      );
      if (other != null && value + other > 100) {
        return 'O₂ + He не должны превышать100%';
      }
    }
    if (key == 'finalPressure') {
      final start = double.tryParse(
        fields['initialPressure']!.text.replaceAll(',', '.'),
      );
      if (start != null && value <= start) {
        return 'Итоговое давление должно быть выше исходного';
      }
    }
    return null;
  }

  void calculate() {
    if (!form.currentState!.validate()) {
      setState(() {
        stale = true;
        error = 'Исправьте отмеченные поля.';
      });
      return;
    }
    try {
      switch (tool) {
        case AuxiliaryTool.topOff:
          gas = topOff(
            initialGas: Gas(
              oxygen: read('initialOxygen') / 100,
              helium: read('initialHelium') / 100,
            ),
            initialBar: physical('initialPressure'),
            topUpGas: Gas(
              oxygen: read('topUpOxygen') / 100,
              helium: read('topUpHelium') / 100,
            ),
            finalBar: physical('finalPressure'),
          );
        case AuxiliaryTool.equalizer:
          equalized = equalizedPressureBar(
            firstBar: physical('firstPressure'),
            firstWaterLitres: physical('firstVolume'),
            secondBar: physical('secondPressure'),
            secondWaterLitres: physical('secondVolume'),
          );
        case AuxiliaryTool.capacity:
          final converted = fromMetric
              ? CylinderCapacity(
                  waterLitres: read('waterLitres'),
                  workingBar: read('workingBar'),
                )
              : CylinderCapacity.fromImperial(
                  nominalCubicFeet: read('nominalCuft'),
                  workingPsi: read('workingPsi'),
                );
          // Force derived quantities through finite-domain checks before success.
          converted.nominalCubicFeet;
          converted.workingPsi;
          capacity = converted;
      }
      setState(() {
        stale = false;
        error = null;
      });
    } on CalculationFailure {
      setState(() {
        stale = true;
        error = 'Значения вне численной области модели. Измените входы.';
      });
    }
  }

  String displayPressure(double bar) {
    try {
      return '${(model.units == DisplayUnits.metric ? bar : Units.barToPsi(bar)).toStringAsFixed(3)} ${model.units == DisplayUnits.metric ? 'bar' : 'PSI'}';
    } on CalculationFailure {
      return 'Вне числового диапазона PSI';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(auxiliaryTitle(tool))),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (tool == AuxiliaryTool.topOff)
                const Text(
                  'Идеальное смешение по давлениям. Для дозаправки итоговое давление должно быть выше исходного.',
                ),
              if (tool == AuxiliaryTool.equalizer)
                const Text(
                  'Идеальное уравнивание при одинаковой температуре. Imperial tank factor — CuFt/100 PSI при1ATA, не номинальная ёмкость.',
                ),
              if (tool == AuxiliaryTool.capacity) ...[
                const Text(
                  'Приближённая номинальная ёмкость с эмпирической поправкой. Параметры баллона уточняйте у производителя.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<bool>(
                  initialValue: fromMetric,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Направление'),
                  items: const [
                    DropdownMenuItem(
                      value: true,
                      child: Text('L/bar → CuFt/PSI'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('CuFt/PSI → L/bar'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      fromMetric = value!;
                      stale = true;
                      error = null;
                    });
                    persist();
                    model.setToolDraft(
                      '${prefix}fromMetric',
                      fromMetric.toString(),
                    );
                  },
                ),
              ],
              if (tool != AuxiliaryTool.capacity && inputUnits != model.units)
                const Text(
                  'Единицы полей сохранены: исправьте неверное значение для преобразования.',
                ),
              const SizedBox(height: 24),
              Form(
                key: form,
                child: Column(
                  children: [
                    for (final key in activeFields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          key: ValueKey(key),
                          controller: fields[key],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(labelText: label(key)),
                          validator: (text) => validate(key, text),
                          onChanged: (_) {
                            stale = true;
                            error = null;
                            persist();
                            model.setToolDraft(
                              '${prefix}units',
                              inputUnits.name,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: calculate,
                child: Text(
                  tool == AuxiliaryTool.capacity
                      ? 'Преобразовать'
                      : 'Рассчитать',
                ),
              ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (hasResult) ...[
                const SizedBox(height: 24),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    stale
                        ? 'Предыдущий результат · пересчитайте'
                        : 'Результат актуален',
                  ),
                ),
                if (gas != null)
                  Text(
                    'O₂ ${(gas!.oxygen * 100).toStringAsFixed(3)} % · He ${(gas!.helium * 100).toStringAsFixed(3)} % · N₂ ${(gas!.nitrogen * 100).toStringAsFixed(3)} %',
                  ),
                if (equalized != null)
                  Text('После уравнивания: ${displayPressure(equalized!)}'),
                if (capacity != null) ...[
                  Text(
                    'Водяной объём: ${capacity!.waterLitres.toStringAsFixed(6)} L',
                  ),
                  Text(
                    'Рабочее давление: ${capacity!.workingBar.toStringAsFixed(6)} bar',
                  ),
                  Text(
                    'Номинальная ёмкость: ${capacity!.nominalCubicFeet.toStringAsFixed(6)} CuFt',
                  ),
                  Text(
                    'Рабочее давление: ${capacity!.workingPsi.toStringAsFixed(6)} PSI',
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
