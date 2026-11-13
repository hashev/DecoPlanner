import '../../core/planner_dialog.dart';
import '../../core/form_validation.dart';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import 'level_editor.dart';

enum SettingsAction { apply, saveDefaults }

final class SettingsEdit {
  const SettingsEdit(this.settings, this.action, this.ratioStops);
  final CalculationSettings settings;
  final SettingsAction action;
  final int ratioStops;
}

Future<SettingsEdit?> editCalculationSettings(
  BuildContext context, {
  required CalculationSettings initial,
  required DisplayUnits units,
  bool allowDefaults = false,
  int ratioStops = 5,
}) => showPlannerDialog<SettingsEdit>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _SettingsEditor(
    initial: initial,
    units: units,
    allowDefaults: allowDefaults,
    ratioStops: ratioStops,
  ),
);

class _SettingsEditor extends StatefulWidget {
  const _SettingsEditor({
    required this.initial,
    required this.units,
    required this.allowDefaults,
    required this.ratioStops,
  });
  final CalculationSettings initial;
  final DisplayUnits units;
  final bool allowDefaults;
  final int ratioStops;
  @override
  State<_SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<_SettingsEditor> {
  final form = GlobalKey<FormState>();
  late DecompressionModel model = widget.initial.model;
  late bool includeDescent = widget.initial.includeDescentInLevelTime;
  late bool altitude = widget.initial.altitude.enabled,
      acclimatized = widget.initial.altitude.acclimatized;
  late int conservatism = widget.initial.vpmConservatism;
  late bool criticalVolume = widget.initial.vpm.criticalVolumeEnabled;
  String? error;
  late final originals = <String, double>{
    'gfLow': widget.initial.gradientFactors.low * 100,
    'gfHigh': widget.initial.gradientFactors.high * 100,
    'descentMetresPerMin': _depth(widget.initial.descentMetresPerMin),
    'ascentMetresPerMin': _depth(widget.initial.ascentMetresPerMin),
    'stepMetres': _depth(widget.initial.stopGrid.stepMetres),
    'lastStopMetres': _depth(widget.initial.stopGrid.lastStopMetres),
    'minimumStopMin': widget.initial.minimumStopMin,
    'ratioStops': widget.ratioStops.toDouble(),
    'lowSetpointBar': Units.barToAta(widget.initial.lowSetpointBar),
    'bottomRmvLitresPerMin': _flow(widget.initial.bottomRmvLitresPerMin),
    'decoRmvLitresPerMin': _flow(widget.initial.decoRmvLitresPerMin),
    'bottomOxygenLitresPerMin': _flow(widget.initial.bottomOxygenLitresPerMin),
    'decoOxygenLitresPerMin': _flow(widget.initial.decoOxygenLitresPerMin),
    'diveAltitudeMetres': _depth(widget.initial.altitude.diveAltitudeMetres),
    'initialAltitudeMetres': _depth(
      widget.initial.altitude.initialAltitudeMetres,
    ),
    'travelMin': widget.initial.altitude.travelMin,
    'waitMin': widget.initial.altitude.waitMin,
  };
  late final fields = originals.map(
    (key, value) => MapEntry(key, TextEditingController(text: number(value))),
  );
  double _depth(double value) =>
      widget.units == DisplayUnits.metric ? value : Units.metresToFeet(value);
  double _flow(double value) => widget.units == DisplayUnits.metric
      ? value
      : Units.litresToCubicFeet(value);
  double _metres(double value) =>
      widget.units == DisplayUnits.metric ? value : Units.feetToMetres(value);
  double _litres(double value) => widget.units == DisplayUnits.metric
      ? value
      : Units.cubicFeetToLitres(value);
  double? parse(String? text) =>
      double.tryParse((text ?? '').replaceAll(',', '.'));
  bool unchanged(String key) => fields[key]!.text == number(originals[key]!);
  double input(String key) => parse(fields[key]!.text)!;
  double physical(
    String key,
    double original,
    double Function(double) convert,
  ) => unchanged(key) ? original : convert(input(key));
  Widget field(
    String key,
    String label, {
    bool zero = false,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('settings-$key'),
      controller: fields[key],
      enabled: enabled,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (text) {
        if (!enabled) return null;
        final value = parse(text);
        return value == null ||
                !value.isFinite ||
                (zero ? value < 0 : value <= 0)
            ? (zero
                  ? 'Введите конечное число не меньше нуля'
                  : 'Введите положительное конечное число')
            : null;
      },
    ),
  );
  void save(SettingsAction action) {
    if (!validatePlannerForm(form)) return;
    final old = widget.initial;
    try {
      final json = {
        ...old.toJson(),
        'model': model.name,
        'waterVapourBar': model == old.model
            ? old.pressure.waterVapourBar
            : model == DecompressionModel.vpmB
            ? .0493
            : .0627,
        'gfLow': model == DecompressionModel.vpmB
            ? old.gradientFactors.low
            : physical('gfLow', old.gradientFactors.low, (v) => v / 100),
        'gfHigh': model == DecompressionModel.vpmB
            ? old.gradientFactors.high
            : physical('gfHigh', old.gradientFactors.high, (v) => v / 100),
        'includeDescentInLevelTime': includeDescent,
        'vpmConservatism': conservatism,
        'vpm': {...old.vpm.toJson(), 'criticalVolumeEnabled': criticalVolume},
        'minimumStopMin': input('minimumStopMin'),
        'lowSetpointBar': physical(
          'lowSetpointBar',
          old.lowSetpointBar,
          Units.ataToBar,
        ),
        'altitude': {
          ...old.altitude.toJson(),
          'enabled': altitude,
          'acclimatized': acclimatized,
          if (altitude)
            'diveAltitudeMetres': physical(
              'diveAltitudeMetres',
              old.altitude.diveAltitudeMetres,
              _metres,
            ),
          if (altitude && !acclimatized) ...{
            'initialAltitudeMetres': physical(
              'initialAltitudeMetres',
              old.altitude.initialAltitudeMetres,
              _metres,
            ),
            'travelMin': input('travelMin'),
            'waitMin': input('waitMin'),
          },
        },
      };
      for (final key in [
        'descentMetresPerMin',
        'ascentMetresPerMin',
        'stepMetres',
        'lastStopMetres',
      ]) {
        json[key] = physical(
          key,
          (old.toJson()[key] as num).toDouble(),
          _metres,
        );
      }
      for (final key in [
        'bottomRmvLitresPerMin',
        'decoRmvLitresPerMin',
        'bottomOxygenLitresPerMin',
        'decoOxygenLitresPerMin',
      ]) {
        json[key] = physical(
          key,
          (old.toJson()[key] as num).toDouble(),
          _litres,
        );
      }
      Navigator.pop(
        context,
        SettingsEdit(
          CalculationSettings.fromJson(json),
          action,
          int.parse(fields['ratioStops']!.text),
        ),
      );
    } on CalculationFailure {
      setState(
        () => error =
            'Проверьте: 0 < GF Low ≤ GF High ≤ 100, сетку остановок и параметры высоты.',
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

  @override
  Widget build(BuildContext context) {
    final depth = depthUnit(widget.units),
        flow = widget.units == DisplayUnits.metric ? 'L/мин' : 'cu ft/мин';
    return AlertDialog(
      scrollable: true,
      title: const Text('Расчётные настройки'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null)
                Semantics(liveRegion: true, child: Text(error!)),
              DropdownButtonFormField<DecompressionModel>(
                initialValue: model,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Модель'),
                items: [
                  for (final value in DecompressionModel.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(switch (value) {
                        DecompressionModel.buhlmannB => 'Bühlmann B',
                        DecompressionModel.buhlmannC => 'Bühlmann C',
                        DecompressionModel.vpmB => 'VPM-B',
                      }),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => model = value);
                },
              ),
              const SizedBox(height: 16),
              if (model == DecompressionModel.vpmB) ...[
                DropdownButtonFormField<int>(
                  initialValue: conservatism,
                  decoration: const InputDecoration(
                    labelText: 'Консерватизм VPM',
                  ),
                  items: [
                    for (var i = 0; i <= 4; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => conservatism = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Критический объём VPM'),
                  value: criticalVolume,
                  onChanged: (v) => setState(() => criticalVolume = v),
                ),
                const Text('GF не применяется к VPM-B.'),
              ] else ...[
                field('gfLow', 'GF Low, %'),
                field('gfHigh', 'GF High, %'),
              ],
              const SizedBox(height: 16),
              field('descentMetresPerMin', 'Скорость спуска, $depth/мин'),
              field('ascentMetresPerMin', 'Скорость подъёма, $depth/мин'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Спуск входит во время уровня'),
                value: includeDescent,
                onChanged: (v) => setState(() => includeDescent = v),
              ),
              field('stepMetres', 'Шаг остановок, $depth'),
              field('lastStopMetres', 'Последняя остановка, $depth'),
              field('minimumStopMin', 'Минимальная остановка, мин'),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  key: const Key('settings-ratioStops'),
                  controller: fields['ratioStops'],
                  decoration: const InputDecoration(
                    labelText: 'Остановок в группе ratios',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (raw) {
                    final value = int.tryParse(raw ?? '');
                    return value == null || value <= 0 || value > 10000
                        ? 'Введите целое число от 1 до 10000'
                        : null;
                  },
                ),
              ),
              field('lowSetpointBar', 'Низкий setpoint CCR, ATA'),
              field('bottomRmvLitresPerMin', 'RMV уровней, $flow', zero: true),
              field(
                'decoRmvLitresPerMin',
                'RMV подъёма и остановок, $flow',
                zero: true,
              ),
              field(
                'bottomOxygenLitresPerMin',
                'OCR уровней CCR, $flow',
                zero: true,
              ),
              field(
                'decoOxygenLitresPerMin',
                'OCR подъёма и остановок CCR, $flow',
                zero: true,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Планирование на высоте'),
                value: altitude,
                onChanged: (v) => setState(() => altitude = v),
              ),
              const Text(
                'Отключённые параметры высоты сохраняются и не участвуют в расчёте.',
              ),
              field(
                'diveAltitudeMetres',
                'Высота погружения, $depth',
                zero: true,
                enabled: altitude,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Акклиматизирован'),
                value: acclimatized,
                onChanged: altitude
                    ? (v) => setState(() => acclimatized = v)
                    : null,
              ),
              if (acclimatized)
                const Text(
                  'При акклиматизации параметры поездки не участвуют.',
                ),
              field(
                'initialAltitudeMetres',
                'Исходная высота, $depth',
                zero: true,
                enabled: altitude && !acclimatized,
              ),
              field(
                'travelMin',
                'Время подъезда, мин',
                enabled: altitude && !acclimatized,
              ),
              field(
                'waitMin',
                'Ожидание на высоте, мин',
                zero: true,
                enabled: altitude && !acclimatized,
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
        if (widget.allowDefaults)
          OutlinedButton(
            onPressed: () => save(SettingsAction.saveDefaults),
            child: const Text('Сохранить по умолчанию'),
          ),
        FilledButton(
          onPressed: () => save(SettingsAction.apply),
          child: const Text('Применить к погружению'),
        ),
      ],
    );
  }
}
