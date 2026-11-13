import '../../core/planner_dialog.dart';
import '../../core/form_validation.dart';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import 'level_editor.dart';
import '../../../data/models/planner_document.dart';

Future<List<GasSwitch>?> editGasSwitches(
  BuildContext context, {
  required List<GasSwitch> initial,
  required DisplayUnits units,
  required bool ccr,
  List<GasSetPreset> presets = const [],
  Future<GasSetPreset?> Function(List<GasSwitch>)? savePreset,
}) => showPlannerDialog<List<GasSwitch>>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _SwitchesEditor(
    initial: initial,
    units: units,
    ccr: ccr,
    presets: presets,
    savePreset: savePreset,
  ),
);

class _SwitchesEditor extends StatefulWidget {
  const _SwitchesEditor({
    required this.initial,
    required this.units,
    required this.ccr,
    required this.presets,
    this.savePreset,
  });
  final List<GasSwitch> initial;
  final DisplayUnits units;
  final bool ccr;
  final List<GasSetPreset> presets;
  final Future<GasSetPreset?> Function(List<GasSwitch>)? savePreset;
  @override
  State<_SwitchesEditor> createState() => _SwitchesEditorState();
}

class _SwitchesEditorState extends State<_SwitchesEditor> {
  late final switches = widget.initial.toList();
  late final presets = widget.presets.toList();
  Future<void> edit(int? index) async {
    final value = await showPlannerDialog<GasSwitch>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SwitchEditor(
        initial: index == null ? null : switches[index],
        units: widget.units,
        ccr: widget.ccr,
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (index == null) {
        switches.add(value);
      } else {
        switches[index] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Переключения газов'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.ccr
                  ? 'CCR: дилюент и setpoint. OC-переключения означают переход на открытый цикл; для сценария отказа используйте bailout.'
                  : 'OC: декомпрессионные газы. Потерянные газы сохраняются в списке и не используются.',
            ),
            if (presets.any(
              (p) =>
                  widget.ccr ||
                  p.switches.every((s) => s.breathing.mode == BreathingMode.oc),
            ))
              DropdownButtonFormField<String>(
                key: ValueKey(presets.length),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Загрузить копию набора',
                ),
                items: [
                  for (final preset in presets.where(
                    (p) =>
                        widget.ccr ||
                        p.switches.every(
                          (s) => s.breathing.mode == BreathingMode.oc,
                        ),
                  ))
                    DropdownMenuItem(
                      value: preset.id,
                      child: Text(preset.name),
                    ),
                ],
                onChanged: (id) {
                  final preset = presets.where((p) => p.id == id).firstOrNull;
                  if (preset == null) return;
                  setState(() {
                    switches
                      ..clear()
                      ..addAll(preset.switches);
                  });
                },
              ),
            if (widget.savePreset != null)
              TextButton(
                onPressed: () async {
                  final value = await widget.savePreset!(
                    List.unmodifiable(switches),
                  );
                  if (value != null && mounted) {
                    setState(() {
                      presets.removeWhere((p) => p.id == value.id);
                      presets.add(value);
                    });
                  }
                },
                child: const Text('Сохранить как набор'),
              ),
            if (switches.isEmpty) const Text('Дополнительных переключений нет'),
            for (var i = 0; i < switches.length; i++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${depthText(switches[i].depthMetres, widget.units)} ${depthUnit(widget.units)} · ${switches[i].breathing.mode.name.toUpperCase()} · ${(switches[i].breathing.gas.oxygen * 100).toStringAsFixed(1)}/${(switches[i].breathing.gas.helium * 100).toStringAsFixed(1)}',
                      ),
                      if (switches[i].breathing.setpointBar != null)
                        Text(
                          'Setpoint ${Units.barToAta(switches[i].breathing.setpointBar!).toStringAsFixed(2)} ATA',
                        ),
                      Text(switches[i].lost ? 'Газ потерян' : 'Доступен'),
                      if (switches[i].minimumStopMin != null)
                        Text(
                          'Минимальная остановка ${number(switches[i].minimumStopMin!)} мин',
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => edit(i),
                            child: Text('Изменить переключение ${i + 1}'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => switches.removeAt(i)),
                            child: Text('Удалить переключение ${i + 1}'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => edit(null),
              icon: const Icon(Icons.add),
              label: const Text('Добавить переключение'),
            ),
            TextButton(
              onPressed: switches.isEmpty
                  ? null
                  : () => setState(() => switches.clear()),
              child: const Text('Очистить переключения'),
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
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, List<GasSwitch>.unmodifiable(switches)),
        child: const Text('Применить переключения'),
      ),
    ],
  );
}

