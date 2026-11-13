import '../../core/planner_dialog.dart';
import '../../core/form_validation.dart';
import 'dart:math' as math;
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';

String number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
String depthText(double metres, DisplayUnits units) =>
    number(units == DisplayUnits.metric ? metres : Units.metresToFeet(metres));
String depthUnit(DisplayUnits units) =>
    units == DisplayUnits.metric ? 'м' : 'ft';

Future<Level?> editLevel(
  BuildContext context, {
  required Level level,
  required DisplayUnits units,
  required double previousDepth,
  required CalculationSettings settings,
}) => showPlannerDialog<Level>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _LevelEditor(
    level: level,
    units: units,
    previousDepth: previousDepth,
    settings: settings,
  ),
);

class _LevelEditor extends StatefulWidget {
  const _LevelEditor({
    required this.level,
    required this.units,
    required this.previousDepth,
    required this.settings,
  });
  final Level level;
  final DisplayUnits units;
  final double previousDepth;
  final CalculationSettings settings;
  @override
  State<_LevelEditor> createState() => _LevelEditorState();
}

class _LevelEditorState extends State<_LevelEditor> {
  final form = GlobalKey<FormState>();
  late final depth = TextEditingController(
    text: depthText(widget.level.depthMetres, widget.units),
  );
  late final duration = TextEditingController(
    text: number(widget.level.durationMin),
  );
  late final oxygen = TextEditingController(
    text: number(widget.level.breathing.gas.oxygen * 100),
  );
  late final helium = TextEditingController(
    text: number(widget.level.breathing.gas.helium * 100),
  );
  late final setpoint = TextEditingController(
    text: number(
      Units.barToAta(widget.level.breathing.setpointBar ?? Units.ataToBar(1.3)),
    ),
  );
  late BreathingMode mode = widget.level.breathing.mode;
  String? error;
  double? parse(String? value) =>
      double.tryParse((value ?? '').replaceAll(',', '.'));
  String? positive(String? value) {
    final n = parse(value);
    return n == null || !n.isFinite || n < 0
        ? 'Введите конечное число не меньше нуля'
        : null;
  }

  Widget field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: validator ?? positive,
      onFieldSubmitted: (_) => save(),
    ),
  );
  void save() {
    if (!validatePlannerForm(form)) return;
    try {
      final d = depth.text == depthText(widget.level.depthMetres, widget.units)
          ? widget.level.depthMetres
          : widget.units == DisplayUnits.metric
          ? parse(depth.text)!
          : Units.feetToMetres(parse(depth.text)!);
      final gas = Gas(
        oxygen: oxygen.text == number(widget.level.breathing.gas.oxygen * 100)
            ? widget.level.breathing.gas.oxygen
            : parse(oxygen.text)! / 100,
        helium: helium.text == number(widget.level.breathing.gas.helium * 100)
            ? widget.level.breathing.gas.helium
            : parse(helium.text)! / 100,
      );
      final breathing = mode == BreathingMode.oc
          ? BreathingGas.oc(gas)
          : BreathingGas.ccr(
              gas,
              widget.level.breathing.setpointBar != null &&
                      setpoint.text ==
                          number(
                            Units.barToAta(widget.level.breathing.setpointBar!),
                          )
                  ? widget.level.breathing.setpointBar!
                  : Units.ataToBar(parse(setpoint.text)!),
            );
      final level = Level(
        depthMetres: d,
        durationMin: parse(duration.text)!,
        breathing: breathing,
      );
      prepareLevel(
        startDepthMetres: widget.previousDepth,
        targetDepthMetres: d,
        levelDurationMin: level.durationMin,
        descentMetresPerMin: widget.settings.descentMetresPerMin,
        ascentMetresPerMin: widget.settings.ascentMetresPerMin,
        includeDescentInLevelTime: widget.settings.includeDescentInLevelTime,
        movementGas: breathing,
        levelGas: breathing,
      );
      Navigator.pop(context, level);
    } on CalculationFailure catch (_) {
      setState(() {
        error =
            'Проверьте состав газа, setpoint и длительность: времени должно хватать на спуск.';
      });
    }
  }

  Future<void> requestCancel() async {
    final original = widget.level;
    final dirty =
        depth.text != depthText(original.depthMetres, widget.units) ||
        duration.text != number(original.durationMin) ||
        oxygen.text != number(original.breathing.gas.oxygen * 100) ||
        helium.text != number(original.breathing.gas.helium * 100) ||
        mode != original.breathing.mode ||
        setpoint.text !=
            number(
              Units.barToAta(
                original.breathing.setpointBar ?? Units.ataToBar(1.3),
              ),
            );
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final decision = await showPlannerDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сохранить изменения уровня?'),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('Продолжить редактирование'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Отменить изменения'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (decision == 'discard') Navigator.pop(context);
    if (decision == 'save') save();
  }

  @override
  void dispose() {
    for (final c in [depth, duration, oxygen, helium, setpoint]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context), compact = size.width < 600;
    final dialog = Dialog(
      insetPadding: EdgeInsets.all(compact ? 8 : 24),
      child: SizedBox(
        width: 560,
        height: math.min(760, size.height - 48),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Уровень погружения',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<BreathingMode>(
                          isExpanded: true,
                          initialValue: mode,
                          decoration: const InputDecoration(
                            labelText: 'Режим дыхания',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: BreathingMode.oc,
                              child: Text('OC — открытый цикл'),
                            ),
                            DropdownMenuItem(
                              value: BreathingMode.ccr,
                              child: Text('CCR — ребризер'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                mode = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        field('Глубина, ${depthUnit(widget.units)}', depth),
                        field('Длительность, мин', duration),
                        field(
                          'Кислород O₂, %',
                          oxygen,
                          validator: (text) {
                            final error = positive(text);
                            if (error != null) return error;
                            final n = parse(text)!;
                            return n <= 0 || n > 100
                                ? 'Кислород должен быть больше 0 и не больше 100 %'
                                : null;
                          },
                        ),
                        field(
                          'Гелий He, %',
                          helium,
                          validator: (text) {
                            final error = positive(text);
                            if (error != null) return error;
                            return parse(text)! + (parse(oxygen.text) ?? 0) >
                                    100
                                ? 'Сумма O₂ и He не должна превышать 100 %'
                                : null;
                          },
                        ),
                        if (mode == BreathingMode.ccr)
                          field('Setpoint, ATA', setpoint),
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
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OverflowBar(
                  spacing: 12,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: requestCancel,
                      child: const Text('Отменить'),
                    ),
                    FilledButton(
                      onPressed: save,
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return PopScope<Level>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) requestCancel();
      },
      child: dialog,
    );
  }
}
