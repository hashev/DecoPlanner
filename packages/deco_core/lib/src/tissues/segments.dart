import '../model/gas.dart';
import '../numerics/failure.dart';
import '../units/units.dart';
import 'tissues.dart';

final class PropagationSegment {
  PropagationSegment({
    required this.startDepthMetres,
    required this.endDepthMetres,
    required this.durationMin,
    required this.breathing,
  }) {
    requireFinite(startDepthMetres, 'startDepthMetres', nonnegative: true);
    requireFinite(endDepthMetres, 'endDepthMetres', nonnegative: true);
    requireFinite(durationMin, 'durationMin', nonnegative: true);
    if (durationMin == 0 && startDepthMetres != endDepthMetres) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Movement cannot take zero time.',
      );
    }
  }
  final double startDepthMetres;
  final double endDepthMetres;
  final double durationMin;
  final BreathingGas breathing;
  bool get isMovement => startDepthMetres != endDepthMetres;

  TissueState propagate(
    TissueState initial,
    TissueKinetics kinetics,
    PressureContext pressure,
  ) => kinetics.propagate(
    initial: initial,
    pressure: pressure,
    breathing: breathing,
    startDepthMetres: startDepthMetres,
    endDepthMetres: endDepthMetres,
    durationMin: durationMin,
  );
}

/// Physical level expansion only. Decompression clearance/inserted stops on
/// ascent are the planning model's responsibility before executing movement.
List<PropagationSegment> prepareLevel({
  required double startDepthMetres,
  required double targetDepthMetres,
  required double levelDurationMin,
  required double descentMetresPerMin,
  required double ascentMetresPerMin,
  required bool includeDescentInLevelTime,
  required BreathingGas movementGas,
  required BreathingGas levelGas,
}) {
  for (final entry in {
    'startDepthMetres': startDepthMetres,
    'targetDepthMetres': targetDepthMetres,
    'levelDurationMin': levelDurationMin,
    'descentMetresPerMin': descentMetresPerMin,
    'ascentMetresPerMin': ascentMetresPerMin,
  }.entries) {
    requireFinite(entry.value, entry.key, nonnegative: true);
  }
  if (descentMetresPerMin == 0 || ascentMetresPerMin == 0) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Travel rates must be positive.',
    );
  }
  final descending = targetDepthMetres > startDepthMetres;
  final travel =
      (targetDepthMetres - startDepthMetres).abs() /
      (descending ? descentMetresPerMin : ascentMetresPerMin);
  final hold =
      levelDurationMin - (descending && includeDescentInLevelTime ? travel : 0);
  if (hold < 0) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Level duration is insufficient for descent.',
    );
  }
  return List.unmodifiable([
    if (travel > 0)
      PropagationSegment(
        startDepthMetres: startDepthMetres,
        endDepthMetres: targetDepthMetres,
        durationMin: travel,
        breathing: movementGas,
      ),
    if (hold > 0)
      PropagationSegment(
        startDepthMetres: targetDepthMetres,
        endDepthMetres: targetDepthMetres,
        durationMin: hold,
        breathing: levelGas,
      ),
  ]);
}
