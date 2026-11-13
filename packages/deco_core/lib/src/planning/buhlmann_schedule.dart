import 'dart:math' as math;
import '../buhlmann/ceiling.dart';
import '../buhlmann/coefficients.dart';
import '../model/gas.dart';
import '../model/request.dart';
import '../model/result.dart';
import '../model/plan.dart';
import '../model/calculation_state.dart';
import '../oxygen/oxygen.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../tissues/segments.dart';
import 'surface.dart';
import 'bailout_continuation.dart';

/// Stateless per-dive schedule. Cross-dive and VPM state are handled by the
/// plan dispatcher; this engine neither reads fixtures nor calls native code.
CalculationResult calculateBuhlmann(
  DiveRequest request, {
  CalculationBudget? budget,
}) => _calculateBuhlmann(request, budget: budget);

CalculationResult _calculateBuhlmann(
  DiveRequest request, {
  CalculationBudget? budget,
  CalculationResult? prefix,
  bool stopAfterLevels = false,
}) {
  if (request.settings.model == DecompressionModel.vpmB) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'A Bühlmann engine cannot execute a VPM request.',
    );
  }
  final limits = budget ?? CalculationBudget();
  final settings = request.settings;
  final coefficients = settings.model == DecompressionModel.buhlmannB
      ? BuhlmannCoefficients.b()
      : BuhlmannCoefficients.c();
  final model = BuhlmannModel(coefficients);
  final prepared = prefix == null
      ? prepareInitialSurface(settings, supplied: request.initialState)
      : null;
  final pressure = prefix?.pressure ?? prepared!.pressure;
  final grid = settings.stopGrid;
  final gf = settings.gradientFactors;
  final initialState =
      prefix?.initialState ??
      recoverSurface(
        prepared!.state,
        request.surfaceIntervalMin,
        pressure: pressure,
        kinetics: coefficients.kinetics,
        parameters: settings.vpm,
      );
  var state = (prefix?.finalState ?? initialState).tissues;
  var oxygen = (prefix?.finalState ?? initialState).oxygen;
  var depth = prefix?.segments.last.physical.endDepthMetres ?? 0.0;
  var runtime = prefix?.runtimeMin ?? 0.0;
  var ascentTime = 0.0;
  var decoTime = 0.0;
  var anchor = prefix?.firstStopMetres ?? 0.0;
  var maximumFirstStop = anchor;
  var breathing = request.levels.first.breathing;
  final segments = <Segment>[...?prefix?.segments];
  if (prefix != null) {
    ascentTime = prefix.ascentMin;
    decoTime = prefix.decompressionMin;
  }
  GasSwitch? selectedSwitch;

  void append(double target, double duration, SegmentPhase phase) {
    if (duration == 0 && depth == target) return;
    limits.consume();
    final physical = PropagationSegment(
      startDepthMetres: depth,
      endDepthMetres: target,
      durationMin: duration,
      breathing: breathing,
    );
    state = physical.propagate(state, coefficients.kinetics, pressure);
    oxygen = OxygenPolicy.exposeSegment(oxygen, physical, pressure);
    segments.add(
      Segment(
        physical: physical,
        phase: phase,
        startMin: runtime,
        endState: CalculationState(tissues: state, oxygen: oxygen),
      ),
    );
    runtime += duration;
    depth = target;
    if (phase == SegmentPhase.ascent || phase == SegmentPhase.decompression) {
      ascentTime += duration;
    }
    if (phase == SegmentPhase.decompression) decoTime += duration;
  }

  // Unit conversion/grid subtraction may differ by a few binary ULPs.
  // This tolerance only identifies the same physical switch boundary.
  bool sameDepth(double a, double b) =>
      (a - b).abs() <=
      16 * 2.220446049250313e-16 * math.max(1, math.max(a.abs(), b.abs()));
  void selectSwitch() {
    for (final candidate in request.switches) {
      if (candidate.lost ||
          (candidate.depthMetres < depth &&
              !sameDepth(candidate.depthMetres, depth))) {
        continue;
      }
      // Preserve supplied order; an already selected shallower switch is never
      // replaced by an older/deeper one on subsequent stop iterations.
      if (selectedSwitch == null ||
          candidate.depthMetres < selectedSwitch!.depthMetres) {
        breathing = candidate.breathing;
        selectedSwitch = candidate;
      }
    }
  }

  double interceptSwitch(double target) {
    var next = target;
    for (final candidate in request.switches) {
      if (!candidate.lost &&
          candidate.depthMetres < depth &&
          candidate.depthMetres > next &&
          !sameDepth(candidate.depthMetres, next) &&
          (selectedSwitch == null ||
              candidate.depthMetres < selectedSwitch!.depthMetres)) {
        next = candidate.depthMetres;
      }
    }
    return next;
  }

  void ascend(double target) {
    if (depth <= target) return;
    var stop = model.firstStop(
      state: state,
      currentDepthMetres: depth,
      ascentMetresPerMin: settings.ascentMetresPerMin,
      breathing: breathing,
      gf: gf,
      pressure: pressure,
      grid: grid,
      budget: limits,
    );
    if (stop < target) stop = target;
    if (anchor == 0 && stop > target) anchor = stop;
    if (stop > maximumFirstStop) maximumFirstStop = stop;
    var reachedFirst = false;
    while (depth > target) {
      limits.consume();
      final next = interceptSwitch(stop);
      if (depth > next) {
        final duration = (depth - next) / settings.ascentMetresPerMin;
        append(next, duration, SegmentPhase.ascent);
        if (reachedFirst) decoTime += duration;
      }
      selectSwitch();
      if (depth <= target) break;
      if (depth > stop) continue;
      reachedFirst = true;
      var nextStop = grid.nextShallower(depth);
      if (nextStop < target) nextStop = target;
      nextStop = interceptSwitch(nextStop);
      final nextGf = gf.atDepth(depthMetres: nextStop, firstStopMetres: anchor);
      final minimum = selectedSwitch?.minimumStopMin ?? settings.minimumStopMin;
      // Runtime-aligned stop increments are model policy, not display rounding.
      var duration = runtime.floorToDouble() + minimum - runtime;
      while (duration <= 0) {
        limits.consume();
        duration += minimum;
      }
      var trial = coefficients.kinetics.propagate(
        initial: state,
        pressure: pressure,
        breathing: breathing,
        startDepthMetres: depth,
        endDepthMetres: depth,
        durationMin: duration,
      );
      while (model.ceiling(trial, nextGf, pressure).depthMetres > nextStop) {
        limits.consume();
        duration += minimum;
        trial = coefficients.kinetics.propagate(
          initial: trial,
          pressure: pressure,
          breathing: breathing,
          startDepthMetres: depth,
          endDepthMetres: depth,
          durationMin: minimum,
        );
      }
      append(depth, duration, SegmentPhase.decompression);
      stop = nextStop;
    }
  }

  if (prefix != null) selectSwitch();
  for (final level in prefix == null ? request.levels : const <Level>[]) {
    if (level.depthMetres < depth) {
      ascend(level.depthMetres);
      breathing = level.breathing;
      // Original level timing aligns a post-ascent hold to the next minute.
      final padding = runtime.ceilToDouble() - runtime;
      append(depth, level.durationMin + padding, SegmentPhase.levelHold);
      continue;
    }
    if (level.depthMetres > depth) {
      anchor = 0;
      selectedSwitch = null;
      breathing = level.breathing.mode == BreathingMode.ccr
          ? BreathingGas.ccr(level.breathing.gas, settings.lowSetpointBar)
          : level.breathing;
      final parts = prepareLevel(
        startDepthMetres: depth,
        targetDepthMetres: level.depthMetres,
        levelDurationMin: level.durationMin,
        descentMetresPerMin: settings.descentMetresPerMin,
        ascentMetresPerMin: settings.ascentMetresPerMin,
        includeDescentInLevelTime: settings.includeDescentInLevelTime,
        movementGas: breathing,
        levelGas: level.breathing,
      );
      for (final part in parts) {
        breathing = part.breathing;
        append(
          part.endDepthMetres,
          part.durationMin,
          part.isMovement ? SegmentPhase.levelTravel : SegmentPhase.levelHold,
        );
      }
    } else {
      breathing = level.breathing;
      append(depth, level.durationMin, SegmentPhase.levelHold);
    }
  }
  if (!stopAfterLevels) ascend(0);
  return CalculationResult(
    diveId: request.id,
    pressure: pressure,
    segments: segments,
    initialState: initialState,
    modelVersion: calculationModelVersion,
    firstStopMetres: maximumFirstStop,
    ascentMin: ascentTime,
    decompressionMin: decoTime,
  );
}

/// Calculates a separate OC escape from a point in a CCR Bühlmann dive.
///
/// The source is calculated with the same shared budget; callers cannot supply
/// an unrelated or stale tissue snapshot. Runtime is measured from the start of
/// the underwater profile, after altitude preparation and surface recovery.
/// At a segment boundary the gas of the following segment is active.
CalculationResult calculateBuhlmannBailout(
  DiveRequest source,
  BailoutRequest bailout, {
  CalculationBudget? budget,
}) {
  if (bailout.sourceDiveId != source.id || bailout.id == source.id) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Bailout must have a distinct identity and reference its source dive.',
    );
  }
  final limits = budget ?? CalculationBudget();
  final levels = _calculateBuhlmann(
    source,
    budget: limits,
    stopAfterLevels: true,
  );
  final original = bailout.runtimeMin <= levels.runtimeMin
      ? levels
      : calculateBuhlmann(source, budget: limits);
  final continuation = prepareBailoutContinuation(
    original,
    bailout,
    source.settings,
    limits,
  );
  return _calculateBuhlmann(
    continuation.request,
    budget: limits,
    prefix: continuation.prefix,
  );
}
