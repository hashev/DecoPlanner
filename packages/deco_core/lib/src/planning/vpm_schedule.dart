import 'dart:math' as math;
import '../buhlmann/coefficients.dart';
import '../model/calculation_state.dart';
import '../model/gas.dart';
import '../model/plan.dart';
import '../model/request.dart';
import '../model/result.dart';
import '../model/vpm_state.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../oxygen/oxygen.dart';
import '../tissues/segments.dart';
import '../tissues/tissues.dart';
import '../units/units.dart';
import '../vpm/gradients.dart';
import '../vpm/physics.dart';
import 'surface.dart';
import 'bailout_continuation.dart';

/// VPM-B with explicit per-request state and bounded critical-volume search.
CalculationResult calculateVpm(
  DiveRequest request, {
  CalculationBudget? budget,
}) {
  if (request.settings.model != DecompressionModel.vpmB) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'A VPM engine requires a VPM request.',
    );
  }
  return _VpmSchedule(request, budget ?? CalculationBudget()).calculate();
}

/// Calculates an independent OC escape retaining the CCR prefix and full VPM
/// state. Surface preparation and repetitive recovery apply only to the source.
CalculationResult calculateVpmBailout(
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
  if (source.settings.model != DecompressionModel.vpmB) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'A VPM engine requires a VPM request.',
    );
  }
  final levels = _VpmSchedule(source, limits).calculate(stopAfterLevels: true);
  final original = bailout.runtimeMin <= levels.runtimeMin
      ? levels
      : calculateVpm(source, budget: limits);
  final continuation = prepareBailoutContinuation(
    original,
    bailout,
    source.settings,
    limits,
  );
  return _VpmSchedule(
    continuation.request,
    limits,
  ).calculate(prefix: continuation.prefix);
}

final class _VpmStep {
  const _VpmStep(this.physical, this.phase, this.tissues, this.bubble);
  final PropagationSegment physical;
  final SegmentPhase phase;
  final TissueState tissues;
  final VpmState bubble;
}

final class _AscentPass {
  const _AscentPass(this.steps, this.tissues, this.bubble, this.runtime);
  final List<_VpmStep> steps;
  final TissueState tissues;
  final VpmState bubble;
  final double runtime;
}

final class _VpmSchedule {
  _VpmSchedule(this.request, this.budget);
  final DiveRequest request;
  final CalculationBudget budget;
  CalculationSettings get settings => request.settings;
  final kinetics = BuhlmannCoefficients.b().kinetics;
  late final VpmPhysics physics = VpmPhysics(
    parameters: settings.vpm,
    kinetics: kinetics,
    budget: budget,
  );
  late final VpmGradients gradients = VpmGradients(
    parameters: settings.vpm,
    kinetics: kinetics,
    budget: budget,
  );
  late PressureContext pressure;
  late TissueState tissues;
  late OxygenState oxygen;
  late VpmState bubble;
  late BreathingGas breathing;
  final segments = <Segment>[];
  double depth = 0, runtime = 0, ascentTime = 0, decoTime = 0, firstStop = 0;

