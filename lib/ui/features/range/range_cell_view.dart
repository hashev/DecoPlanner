import '../../../domain/planner_report.dart';
import '../export/report_view.dart';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../../../data/services/calculation_worker.dart';
import '../../../data/services/range_worker.dart';
import '../../../domain/profile_data.dart';
import '../plan/gas_usage_view.dart';
import '../plan/level_editor.dart';
import '../plan/planner_view_model.dart';
import '../plan/profile_view.dart';
import 'range_view_model.dart';

class RangeCellView extends StatefulWidget {
  const RangeCellView({
    super.key,
    required this.cell,
    required this.range,
    required this.model,
  });
  final RangeSummary cell;
  final RangeViewModel range;
  final PlannerViewModel model;
  @override
  State<RangeCellView> createState() => _RangeCellViewState();
}

class _RangeCellViewState extends State<RangeCellView> {
  final worker = CalculationWorker();
  CalculationResult? result;
  WorkerFailure? failure;
  bool get current =>
      widget.range.inputsCurrent &&
      widget.range.inputRevision == widget.model.planRequest.revision;
  @override
  void initState() {
    super.initState();
    calculate();
  }

  Future<void> calculate() async {
    setState(() => failure = null);
    try {
      final value = await worker
          .calculate(
            widget.cell.request,
            bailout: widget.cell.bailout,
            inputRevision: widget.range.inputRevision,
            dependencyVersion: 'range:${widget.range.inputRevision}',
          )
          .result;
      if (mounted) setState(() => result = value);
    } on WorkerFailure catch (error) {
      if (mounted) setState(() => failure = error);
    }
  }

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.model, widget.range]),
    builder: (context, _) {
      final units = widget.model.units,
          settings = widget.cell.request.settings,
          value = result;
      return Scaffold(
        appBar: AppBar(title: const Text('Сценарий диапазона')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${depthText(widget.cell.depthMetres, units)} ${depthUnit(units)} · ${widget.cell.durationMin} мин · ${widget.cell.variant.name}',
              ),
              Text(
                '${settings.model.name} · $calculationModelVersion · ${settings.model == DecompressionModel.vpmB ? 'Консерватизм ${settings.vpmConservatism}' : 'GF ${(settings.gradientFactors.low * 100).toStringAsFixed(0)}/${(settings.gradientFactors.high * 100).toStringAsFixed(0)}'}',
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  current
                      ? 'Условия актуальны'
                      : 'Снимок диапазона неактуален · входы изменены',
                ),
              ),
              if (failure != null) ...[
                Text('Полный расчёт не завершён: ${failure!.message}'),
                TextButton(
                  onPressed: calculate,
                  child: const Text('Повторить'),
                ),
              ] else if (value == null)
                const LinearProgressIndicator(
                  semanticsLabel: 'Полный расчёт сценария',
                )
              else ...[
                Text(
                  'Runtime ${value.runtimeMin.toStringAsFixed(3)} мин · подъём ${value.ascentMin.toStringAsFixed(3)} мин · остановки ${value.decompressionMin.toStringAsFixed(3)} мин',
                ),
                Text(
                  'Первая остановка ${depthText(value.firstStopMetres, units)} ${depthUnit(units)} · поверхность ${value.pressure.surfaceBar.toStringAsFixed(5)} bar',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: !current
                          ? null
                          : () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ReportView(
                                  report: PlannerReport.dive(
                                    result: value,
                                    request: widget.cell.request,
                                    bailout: widget.cell.bailout,
                                    units: units,
                                  ),
                                  changes: Listenable.merge([
                                    widget.model,
                                    widget.range,
                                  ]),
                                  isCurrent: () => current,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Печатный вид'),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => ProfileView(
                            data: ProfileData(
                              result: value,
                              settings: settings,
                            ),
                            model: widget.model,
                            isCurrent: () => current,
                          ),
                        ),
                      ),
                      child: const Text('Профиль и ткани'),
                    ),
                    OutlinedButton(
                      onPressed: !current
                          ? null
                          : () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ListenableBuilder(
                                  listenable: Listenable.merge([
                                    widget.model,
                                    widget.range,
                                  ]),
                                  builder: (context, _) => !current
                                      ? Scaffold(
                                          appBar: AppBar(
                                            title: const Text('Расход газа'),
                                          ),
                                          body: SafeArea(
                                            child: const Center(
                                              child: Text(
                                                'Снимок диапазона неактуален · входы изменены',
                                              ),
                                            ),
                                          ),
                                        )
                                      : GasUsageView(
                                          report: calculateGasUsage(
                                            value,
                                            settings,
                                            stopsPerGroup:
                                                widget.model.ratioStops,
                                          ),
                                          units: widget.model.units,
                                          drafts: widget.model.toolDraft,
                                          onDraft: widget.model.setToolDraft,
                                        ),
                                ),
                              ),
                            ),
                      child: const Text('Расход газа и баллоны'),
                    ),
                  ],
                ),
                for (final segment in value.segments)
                  ExpansionTile(
                    title: Text(
                      '${segment.startMin.toStringAsFixed(3)}–${segment.endMin.toStringAsFixed(3)} мин · ${segment.phase.name}',
                    ),
                    subtitle: Text(
                      '${depthText(segment.physical.startDepthMetres, units)} → ${depthText(segment.physical.endDepthMetres, units)} ${depthUnit(units)} · O₂ ${(segment.physical.breathing.gas.oxygen * 100).toStringAsFixed(2)}% / He ${(segment.physical.breathing.gas.helium * 100).toStringAsFixed(2)}% · ${segment.physical.breathing.mode.name}${segment.physical.breathing.setpointBar == null ? '' : ' · SP ${segment.physical.breathing.setpointBar!.toStringAsFixed(3)} bar'}',
                    ),
                    children: [
                      Text(
                        'CNS ${segment.endState.oxygen.cnsFraction == null ? 'недоступен: вне области 1,6 ATA' : '${(segment.endState.oxygen.cnsFraction! * 100).toStringAsFixed(3)}%'} · OTU ${segment.endState.oxygen.otu.toStringAsFixed(3)}',
                      ),
                      for (var i = 0; i < 16; i++)
                        ListTile(
                          title: Text('Ткань ${i + 1}'),
                          subtitle: Text(
                            'N₂ ${segment.endState.tissues.nitrogenBar[i].toStringAsFixed(6)} bar · He ${segment.endState.tissues.heliumBar[i].toStringAsFixed(6)} bar',
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
