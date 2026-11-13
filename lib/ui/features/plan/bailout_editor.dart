import '../../core/planner_dialog.dart';
import '../../core/form_validation.dart';
import 'dart:math' as math;
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import 'level_editor.dart';

final class BailoutDraft {
  const BailoutDraft(this.runtimeMin, this.initialOcGas, this.switches);
  final double runtimeMin;
  final Gas initialOcGas;
  final List<GasSwitch> switches;
}

Future<BailoutDraft?> editBailout(
  BuildContext context, {
  required DiveRequest source,
  required DisplayUnits units,
  BailoutRequest? initial,
  CalculationResult? sourceResult,
}) => showPlannerDialog<BailoutDraft>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _BailoutEditor(
    source: source,
    units: units,
    initial: initial,
    sourceResult: sourceResult,
  ),
);

class _GasDraft {
  _GasDraft(
    this.original,
    DisplayUnits units, {
    this.originalDepth = 0,
    this.minimumStopMin,
    this.lost = false,
  }) : oxygen = TextEditingController(text: number(original.oxygen * 100)),
       helium = TextEditingController(text: number(original.helium * 100)),
       depth = TextEditingController(text: depthText(originalDepth, units)),
       minimum = TextEditingController(
         text: minimumStopMin == null ? '' : number(minimumStopMin),
       );
  final Gas original;
  final double originalDepth;
  final double? minimumStopMin;
  final TextEditingController oxygen, helium, depth, minimum;
  bool lost;
  Gas gas() => Gas(
    oxygen: oxygen.text == number(original.oxygen * 100)
        ? original.oxygen
        : _parse(oxygen.text)! / 100,
    helium: helium.text == number(original.helium * 100)
        ? original.helium
        : _parse(helium.text)! / 100,
  );
  GasSwitch toSwitch(DisplayUnits units) => GasSwitch(
    depthMetres: depth.text == depthText(originalDepth, units)
        ? originalDepth
        : units == DisplayUnits.metric
        ? _parse(depth.text)!
        : Units.feetToMetres(_parse(depth.text)!),
    breathing: BreathingGas.oc(gas()),
    lost: lost,
    minimumStopMin: minimum.text.trim().isEmpty ? null : _parse(minimum.text),
  );
  void dispose() {
    for (final c in [oxygen, helium, depth, minimum]) {
      c.dispose();
    }
  }
}

double? _parse(String? value) =>
    double.tryParse((value ?? '').replaceAll(',', '.'));

class _BailoutEditor extends StatefulWidget {
  const _BailoutEditor({
    required this.source,
    required this.units,
    this.initial,
    this.sourceResult,
  });
  final DiveRequest source;
  final DisplayUnits units;
  final BailoutRequest? initial;
  final CalculationResult? sourceResult;
  @override
  State<_BailoutEditor> createState() => _BailoutEditorState();
}

class _BailoutEditorState extends State<_BailoutEditor> {
  final form = GlobalKey<FormState>();
  late final runtime = TextEditingController(
    text: number(
      widget.initial?.runtimeMin ??
          widget.source.levels.fold(
            0.0,
            (sum, level) => sum + level.durationMin,
          ),
    ),
  );
  late final first = _GasDraft(
    widget.initial?.initialOcGas ?? widget.source.levels.first.breathing.gas,
    widget.units,
  );
  late final switches = [
    for (final s in widget.initial?.switches ?? <GasSwitch>[])
      _GasDraft(
        s.breathing.gas,
        widget.units,
        originalDepth: s.depthMetres,
        minimumStopMin: s.minimumStopMin,
        lost: s.lost,
      ),
  ];
  bool dirty = false;
  String? error;

  String? nonnegative(String? text) {
    final value = _parse(text);
    return value == null || !value.isFinite || value < 0
        ? 'Введите конечное число не меньше нуля'
        : null;
  }

  Widget field(
    String label,
    TextEditingController controller,
    String key, {
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validate ?? nonnegative,
      onChanged: (_) => dirty = true,
      onFieldSubmitted: (_) => save(),
    ),
  );
  List<Widget> gasFields(_GasDraft gas, String key) => [
    field(
      'Кислород O₂, %',
      gas.oxygen,
      '$key-o2',
      validate: (text) {
        final invalid = nonnegative(text);
        if (invalid != null) return invalid;
        return _parse(text)! <= 0 || _parse(text)! > 100
            ? 'Кислород должен быть больше 0 и не больше 100 %'
            : null;
      },
    ),
    field(
      'Гелий He, %',
      gas.helium,
      '$key-he',
      validate: (text) {
        final invalid = nonnegative(text);
        if (invalid != null) return invalid;
        return _parse(text)! + (_parse(gas.oxygen.text) ?? 0) > 100
            ? 'Сумма O₂ и He не должна превышать 100 %'
            : null;
      },
    ),
  ];

