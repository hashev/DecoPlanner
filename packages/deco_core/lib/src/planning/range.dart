import '../model/plan.dart';
import '../model/gas.dart';
import '../model/request.dart';
import '../model/result.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../units/units.dart';
import 'buhlmann_schedule.dart';
import 'vpm_schedule.dart';

enum RangeVariant { base, noAdditionalGases, noSwitches }

final class RangeAxis {
  RangeAxis({required this.first, required this.last, required this.step}) {
    for (final entry in {'first': first, 'last': last, 'step': step}.entries) {
      requireFinite(entry.value, entry.key, nonnegative: true);
    }
    if (step == 0 || last < first) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Range endpoints must be ordered and step positive.',
      );
    }
    final intervals = (last - first) / step;
    requireFinite(intervals, 'range interval count', nonnegative: true);
    if (intervals > 9999 || (intervals - intervals.round()).abs() > 1e-8) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Range must have at most10000 aligned points, including both endpoints.',
      );
    }
    length = intervals.round() + 1;
  }
  final double first, last, step;
  late final int length;
  double at(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.range(index, 0, length - 1, 'index');
    }
    return index == length - 1 ? last : first + index * step;
  }
}

final class RangeCell {
  const RangeCell({
    required this.depthMetres,
    required this.durationMin,
    required this.variant,
    required this.request,
    required this.bailout,
    this.result,
    this.failure,
  });
  final double depthMetres, durationMin;
  final RangeVariant variant;
  final DiveRequest request;
  final BailoutRequest? bailout;
  final CalculationResult? result;
  final CalculationFailure? failure;
}

/// Lazily calculates the inclusive grid by replacing only the last entered
/// level. Caller should execute iteration in a worker; each yielded cell is a
/// progress boundary. Cancel/global budget abort the range, other cell errors
/// remain visible and do not erase successful neighbours.
Iterable<RangeCell> calculateRange({
  required DiveRequest source,
  required RangeAxis depths,
  required RangeAxis durations,
  Iterable<RangeVariant> variants = const [RangeVariant.base],
  BailoutRequest? bailout,
  int maximumCells = 1000,
  CalculationBudget? budget,
}) sync* {
  final selected = variants.toSet().toList();
  if (maximumCells <= 0 ||
      selected.isEmpty ||
      depths.length * durations.length * selected.length > maximumCells) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Range is empty or exceeds the requested cell limit.',
    );
  }
  if (bailout != null && bailout.sourceDiveId != source.id) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Range bailout must belong to its source.',
    );
  }
  final limits = budget ?? CalculationBudget();
  for (var di = 0; di < depths.length; di++) {
    for (var ti = 0; ti < durations.length; ti++) {
      for (final variant in selected) {
        limits.consume();
        final depth = depths.at(di), duration = durations.at(ti);
        final previous = source.levels.last;
        final request = DiveRequest(
          id: source.id,
          settings: source.settings,
          levels: [
            ...source.levels.take(source.levels.length - 1),
            Level(
              depthMetres: depth,
              durationMin: duration,
              breathing: previous.breathing,
            ),
          ],
          switches: source.switches.where(
            (s) => switch (variant) {
              RangeVariant.base => true,
              RangeVariant.noAdditionalGases =>
                s.breathing.mode == BreathingMode.ccr,
              RangeVariant.noSwitches => false,
            },
          ),
          surfaceIntervalMin: source.surfaceIntervalMin,
          initialState: source.initialState,
        );
        final branch = bailout == null
            ? null
            : BailoutRequest(
                id: bailout.id,
                sourceDiveId: bailout.sourceDiveId,
                runtimeMin: bailout.runtimeMin,
                initialOcGas: bailout.initialOcGas,
                switches: variant == RangeVariant.base ? bailout.switches : [],
              );
        CalculationResult? result;
        CalculationFailure? failure;
        try {
          if (branch != null) {
            result = source.settings.model == DecompressionModel.vpmB
                ? calculateVpmBailout(request, branch, budget: limits)
                : calculateBuhlmannBailout(request, branch, budget: limits);
          } else {
            result = source.settings.model == DecompressionModel.vpmB
                ? calculateVpm(request, budget: limits)
                : calculateBuhlmann(request, budget: limits);
          }
        } on CalculationFailure catch (error) {
          if (error.code == CalculationFailureCode.cancelled ||
              error.code == CalculationFailureCode.budgetExceeded) {
            rethrow;
          }
          failure = error;
        }
        limits.check(includeIterations: false);
        yield RangeCell(
          depthMetres: depth,
          durationMin: duration,
          variant: variant,
          request: request,
          bailout: branch,
          result: result,
          failure: failure,
        );
      }
    }
  }
}