  CalculationResult calculate({
    CalculationResult? prefix,
    bool stopAfterLevels = false,
  }) {
    budget.check();
    late final CalculationState initial;
    if (prefix == null) {
      final prepared = prepareInitialSurface(
        settings,
        supplied: request.initialState,
      );
      pressure = prepared.pressure;
      final recovered = recoverSurface(
        prepared.state,
        request.surfaceIntervalMin,
        pressure: pressure,
        kinetics: kinetics,
        parameters: settings.vpm,
      );
      tissues = recovered.tissues;
      oxygen = recovered.oxygen;
      final previous = recovered.vpm;
      if (previous != null && previous.modelVersion != settings.vpm.version) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Initial VPM state and parameter versions differ.',
        );
      }
      // Scratch arrays belong to this dive; repetitive excitation lives in radii.
      bubble = VpmState.initial(
        parameters: settings.vpm,
        conservatism: settings.vpmConservatism,
        tissues: tissues,
        pressure: pressure,
      );
      if (previous != null) {
        bubble = bubble.copyWith(
          initialRadiusNitrogenMetres: previous.initialRadiusNitrogenMetres,
          initialRadiusHeliumMetres: previous.initialRadiusHeliumMetres,
          adjustedInitialRadiusNitrogenMetres:
              previous.adjustedInitialRadiusNitrogenMetres,
          adjustedInitialRadiusHeliumMetres:
              previous.adjustedInitialRadiusHeliumMetres,
        );
      }
      initial = CalculationState(tissues: tissues, oxygen: oxygen, vpm: bubble);
    } else {
      initial = prefix.initialState;
      pressure = prefix.pressure;
      tissues = prefix.finalTissues;
      oxygen = prefix.finalState.oxygen;
      bubble = prefix.finalState.vpm!;
      segments.addAll(prefix.segments);
      runtime = prefix.runtimeMin;
      depth = prefix.segments.last.physical.endDepthMetres;
      ascentTime = prefix.ascentMin;
      decoTime = prefix.decompressionMin;
      firstStop = prefix.firstStopMetres;
    }
    breathing = request.levels.first.breathing;
    for (final level in prefix == null ? request.levels : const <Level>[]) {
      if (level.depthMetres < depth) {
        _ascend(level.depthMetres);
        breathing = level.breathing;
        _append(
          PropagationSegment(
            startDepthMetres: depth,
            endDepthMetres: depth,
            durationMin: level.durationMin + runtime.ceilToDouble() - runtime,
            breathing: breathing,
          ),
          SegmentPhase.levelHold,
        );
      } else {
        final descending = level.depthMetres > depth;
        if (descending) bubble = bubble.copyWith(maximumFirstStopMetres: 0);
        final movement = descending && level.breathing.mode == BreathingMode.ccr
            ? BreathingGas.ccr(level.breathing.gas, settings.lowSetpointBar)
            : level.breathing;
        for (final part in prepareLevel(
          startDepthMetres: depth,
          targetDepthMetres: level.depthMetres,
          levelDurationMin: level.durationMin,
          descentMetresPerMin: settings.descentMetresPerMin,
          ascentMetresPerMin: settings.ascentMetresPerMin,
          includeDescentInLevelTime: settings.includeDescentInLevelTime,
          movementGas: movement,
          levelGas: level.breathing,
        )) {
          _append(
            part,
            part.isMovement ? SegmentPhase.levelTravel : SegmentPhase.levelHold,
          );
        }
        breathing = level.breathing;
      }
    }
    if (!stopAfterLevels) _ascend(0);
    if (!stopAfterLevels) bubble = finalizeSurfaceBubbles(bubble, settings.vpm);
    if (!stopAfterLevels && segments.isNotEmpty) {
      final last = segments.removeLast();
      segments.add(
        Segment(
          physical: last.physical,
          phase: last.phase,
          startMin: last.startMin,
          endState: CalculationState(
            tissues: tissues,
            oxygen: oxygen,
            vpm: bubble,
          ),
        ),
      );
    }
    return CalculationResult(
      diveId: request.id,
      modelVersion: calculationModelVersion,
      pressure: pressure,
      initialState: initial,
      segments: segments,
      firstStopMetres: firstStop,
      ascentMin: ascentTime,
      decompressionMin: decoTime,
    );
  }

  void _append(PropagationSegment physical, SegmentPhase phase) {
    if (physical.durationMin == 0) return;
    budget.consume();
    if (physical.endDepthMetres > physical.startDepthMetres) {
      bubble = physics.crushingAfterDescent(
        bubble: bubble,
        initialTissues: tissues,
        segment: physical,
        pressure: pressure,
      );
    }
    tissues = physical.propagate(tissues, kinetics, pressure);
    oxygen = OxygenPolicy.exposeSegment(oxygen, physical, pressure);
    segments.add(
      Segment(
        physical: physical,
        phase: phase,
        startMin: runtime,
        endState: CalculationState(
          tissues: tissues,
          oxygen: oxygen,
          vpm: bubble,
        ),
      ),
    );
    runtime += physical.durationMin;
    depth = physical.endDepthMetres;
    breathing = physical.breathing;
  }

  double _zoneDepth() {
    final travel = depth / settings.ascentMetresPerMin;
    if (travel == 0) return 0;
    TissueState at(double time) => kinetics.propagate(
      initial: tissues,
      pressure: pressure,
      breathing: breathing,
      startDepthMetres: depth,
      endDepthMetres: math.max(0, depth - time * settings.ascentMetresPerMin),
      durationMin: time,
    );
    final surface = at(travel);
    var zone = 0.0;
    for (var i = 0; i < 16; i++) {
      budget.consume();
      double tension(TissueState t) =>
          t.nitrogenBar[i] + t.heliumBar[i] + settings.vpm.otherGasesBar;
      if (tension(tissues) >= pressure.ambientBar(depth)) return depth;
      if (tension(surface) <= pressure.surfaceBar) continue;
      final root = solveBracketed(
        function: (time) =>
            tension(at(time)) -
            pressure.ambientBar(
              math.max(0, depth - time * settings.ascentMetresPerMin),
            ),
        lower: 0,
        upper: travel,
        budget: budget,
        residualTolerance: 1e-12,
        positionTolerance: 1e-13,
      ).value;
      zone = math.max(zone, depth - root * settings.ascentMetresPerMin);
    }
    return zone;
  }

  void _ascend(double target) {
    if (target >= depth) return;
    bubble = physics.regenerate(bubble, runtime);
    final bottom = tissues, bottomDepth = depth, bottomRuntime = runtime;
    final bottomBreathing = breathing;
    final zone = _zoneDepth();
    final zoneTime = (depth - zone) / settings.ascentMetresPerMin;
    final zoneTissues = kinetics.propagate(
      initial: tissues,
      pressure: pressure,
      breathing: breathing,
      startDepthMetres: depth,
      endDepthMetres: zone,
      durationMin: zoneTime,
    );
    final zeros = List<double>.filled(16, 0);
    bubble = bubble.copyWith(
      ascentStartTissues: bottom,
      decoStartTissues: zoneTissues,
      savedRuntimeMin: runtime,
      savedSegmentCount: segments.length,
      decoZoneStartMin: runtime + zoneTime,
      totalPhaseVolumeMin: zeros,
      previousPhaseVolumeMin: zeros,
      surfacePhaseVolumeMin: zeros,
      decoPhaseVolumeMin: 0,
      criticalVolumeIterations: 0,
    );
    var accepted = 0.0;
    while (true) {
      budget.consume();
      bubble = bubble.copyWith(
        criticalVolumeIterations: bubble.criticalVolumeIterations + 1,
      );
      final ceiling = gradients.ceilingMetres(bubble, zoneTissues, pressure);
      final rounded = ceiling <= 0
          ? 0.0
          : _nearestEven(ceiling / settings.stopGrid.stepMetres + .5) *
                settings.stopGrid.stepMetres;
      var candidate = settings.stopGrid.atOrDeeper(rounded);
      candidate = gradients.projectedAscent(
        bubble: bubble,
        initial: zoneTissues,
        fromMetres: zone,
        candidateMetres: candidate,
        breathing: bottomBreathing,
        ascentMetresPerMin: settings.ascentMetresPerMin,
        pressure: pressure,
        grid: settings.stopGrid,
      );
      bubble = bubble.copyWith(
        maximumFirstStopMetres: math.max(
          bubble.maximumFirstStopMetres,
          candidate,
        ),
      );
      if (candidate == 0) {
        accepted = 0;
        break;
      }
      final trial = _pass(
        initial: zoneTissues,
        from: zone,
        startMin: bottomRuntime + zoneTime,
        initialBreathing: bottomBreathing,
        first: candidate,
        target: 0,
        initialBubble: bubble,
        recordActual: false,
      );
      bubble = gradients.phaseVolume(
        trial.bubble,
        surfaceTissues: trial.tissues,
        pressure: pressure,
        decoDurationMin: trial.runtime - (bottomRuntime + zoneTime),
      );
      if (!settings.vpm.criticalVolumeEnabled ||
          gradients.isConverged(bubble)) {
        accepted = candidate;
        break;
      }
      bubble = gradients
          .relaxGradients(bubble)
          .copyWith(
            previousPhaseVolumeMin: bubble.totalPhaseVolumeMin,
            decoPhaseVolumeMin: 0,
          );
    }
    firstStop = math.max(firstStop, bubble.maximumFirstStopMetres);
    final actual = _pass(
      initial: bottom,
      from: bottomDepth,
      startMin: bottomRuntime,
      initialBreathing: bottomBreathing,
      first: accepted,
      target: target,
      initialBubble: bubble,
      recordActual: true,
    );
    var reachedFirst = false;
    for (final step in actual.steps) {
      if (step.phase == SegmentPhase.decompression) reachedFirst = true;
      ascentTime += step.physical.durationMin;
      if (reachedFirst) decoTime += step.physical.durationMin;
      bubble = step.bubble;
      _append(step.physical, step.phase);
    }
    tissues = actual.tissues;
    bubble = actual.bubble;
  }

  _AscentPass _pass({
    required TissueState initial,
    required double from,
    required double startMin,
    required BreathingGas initialBreathing,
    required double first,
    required double target,
    required VpmState initialBubble,
    required bool recordActual,
  }) {
    var state = initial, b = initialBubble;
    var current = from, time = startMin;
    var gas = initialBreathing;
    GasSwitch? selected;
    final steps = <_VpmStep>[];
    bool same(double a, double b) =>
        (a - b).abs() <=
        16 * 2.220446049250313e-16 * math.max(1, math.max(a.abs(), b.abs()));
    void select() {
      for (final s in request.switches) {
        if (!s.lost &&
            (s.depthMetres >= current || same(s.depthMetres, current)) &&
            (selected == null || s.depthMetres < selected!.depthMetres)) {
          gas = s.breathing;
          selected = s;
        }
      }
    }

    void append(double next, double minutes, SegmentPhase phase) {
      if (minutes == 0) return;
      budget.consume();
      final physical = PropagationSegment(
        startDepthMetres: current,
        endDepthMetres: next,
        durationMin: minutes,
        breathing: gas,
      );
      b = b.copyWith(segmentStartTissues: state);
      state = physical.propagate(state, kinetics, pressure);
      if (recordActual && phase == SegmentPhase.ascent) {
        b = gradients.recordActualGradient(b, state, pressure.ambientBar(next));
      }
      steps.add(_VpmStep(physical, phase, state, b));
      current = next;
      time += minutes;
    }

    var stop = math.max(target, first);
    while (current > target) {
      budget.consume();
      final next = stop;
      if (current > next) {
        append(
          next,
          (current - next) / settings.ascentMetresPerMin,
          SegmentPhase.ascent,
        );
      }
      select();
      if (current <= target) break;
      if (current > stop) continue;
      final nextStop = math.max(
        target,
        settings.stopGrid.nextShallower(current),
      );
      b = gradients.boyleCompensation(
        b,
        nextDepthMetres: nextStop,
        pressure: pressure,
      );
      final inspired = inspiredInert(
        pressure.ambientBar(current),
        pressure.waterVapourBar,
        gas,
      );
      final equilibrium = TissueState(
        nitrogenBar: List<double>.filled(16, inspired.nitrogen),
        heliumBar: List<double>.filled(16, inspired.helium),
      );
      if (gradients.ceilingMetres(b, equilibrium, pressure, boyle: true) >
          nextStop) {
        throw CalculationFailure(
          CalculationFailureCode.nonConvergence,
          'Off-gassing gradient cannot clear the next stop from ${current}m.',
        );
      }
      final minimum = selected?.minimumStopMin ?? settings.minimumStopMin;
      var duration = _nearestEven(time / minimum + .501) * minimum - time;
      if (duration <= 0) duration = minimum;
      var trial = kinetics.propagate(
        initial: state,
        pressure: pressure,
        breathing: gas,
        startDepthMetres: current,
        endDepthMetres: current,
        durationMin: duration,
      );
      while (gradients.ceilingMetres(b, trial, pressure, boyle: true) >
          nextStop) {
        budget.consume();
        duration += minimum;
        trial = kinetics.propagate(
          initial: trial,
          pressure: pressure,
          breathing: gas,
          startDepthMetres: current,
          endDepthMetres: current,
          durationMin: minimum,
        );
      }
      append(current, duration, SegmentPhase.decompression);
      stop = nextStop;
    }
    return _AscentPass(steps, state, b, time);
  }
}

double _nearestEven(double value) {
  requireFinite(value, 'VPM stop alignment');
  final floor = value.floorToDouble(), fraction = value - value.floorToDouble();
  if (fraction < .5) return floor;
  if (fraction > .5) return floor + 1;
  return floor % 2 == 0 ? floor : floor + 1;
}
