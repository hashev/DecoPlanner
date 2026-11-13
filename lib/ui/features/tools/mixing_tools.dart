import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../plan/gas_usage_view.dart';
import '../plan/level_editor.dart';
import '../plan/planner_view_model.dart';
import 'mixing_view_model.dart';
import '../../../data/models/planner_document.dart';

String _composition(Gas gas) =>
    'O₂ ${(gas.oxygen * 100).toStringAsFixed(3)}%, He ${(gas.helium * 100).toStringAsFixed(3)}%, N₂ ${(gas.nitrogen * 100).toStringAsFixed(3)}%';

class MixingToolView extends StatefulWidget {
  const MixingToolView({super.key, required this.model, this.tanks = const []});
  final PlannerViewModel model;
  final List<TankPreset> tanks;
  @override
  State<MixingToolView> createState() => _MixingToolViewState();
}

class _MixingToolViewState extends State<MixingToolView> {
  final form = GlobalKey<FormState>();
  final mixer = MixingViewModel();
  final fields = <String, TextEditingController>{};
  late DisplayUnits inputUnits;
  MixingMethod method = MixingMethod.partialPressure;
  bool realGas = false;
  FillOrder order = FillOrder.oxygenFirst;
  ContinuousVariant variant = ContinuousVariant.singleStream;
  ContinuousPath path = ContinuousPath.oxygenHeliumThenNitrox;
  String? loadedDraft, validationError;
  PlannerViewModel get model => widget.model;
  static const prefix = 'mixing:';
  String get signature => jsonEncode({
    for (final e in model.toolDraft.entries)
      if (e.key.startsWith(prefix)) e.key: e.value,
  });
  static const defaults = {
    'initialOxygen': 21.0,
    'initialHelium': 0.0,
    'initialPressure': 50.0,
    'targetOxygen': 32.0,
    'targetHelium': 0.0,
    'targetPressure': 200.0,
    'topUpOxygen': 21.0,
    'topUpHelium': 0.0,
    'temperature': 294.0,
    'oxygenLimit': 100.0,
    'heliumLimit': 100.0,
  };
  T choice<T extends Enum>(String key, List<T> values, T fallback) =>
      values
          .where((e) => e.name == model.toolDraft['$prefix$key'])
          .firstOrNull ??
      fallback;
  @override
  void initState() {
    super.initState();
    load();
    model.addListener(changed);
  }

  void load() {
    inputUnits = switch (model.toolDraft['${prefix}units']) {
      'metric' => DisplayUnits.metric,
      'imperial' => DisplayUnits.imperial,
      _ => model.units,
    };
    method = choice(
      'method',
      MixingMethod.values,
      MixingMethod.partialPressure,
    );
    order = choice('order', FillOrder.values, FillOrder.oxygenFirst);
    variant = choice(
      'variant',
      ContinuousVariant.values,
      ContinuousVariant.singleStream,
    );
    path = choice(
      'path',
      ContinuousPath.values,
      ContinuousPath.oxygenHeliumThenNitrox,
    );
    realGas = model.toolDraft['${prefix}realGas'] == 'true';
    for (final e in defaults.entries) {
      fields[e.key] = TextEditingController(
        text:
            model.toolDraft['$prefix${e.key}'] ??
            number(
              e.key.endsWith('Pressure') && inputUnits == DisplayUnits.imperial
                  ? Units.barToPsi(e.value)
                  : e.value,
            ),
      );
    }
    syncUnits();
    loadedDraft = signature;
  }

  void persist() {
    for (final e in fields.entries) {
      model.toolDraft['$prefix${e.key}'] = e.value.text;
    }
    model.toolDraft['${prefix}units'] = inputUnits.name;
    model.toolDraft['${prefix}method'] = method.name;
    model.toolDraft['${prefix}order'] = order.name;
    model.toolDraft['${prefix}variant'] = variant.name;
    model.toolDraft['${prefix}path'] = path.name;
    model.toolDraft['${prefix}realGas'] = realGas.toString();
    loadedDraft = signature;
  }

  void edited() {
    validationError = null;
    persist();
    mixer.invalidate();
    model.setToolDraft('${prefix}units', inputUnits.name);
  }

