import 'dart:math' as math;
import '../buhlmann/coefficients.dart';
import '../model/calculation_state.dart';
import '../model/gas.dart';
import '../model/plan.dart';
import '../model/request.dart';
import '../model/result.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../oxygen/oxygen.dart';
import '../tissues/segments.dart';
import '../vpm/physics.dart';
import '../vpm/gradients.dart';

final class BailoutContinuation {
  const BailoutContinuation(this.request, this.prefix);
  final DiveRequest request;
  final CalculationResult prefix;
}

/// Internal continuation assembled only from a freshly calculated source.
BailoutContinuation prepareBailoutContinuation(
  CalculationResult original,
  BailoutRequest bailout,
  CalculationSettings settings,
  CalculationBudget budget,
) {
  final point = bailout.runtimeMin;
  if (point <= 0 ||
      point > original.runtimeMin ||
      (point == original.runtimeMin &&
          (original.segments.last.physical.endDepthMetres <= 0 ||
              original.segments.last.physical.breathing.mode !=
                  BreathingMode.ccr))) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Bailout must occur strictly inside the underwater profile.',
    );
  }
  final prefix = <Segment>[];
  var state = original.initialState;
  var depth = 0.0;
  var firstStop = 0.0;
  var ascent = 0.0;
  var deco = 0.0;
  var inDeco = false;
  final kinetics = settings.model == DecompressionModel.buhlmannC
      ? BuhlmannCoefficients.c().kinetics
      : BuhlmannCoefficients.b().kinetics;
  for (final segment in original.segments) {
    budget.consume();
    final physical = segment.physical;
    if (segment.endMin > point &&
        physical.breathing.mode != BreathingMode.ccr) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Bailout requires active CCR breathing at the selected runtime.',
      );
    }
    if (segment.startMin >= point) break;
    final duration = math.min(physical.durationMin, point - segment.startMin);
    final complete = segment.endMin <= point;
    depth = complete
        ? physical.endDepthMetres
        : physical.startDepthMetres +
              (physical.endDepthMetres - physical.startDepthMetres) *
                  (duration / physical.durationMin);
    final part = PropagationSegment(
      startDepthMetres: physical.startDepthMetres,
      endDepthMetres: depth,
      durationMin: duration,
      breathing: physical.breathing,
    );
    state = complete
        ? segment.endState
        : CalculationState(
            tissues: part.propagate(state.tissues, kinetics, original.pressure),
            oxygen: OxygenPolicy.exposeSegment(
              state.oxygen,
              part,
              original.pressure,
            ),
          );
    if (!complete && settings.model == DecompressionModel.vpmB) {
      final previous = prefix.isEmpty
          ? original.initialState
          : prefix.last.endState;
      var bubble = previous.vpm!;
      final physics = VpmPhysics(
        parameters: settings.vpm,
        kinetics: kinetics,
        budget: budget,
      );
      final gradients = VpmGradients(
        parameters: settings.vpm,
        kinetics: kinetics,
        budget: budget,
      );
      if (part.endDepthMetres > part.startDepthMetres) {
        bubble = physics.crushingAfterDescent(
          bubble: bubble,
          initialTissues: previous.tissues,
          segment: part,
          pressure: original.pressure,
        );
      } else if (segment.phase == SegmentPhase.ascent ||
          segment.phase == SegmentPhase.decompression) {
        // Search/Boyle context belongs to this segment. Its endpoint's actual
        // supersaturation does not: recompute that only to the failure point.
        bubble = segment.endState.vpm!.copyWith(
          segmentStartTissues: previous.tissues,
          maxActualGradientBar: bubble.maxActualGradientBar,
        );
        if (segment.phase == SegmentPhase.ascent) {
          bubble = gradients.recordActualGradient(
            bubble,
            state.tissues,
            original.pressure.ambientBar(depth),
          );
        }
      }
      state = CalculationState(
        tissues: state.tissues,
        oxygen: state.oxygen,
        vpm: bubble,
      );
    }
    prefix.add(
      complete
          ? segment
          : Segment(
              physical: part,
              phase: segment.phase,
              startMin: segment.startMin,
              endState: state,
            ),
    );
    if (segment.phase == SegmentPhase.decompression) {
      if (!inDeco) firstStop = depth;
      inDeco = true;
    }
    if (segment.phase == SegmentPhase.ascent ||
        segment.phase == SegmentPhase.decompression) {
      ascent += duration;
      if (inDeco) deco += duration;
    }
    if (!complete) break;
  }
  if (depth <= 0) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Bailout requires a positive underwater depth.',
    );
  }
  if (settings.model == DecompressionModel.vpmB) {
    firstStop = prefix.fold(
      0.0,
      (value, segment) =>
          math.max(value, segment.endState.vpm!.maximumFirstStopMetres),
    );
  }
  final branch = DiveRequest(
    id: bailout.id,
    levels: [
      Level(
        depthMetres: depth,
        durationMin: 0,
        breathing: BreathingGas.oc(bailout.initialOcGas),
      ),
    ],
    switches: bailout.switches,
    settings: settings,
  );
  return BailoutContinuation(
    branch,
    CalculationResult(
      diveId: bailout.id,
      modelVersion: original.modelVersion,
      initialState: original.initialState,
      pressure: original.pressure,
      segments: prefix,
      firstStopMetres: firstStop,
      ascentMin: ascent,
      decompressionMin: deco,
    ),
  );
}
