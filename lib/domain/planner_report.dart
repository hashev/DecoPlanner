import 'package:deco_core/deco_core.dart';
import '../data/services/range_worker.dart';

final class ReportTable {
  ReportTable(this.title, List<String> columns, List<List<String>> rows)
    : columns = List.unmodifiable(columns),
      rows = List.unmodifiable(rows.map((r) => List<String>.unmodifiable(r)));
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
}

/// A frozen presentation snapshot. It contains no editable planning state.
final class PlannerReport {
  PlannerReport(this.title, List<String> conditions, List<ReportTable> tables)
    : conditions = List.unmodifiable(conditions),
      tables = List.unmodifiable(tables);
  final String title;
  final List<String> conditions;
  final List<ReportTable> tables;

  static String number(double v) => v.toStringAsFixed(3);
  static String depth(double v, DisplayUnits u) =>
      '${number(u == DisplayUnits.metric ? v : Units.metresToFeet(v))} ${u == DisplayUnits.metric ? 'м' : 'ft'}';
  static String pressure(double v, DisplayUnits u) =>
      '${number(u == DisplayUnits.metric ? v : Units.barToPsi(v))} ${u == DisplayUnits.metric ? 'bar' : 'PSI'}';
  static String gas(BreathingGas b, DisplayUnits u) =>
      '${b.mode.name} O2 ${number(b.gas.oxygen * 100)}% / He ${number(b.gas.helium * 100)}%${b.setpointBar == null ? '' : ' SP ${pressure(b.setpointBar!, u)}'}';
  static List<String> settings(CalculationSettings s, DisplayUnits u) => [
    'Модель ${s.model.name} · $calculationModelVersion',
    s.model == DecompressionModel.vpmB
        ? 'Консерватизм VPM ${s.vpmConservatism}'
        : 'GF ${number(s.gradientFactors.low * 100)}/${number(s.gradientFactors.high * 100)}',
    'Единицы: ${u == DisplayUnits.metric ? 'метрические' : 'imperial'} · времена: минуты',
    'Скорость спуска ${depth(s.descentMetresPerMin, u)}/мин · подъёма ${depth(s.ascentMetresPerMin, u)}/мин',
    'Минимальная остановка ${number(s.minimumStopMin)} мин · время уровня ${s.includeDescentInLevelTime ? 'включает' : 'не включает'} спуск',
    'Сетка остановок ${depth(s.stopGrid.stepMetres, u)} · последняя ${depth(s.stopGrid.lastStopMetres, u)}',
    'Поверхность ${pressure(s.pressure.surfaceBar, u)} · водяной пар ${pressure(s.pressure.waterVapourBar, u)} · градиент ${u == DisplayUnits.metric ? number(s.pressure.barPerMetre) : number(Units.barToPsi(s.pressure.barPerMetre * Units.metresPerFoot))} ${u == DisplayUnits.metric ? 'bar/m' : 'PSI/ft'}',
    'Высота ${depth(s.altitude.diveAltitudeMetres, u)} · коррекция ${s.altitude.enabled ? 'включена' : 'выключена'}',
    if (s.altitude.enabled)
      'Акклиматизация ${s.altitude.acclimatized ? 'да' : 'нет'} · начальная высота ${depth(s.altitude.initialAltitudeMetres, u)} · переезд ${number(s.altitude.travelMin)} мин · ожидание ${number(s.altitude.waitMin)} мин · море ${pressure(s.altitude.seaLevelBar, u)}',
    'Низкий SP ${pressure(s.lowSetpointBar, u)}',
    'RMV дно/деко ${number(s.bottomRmvLitresPerMin)}/${number(s.decoRmvLitresPerMin)} L/min · OCR ${number(s.bottomOxygenLitresPerMin)}/${number(s.decoOxygenLitresPerMin)} L/min',
    'Один дайвер · без резервов',
  ];