class _SwitchEditor extends StatefulWidget {
  const _SwitchEditor({
    required this.initial,
    required this.units,
    required this.ccr,
  });
  final GasSwitch? initial;
  final DisplayUnits units;
  final bool ccr;
  @override
  State<_SwitchEditor> createState() => _SwitchEditorState();
}

class _SwitchEditorState extends State<_SwitchEditor> {
  final form = GlobalKey<FormState>();
  late BreathingMode mode =
      widget.initial?.breathing.mode ??
      (widget.ccr ? BreathingMode.ccr : BreathingMode.oc);
  late bool lost = widget.initial?.lost ?? false;
  late final depth = TextEditingController(
    text: depthText(widget.initial?.depthMetres ?? 6, widget.units),
  );
  late final oxygen = TextEditingController(
    text: number(
      (widget.initial?.breathing.gas.oxygen ?? (widget.ccr ? .21 : 1)) * 100,
    ),
  );
  late final helium = TextEditingController(
    text: number((widget.initial?.breathing.gas.helium ?? 0) * 100),
  );
  late final setpoint = TextEditingController(
    text: number(
      Units.barToAta(
        widget.initial?.breathing.setpointBar ?? Units.ataToBar(1.3),
      ),
    ),
  );
  late final minimum = TextEditingController(
    text: widget.initial?.minimumStopMin == null
        ? ''
        : number(widget.initial!.minimumStopMin!),
  );
  String? error;
  double? parse(String? raw) =>
      double.tryParse((raw ?? '').replaceAll(',', '.'));
  Widget field(
    String label,
    TextEditingController controller, {
    bool positive = false,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (raw) {
        if (optional && (raw ?? '').trim().isEmpty) return null;
        final value = parse(raw);
        return value == null ||
                !value.isFinite ||
                (positive ? value <= 0 : value < 0)
            ? 'Введите допустимое конечное число'
            : null;
      },
    ),
  );
  void save() {
    if (!validatePlannerForm(form)) return;
    try {
      final old = widget.initial;
      final gas = Gas(
        oxygen:
            old != null && oxygen.text == number(old.breathing.gas.oxygen * 100)
            ? old.breathing.gas.oxygen
            : parse(oxygen.text)! / 100,
        helium:
            old != null && helium.text == number(old.breathing.gas.helium * 100)
            ? old.breathing.gas.helium
            : parse(helium.text)! / 100,
      );
      final metres =
          old != null && depth.text == depthText(old.depthMetres, widget.units)
          ? old.depthMetres
          : widget.units == DisplayUnits.metric
          ? parse(depth.text)!
          : Units.feetToMetres(parse(depth.text)!);
      final sp = mode == BreathingMode.oc
          ? 0.0
          : old?.breathing.setpointBar != null &&
                setpoint.text ==
                    number(Units.barToAta(old!.breathing.setpointBar!))
          ? old.breathing.setpointBar!
          : Units.ataToBar(parse(setpoint.text)!);
      Navigator.pop(
        context,
        GasSwitch(
          depthMetres: metres,
          breathing: mode == BreathingMode.oc
              ? BreathingGas.oc(gas)
              : BreathingGas.ccr(gas, sp),
          lost: lost,
          minimumStopMin: minimum.text.trim().isEmpty
              ? null
              : parse(minimum.text),
        ),
      );
    } on CalculationFailure {
      setState(
        () => error =
            'Сумма O₂ и He должна быть не больше 100%; для CCR требуется инертный дилюент.',
      );
    }
  }

  @override
  void dispose() {
    for (final field in [depth, oxygen, helium, setpoint, minimum]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Газ и глубина переключения'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Semantics(liveRegion: true, child: Text(error!)),
              if (widget.ccr || mode == BreathingMode.ccr)
                DropdownButtonFormField<BreathingMode>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                    labelText: 'Режим переключения',
                  ),
                  items: [
                    for (final value in BreathingMode.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.name.toUpperCase()),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => mode = v);
                  },
                ),
              field('Глубина переключения, ${depthUnit(widget.units)}', depth),
              field('Кислород O₂, %', oxygen),
              field('Гелий He, %', helium),
              if (mode == BreathingMode.ccr)
                field('Setpoint, ATA', setpoint, positive: true),
              field(
                'Минимальная остановка, мин (необязательно)',
                minimum,
                positive: true,
                optional: true,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Газ потерян'),
                value: lost,
                onChanged: (v) => setState(() => lost = v ?? false),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отменить'),
      ),
      FilledButton(onPressed: save, child: const Text('Сохранить газ')),
    ],
  );
}