  void syncUnits() {
    if (inputUnits == model.units) return;
    final converted = <String, double>{};
    try {
      for (final key in fields.keys.where((k) => k.endsWith('Pressure'))) {
        final n = double.tryParse(fields[key]!.text.replaceAll(',', '.'));
        if (n == null || !n.isFinite || n < 0) return;
        converted[key] = inputUnits == DisplayUnits.metric
            ? Units.barToPsi(n)
            : Units.psiToBar(n);
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
    if (loadedDraft != signature) {
      for (final field in fields.values) {
        field.dispose();
      }
      fields.clear();
      mixer.invalidate();
      load();
    }
    syncUnits();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(changed);
    mixer.dispose();
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  double read(String key) =>
      double.parse(fields[key]!.text.replaceAll(',', '.'));
  double pressure(String key) =>
      inputUnits == DisplayUnits.metric ? read(key) : Units.psiToBar(read(key));
  Gas gas(String prefix) => Gas(
    oxygen: read('${prefix}Oxygen') / 100,
    helium: read('${prefix}Helium') / 100,
  );
  List<String> get activeFields => [
    'initialOxygen',
    'initialHelium',
    'initialPressure',
    'targetOxygen',
    'targetHelium',
    'targetPressure',
    'temperature',
    if (method == MixingMethod.partialPressure) ...[
      'topUpOxygen',
      'topUpHelium',
    ] else ...[
      'oxygenLimit',
      'heliumLimit',
    ],
  ];
  String label(String key) => switch (key) {
    'initialOxygen' => 'Исходный O₂, %',
    'initialHelium' => 'Исходный He, %',
    'targetOxygen' => 'Целевой O₂, %',
    'targetHelium' => 'Целевой He, %',
    'initialPressure' =>
      'Исходное давление, ${inputUnits == DisplayUnits.metric ? 'bar' : 'PSI'}',
    'targetPressure' =>
      'Целевое давление, ${inputUnits == DisplayUnits.metric ? 'bar' : 'PSI'}',
    'topUpOxygen' => 'Газ дозаправки O₂, %',
    'topUpHelium' => 'Газ дозаправки He, %',
    'temperature' => 'Температура заправки, K',
    'oxygenLimit' => 'Предел O₂ в потоке, %',
    _ => 'Предел He в потоке, %',
  };
  String? validate(String key, String? text) {
    final n = double.tryParse((text ?? '').replaceAll(',', '.'));
    if (n == null || !n.isFinite || n < 0) {
      return 'Введите конечное число не меньше нуля';
    }
    if ((key == 'temperature' || key == 'targetPressure') && n == 0) {
      return 'Значение должно быть больше нуля';
    }
    if (key.endsWith('Oxygen') ||
        key.endsWith('Helium') ||
        key.endsWith('Limit')) {
      if (n > 100) return 'Доля должна быть от0до100%';
      if (!key.endsWith('Limit')) {
        final other = double.tryParse(
          fields[key.endsWith('Oxygen')
                  ? key.replaceFirst('Oxygen', 'Helium')
                  : key.replaceFirst('Helium', 'Oxygen')]!
              .text
              .replaceAll(',', '.'),
        );
        if (other != null && other + n > 100) {
          return 'O₂ + He не должны превышать100%';
        }
      }
    }
    return null;
  }

  Future<void> calculate() async {
    if (!form.currentState!.validate()) {
      mixer.invalidate();
      setState(() => validationError = 'Исправьте отмеченные поля.');
      return;
    }
    try {
      final input = MixingInput(
        initialGas: gas('initial'),
        initialBar: pressure('initialPressure'),
        targetGas: gas('target'),
        targetBar: pressure('targetPressure'),
        topUpGas: method == MixingMethod.partialPressure
            ? gas('topUp')
            : Gas(oxygen: .21),
        method: method,
        realGas: realGas,
        temperatureKelvin: read('temperature'),
        order: order,
        variant: variant,
        path: path,
        maximumOxygenFraction: method == MixingMethod.continuous
            ? read('oxygenLimit') / 100
            : 1,
        maximumHeliumFraction: method == MixingMethod.continuous
            ? read('heliumLimit') / 100
            : 1,
      );
      await mixer.calculate(input);
    } on CalculationFailure {
      mixer.invalidate();
      if (mounted) {
        setState(
          () => validationError =
              'Значения вне численной области. Проверьте ввод.',
        );
      }
    }
  }

  Widget option<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (value) {
        change(value as T);
        edited();
      },
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: mixer,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Смешивание газов')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                option('Способ', method, {
                  MixingMethod.partialPressure: 'Парциальные давления',
                  MixingMethod.continuous: 'Непрерывное смешивание',
                }, (value) => method = value),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Реальный газ (van der Waals)'),
                  value: realGas,
                  onChanged: (value) {
                    realGas = value;
                    edited();
                  },
                ),
                if (method == MixingMethod.partialPressure)
                  option('Порядок добавления', order, {
                    FillOrder.oxygenFirst: 'Сначала O₂',
                    FillOrder.heliumFirst: 'Сначала He',
                  }, (value) => order = value),
                if (method == MixingMethod.continuous) ...[
                  option('Вариант', variant, {
                    ContinuousVariant.singleStream: 'Один поток',
                    ContinuousVariant.twoStreams: 'Два потока',
                  }, (value) => variant = value),
                  if (variant == ContinuousVariant.twoStreams)
                    option('Путь потоков', path, {
                      ContinuousPath.oxygenHeliumThenNitrox: 'O₂/He → Nitrox',
                      ContinuousPath.nitroxThenHeliair: 'Nitrox → Heliair',
                    }, (value) => path = value),
                  const Text(
                    'Пределы относятся к составу каждого непрерывного потока. Отдельная добавка чистого O₂/He может предшествовать потоку.',
                  ),
                ],
                if (inputUnits != model.units)
                  const Text(
                    'Единицы полей сохранены: исправьте неверное давление для преобразования.',
                  ),
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
                            decoration: InputDecoration(labelText: label(key)),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (text) => validate(key, text),
                            onChanged: (_) => edited(),
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: mixer.status == MixingStatus.calculating
                      ? null
                      : calculate,
                  child: const Text('Рассчитать рецепт'),
                ),
                if (mixer.status == MixingStatus.calculating)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Расчёт смешивания',
                    ),
                  ),
                if (validationError != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      validationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (mixer.failure != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      mixer.failure!.code ==
                              CalculationFailureCode.impossibleMixture
                          ? 'Невозможно получить смесь доступными газами и пределами потоков. Измените условия.'
                          : 'Расчёт не завершён в численной области модели. Измените условия и повторите.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (mixer.result != null && !mixer.current)
                  const Text(
                    'Предыдущий рецепт неактуален. Инструкция скрыта до успешного пересчёта.',
                  ),
                if (mixer.current) ...[
                  const SizedBox(height: 24),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Актуальный рецепт · revision ${mixer.recipeRevision}',
                    ),
                  ),
                  Text(
                    '${realGas ? 'van der Waals' : 'Идеальный газ'} · ${mixer.result!.input.temperatureKelvin} K',
                  ),
                  if (mixer.result!.drainedBar > 1e-9)
                    Text(
                      'Стравить ${usagePressure(mixer.result!.drainedBar, model.units)}; оставить ${usagePressure(mixer.result!.retainedBar, model.units)}',
                    ),
                  if (mixer.result!.partial != null)
                    for (final step in mixer.result!.partial!.steps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Добавить ${switch (step.component) {
                            FillComponent.oxygen => 'O₂',
                            FillComponent.helium => 'He',
                            FillComponent.topUp => 'газ дозаправки',
                          }}',
                        ),
                        subtitle: Text(
                          'Довести до ${usagePressure(step.pressureAfterBar, model.units)} · смесь ${_composition(step.resultingGas)}',
                        ),
                      ),
                  if (mixer.result!.continuous != null)
                    for (final step in mixer.result!.continuous!.steps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Добавить ${switch (step.kind) {
                            ContinuousStepKind.oxygen => 'O₂',
                            ContinuousStepKind.helium => 'He',
                            ContinuousStepKind.blend => 'поток',
                          }} ${_composition(step.feedGas)}',
                        ),
                        subtitle: Text(
                          'Довести до ${usagePressure(step.pressureAfterBar, model.units)} · доли источников: воздух ${(step.airFraction * 100).toStringAsFixed(3)}%, O₂ ${(step.oxygenFraction * 100).toStringAsFixed(3)}%, He ${(step.heliumFraction * 100).toStringAsFixed(3)}%',
                        ),
                      ),
                  if ((mixer.result!.partial?.steps.isEmpty ??
                      mixer.result!.continuous!.steps.isEmpty))
                    const Text(
                      'Добавлять газ не требуется: исходная смесь уже соответствует цели.',
                    ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => MixingCostView(
                          model: model,
                          mixer: mixer,
                          tanks: widget.tanks,
                        ),
                      ),
                    ),
                    child: const Text('Объём и стоимость'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MixingCostView extends StatefulWidget {
  const MixingCostView({
    super.key,
    required this.model,
    required this.mixer,
    this.tanks = const [],
  });
  final List<TankPreset> tanks;
  final PlannerViewModel model;
  final MixingViewModel mixer;
  @override
  State<MixingCostView> createState() => _MixingCostViewState();
}

class _MixingCostViewState extends State<MixingCostView> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  FillCost? cost;
  int? costRevision;
  bool dirty = false;
  String? error;
  bool get current =>
      !dirty &&
      widget.mixer.current &&
      costRevision == widget.mixer.recipeRevision;
  static const defaults = {
    'water': 24.0,
    'oxygenPrice': .1,
    'heliumPrice': .7,
    'topUpFlat': 10.0,
  };
  @override
  void initState() {
    super.initState();
    for (final e in defaults.entries) {
      fields[e.key] = TextEditingController(
        text: widget.model.toolDraft['cost:${e.key}'] ?? number(e.value),
      );
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String label(String key) => switch (key) {
    'water' => 'Водяной объём баллона, L',
    'oxygenPrice' => 'Цена O₂ за L',
    'heliumPrice' => 'Цена He за L',
    _ => 'Дозаправка, фиксированная плата',
  };
  void calculate() {
    if (!widget.mixer.current || !form.currentState!.validate()) return;
    try {
      double value(String key) =>
          double.parse(fields[key]!.text.replaceAll(',', '.'));
      final result = fillCost(
        recipe: widget.mixer.result!.costRecipe,
        waterLitres: value('water'),
        prices: FillPrices(
          oxygenPerLitre: value('oxygenPrice'),
          heliumPerLitre: value('heliumPrice'),
          topUpFlat: value('topUpFlat'),
        ),
        basis: ReferenceGasVolume(
          temperatureKelvin: 294,
          pressureBar: Units.barPerAta,
        ),
      );
      setState(() {
        cost = result;
        costRevision = widget.mixer.recipeRevision;
        dirty = false;
        error = null;
      });
    } on CalculationFailure {
      setState(
        () =>
            error = 'Стоимость вне численной области. Проверьте объём и цены.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.model, widget.mixer]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Объём и стоимость')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Источник: рецепт revision ${widget.mixer.recipeRevision} · ${widget.mixer.result!.input.realGas ? 'van der Waals' : 'идеальный газ'}',
                ),
                Text(
                  'Исходная смесь ${_composition(widget.mixer.result!.input.initialGas)} · ${usagePressure(widget.mixer.result!.input.initialBar, widget.model.units)}; цель ${_composition(widget.mixer.result!.input.targetGas)} · ${usagePressure(widget.mixer.result!.input.targetBar, widget.model.units)}',
                ),
                const Text(
                  'Свободный объём при294K и1ATA. Цены явно за L, общая денежная единица задаётся вашими ценами; конверсии валют нет. Дозаправка оплачивается один раз при наличии добавки.',
                ),
                if (!widget.mixer.current)
                  const Text(
                    'Рецепт изменён. Вернитесь к смешиванию и пересчитайте.',
                  ),
                if (widget.tanks.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Баллон из справочника',
                    ),
                    items: [
                      for (final tank in widget.tanks)
                        DropdownMenuItem(
                          value: tank.id,
                          child: Text('${tank.name} · ${tank.waterLitres} L'),
                        ),
                    ],
                    onChanged: (value) {
                      final tank = widget.tanks.firstWhere(
                        (tank) => tank.id == value,
                      );
                      fields['water']!.text = number(tank.waterLitres);
                      dirty = true;
                      widget.model.setToolDraft(
                        'cost:water',
                        fields['water']!.text,
                      );
                    },
                  ),
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
                                      (key == 'water' && n == 0)
                                  ? 'Введите допустимое конечное число'
                                  : null;
                            },
                            onChanged: (text) {
                              dirty = true;
                              error = null;
                              widget.model.setToolDraft('cost:$key', text);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: widget.mixer.current ? calculate : null,
                  child: const Text('Пересчитать стоимость'),
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
                if (cost != null) ...[
                  Text(
                    current
                        ? 'Стоимость актуальна'
                        : 'Предыдущая стоимость · пересчитайте',
                  ),
                  for (final line in cost!.lines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(switch (line.component) {
                        FillComponent.oxygen => 'O₂',
                        FillComponent.helium => 'He',
                        FillComponent.topUp => 'Дозаправка',
                      }),
                      subtitle: Text(
                        '${usageVolume(line.referenceLitres, widget.model.units)} · ${line.cost.toStringAsFixed(2)}',
                      ),
                    ),
                  Text('Итого: ${cost!.total.toStringAsFixed(2)}'),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