  factory PlannerReport.dive({
    required CalculationResult result,
    required DiveRequest request,
    required DisplayUnits units,
    BailoutRequest? bailout,
  }) {
    final oxygen = result.finalState.oxygen;
    return PlannerReport(
      'План погружения ${result.diveId}',
      [
        ...settings(request.settings, units),
        'Интервал поверхности ${number(request.surfaceIntervalMin)} мин',
        'Давление поверхности ${pressure(result.pressure.surfaceBar, units)}',
        if (bailout != null)
          'Bailout ${bailout.id}: на ${number(bailout.runtimeMin)} мин · ${gas(BreathingGas.oc(bailout.initialOcGas), units)}',
        'Runtime ${number(result.runtimeMin)} мин · подъём ${number(result.ascentMin)} мин · декомпрессия ${number(result.decompressionMin)} мин',
        'Первая остановка ${depth(result.firstStopMetres, units)}',
        'CNS ${oxygen.cnsFraction == null ? 'недоступен: ppO2 вне области 1,6 ATA (${oxygen.cnsUnavailableReason?.code.name})' : '${number(oxygen.cnsFraction! * 100)}%'} · OTU ${number(oxygen.otu)}',
      ],
      [
        ReportTable(
          'Введённые уровни',
          ['Глубина', 'Время, мин', 'Газ'],
          [
            for (final l in request.levels)
              [
                depth(l.depthMetres, units),
                number(l.durationMin),
                gas(l.breathing, units),
              ],
          ],
        ),
        ReportTable(
          'Переключения',
          ['Глубина', 'Газ', 'Lost / min stop'],
          [
            for (final s in request.switches)
              [
                depth(s.depthMetres, units),
                gas(s.breathing, units),
                '${s.lost} / ${s.minimumStopMin ?? '-'}',
              ],
          ],
        ),
        if (bailout != null)
          ReportTable(
            'Переключения bailout',
            ['Глубина', 'Газ', 'Lost / min stop'],
            [
              for (final s in bailout.switches)
                [
                  depth(s.depthMetres, units),
                  gas(s.breathing, units),
                  '${s.lost} / ${s.minimumStopMin ?? '-'}',
                ],
            ],
          ),
        ReportTable(
          'Начальные ткани перед погружением',
          ['Ткань', 'N2, bar', 'He, bar'],
          [
            for (var i = 0; i < 16; i++)
              [
                '${i + 1}',
                number(result.initialState.tissues.nitrogenBar[i]),
                number(result.initialState.tissues.heliumBar[i]),
              ],
          ],
        ),
        ReportTable(
          'Физические сегменты',
          ['Фаза', 'От / до', 'Время / конец, мин', 'Газ'],
          [
            for (final s in result.segments)
              [
                s.phase.name,
                '${depth(s.physical.startDepthMetres, units)} / ${depth(s.physical.endDepthMetres, units)}',
                '${number(s.physical.durationMin)} / ${number(s.endMin)}',
                gas(s.physical.breathing, units),
              ],
          ],
        ),
      ],
    );
  }

  factory PlannerReport.range({
    required List<RangeSummary> cells,
    required RangeAxis depths,
    required RangeAxis durations,
    required List<RangeVariant> variants,
    required DisplayUnits units,
    required String status,
    required int total,
  }) {
    if (cells.isEmpty) throw ArgumentError('No range cells.');
    return PlannerReport(
      'Таблица диапазонов',
      [
        ...settings(cells.first.request.settings, units),
        'Статус: $status · рассчитано ${cells.length} / $total',
        'Интервал поверхности ${number(cells.first.request.surfaceIntervalMin)} мин',
        if (cells.first.bailout case final b?)
          'Bailout ${b.id}: на ${number(b.runtimeMin)} мин · ${gas(BreathingGas.oc(b.initialOcGas), units)}',
        'Глубина ${depth(depths.first, units)} - ${depth(depths.last, units)} · шаг ${depth(depths.step, units)}',
        'Время ${number(durations.first)} - ${number(durations.last)} мин · шаг ${number(durations.step)} мин',
        'Варианты: ${variants.map((v) => v.name).join(', ')}',
        'Изменяется последний введённый уровень. Ошибки не заменяются нулём.',
      ],
      [
        ReportTable(
          'Общие уровни (последний заменяется осями)',
          ['Глубина', 'Время, мин', 'Газ'],
          [
            for (var i = 0; i < cells.first.request.levels.length; i++)
              [
                i == cells.first.request.levels.length - 1
                    ? 'По оси'
                    : depth(cells.first.request.levels[i].depthMetres, units),
                i == cells.first.request.levels.length - 1
                    ? 'По оси'
                    : number(cells.first.request.levels[i].durationMin),
                gas(cells.first.request.levels[i].breathing, units),
              ],
          ],
        ),
        ReportTable(
          'Переключения первого варианта',
          ['Глубина', 'Газ', 'Lost / min stop'],
          [
            for (final s in cells.first.request.switches)
              [
                depth(s.depthMetres, units),
                gas(s.breathing, units),
                '${s.lost} / ${s.minimumStopMin ?? '-'}',
              ],
          ],
        ),
        ReportTable(
          'Сценарии',
          [
            'Глубина / время',
            'Вариант',
            'Runtime / подъём / деко, мин',
            'Первая остановка / ошибка',
          ],
          [
            for (final c in cells)
              [
                '${depth(c.depthMetres, units)} / ${number(c.durationMin)}',
                c.variant.name,
                c.failure == null
                    ? '${number(c.runtimeMin!)} / ${number(c.ascentMin!)} / ${number(c.decompressionMin!)}'
                    : '-',
                c.failure == null
                    ? depth(c.firstStopMetres!, units)
                    : '${c.failure!.code.name}: ${c.failure!.message}',
              ],
          ],
        ),
      ],
    );
  }
}