  void save() {
    if (!validatePlannerForm(form)) return;
    try {
      Navigator.pop(
        context,
        BailoutDraft(
          _parse(runtime.text)!,
          first.gas(),
          List.unmodifiable(switches.map((s) => s.toSwitch(widget.units))),
        ),
      );
    } on CalculationFailure catch (_) {
      setState(() => error = 'Проверьте состав и глубины газов.');
    }
  }

  Future<void> cancel() async {
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final decision = await showPlannerDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сохранить изменения bailout?'),
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

  Future<void> remove(_GasDraft gas) async {
    final confirmed = await showPlannerDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить газ bailout?'),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отменить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      setState(() {
        switches.remove(gas);
        dirty = true;
      });
      // Disposing after the next frame lets the removed fields detach first.
      WidgetsBinding.instance.addPostFrameCallback((_) => gas.dispose());
    }
  }

  @override
  void dispose() {
    runtime.dispose();
    first.dispose();
    for (final s in switches) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PopScope<BailoutDraft>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) cancel();
      },
      child: Dialog(
        insetPadding: EdgeInsets.all(size.width < 600 ? 8 : 24),
        child: SizedBox(
          width: 560,
          height: math.min(760, size.height - 48),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Bailout · CCR → OC',
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
                          const Text(
                            'Исходный CCR сохраняется. Время перехода отсчитывается от начала подводного профиля.',
                          ),
                          const SizedBox(height: 16),
                          field(
                            'Момент перехода, мин',
                            runtime,
                            'bailout-time',
                            validate: (text) {
                              final invalid = nonnegative(text);
                              if (invalid != null) return invalid;
                              final point = _parse(text)!;
                              if (point <= 0) {
                                return 'Время перехода должно быть больше нуля';
                              }
                              final result = widget.sourceResult;
                              if (result != null) {
                                if (point >= result.runtimeMin) {
                                  return 'Выберите момент до выхода на поверхность';
                                }
                                if (result.segments
                                        .firstWhere((s) => s.endMin > point)
                                        .physical
                                        .breathing
                                        .mode !=
                                    BreathingMode.ccr) {
                                  return 'В выбранный момент должен использоваться CCR';
                                }
                              }
                              return null;
                            },
                          ),
                          Text(
                            'Первый газ OC',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ...gasFields(first, 'bailout'),
                          Text(
                            'Декомпрессионные газы OC',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (switches.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Без декогазов: весь подъём на первом газе OC.',
                              ),
                            ),
                          for (var i = 0; i < switches.length; i++)
                            Card(
                              key: ObjectKey(switches[i]),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Газ ${i + 1} · OC',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    field(
                                      'Глубина переключения, ${depthUnit(widget.units)}',
                                      switches[i].depth,
                                      'bailout-switch-$i-depth',
                                    ),
                                    ...gasFields(
                                      switches[i],
                                      'bailout-switch-$i',
                                    ),
                                    field(
                                      'Минимум остановки, мин (необязательно)',
                                      switches[i].minimum,
                                      'bailout-switch-$i-minimum',
                                      validate: (text) {
                                        if ((text ?? '').trim().isEmpty) {
                                          return null;
                                        }
                                        final invalid = nonnegative(text);
                                        return invalid ??
                                            (_parse(text)! <= 0
                                                ? 'Минимум должен быть больше нуля'
                                                : null);
                                      },
                                    ),
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Газ потерян'),
                                      value: switches[i].lost,
                                      onChanged: (value) => setState(() {
                                        switches[i].lost = value!;
                                        dirty = true;
                                      }),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => remove(switches[i]),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Удалить газ'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            key: const Key('bailout-add-gas'),
                            onPressed: () => setState(() {
                              switches.add(
                                _GasDraft(Gas(oxygen: .21), widget.units),
                              );
                              dirty = true;
                            }),
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить газ OC'),
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
                          const SizedBox(height: 16),
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
                        onPressed: cancel,
                        child: const Text('Отменить'),
                      ),
                      FilledButton(
                        key: const Key('bailout-save'),
                        onPressed: save,
                        child: const Text('Сохранить bailout'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
