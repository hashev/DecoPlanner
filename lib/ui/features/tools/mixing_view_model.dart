import 'dart:isolate';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/foundation.dart';

enum MixingMethod { partialPressure, continuous }

enum MixingStatus { draft, calculating, ready, stale, failed }

@immutable
final class MixingInput {
  const MixingInput({
    required this.initialGas,
    required this.initialBar,
    required this.targetGas,
    required this.targetBar,
    required this.topUpGas,
    required this.method,
    required this.realGas,
    required this.temperatureKelvin,
    required this.order,
    required this.variant,
    required this.path,
    required this.maximumOxygenFraction,
    required this.maximumHeliumFraction,
  });
  final Gas initialGas, targetGas, topUpGas;
  final double initialBar,
      targetBar,
      temperatureKelvin,
      maximumOxygenFraction,
      maximumHeliumFraction;
  final MixingMethod method;
  final bool realGas;
  final FillOrder order;
  final ContinuousVariant variant;
  final ContinuousPath path;
}

@immutable
final class MixingResult {
  const MixingResult({required this.input, this.partial, this.continuous});
  final MixingInput input;
  final FillRecipe? partial;
  final ContinuousRecipe? continuous;
  double get retainedBar =>
      partial?.retainedPressureBar ?? continuous!.retainedPressureBar;
  double get drainedBar =>
      partial?.drainedPressureBar ?? continuous!.drainedPressureBar;
  FillRecipe get costRecipe {
    if (partial != null) return partial!;
    final source = continuous!;
    // Cost consumes purchased source amounts, not final blended feed composition.
    return FillRecipe(
      retainedPressureBar: source.retainedPressureBar,
      drainedPressureBar: source.drainedPressureBar,
      retainedMolesPerLitre: source.retainedMolesPerLitre,
      oxygenMolesPerLitre: source.oxygenMolesPerLitre,
      heliumMolesPerLitre: source.heliumMolesPerLitre,
      topUpMolesPerLitre: source.airMolesPerLitre,
      targetMolesPerLitre: source.targetMolesPerLitre,
      steps: const [],
    );
  }
}

MixingResult calculateMixing(MixingInput input) {
  final eos = GasEquationOfState(
    realGas: input.realGas,
    temperatureKelvin: input.temperatureKelvin,
  );
  final budget = CalculationBudget(
    maxIterations: 100000,
    maxElapsed: const Duration(seconds: 3),
  );
  if (input.method == MixingMethod.partialPressure) {
    return MixingResult(
      input: input,
      partial: partialPressureMix(
        initialGas: input.initialGas,
        initialBar: input.initialBar,
        targetGas: input.targetGas,
        targetBar: input.targetBar,
        topUpGas: input.topUpGas,
        eos: eos,
        order: input.order,
        budget: budget,
      ),
    );
  }
  return MixingResult(
    input: input,
    continuous: continuousMix(
      initialGas: input.initialGas,
      initialBar: input.initialBar,
      targetGas: input.targetGas,
      targetBar: input.targetBar,
      eos: eos,
      variant: input.variant,
      path: input.path,
      maximumOxygenFraction: input.maximumOxygenFraction,
      maximumHeliumFraction: input.maximumHeliumFraction,
      budget: budget,
    ),
  );
}

Future<MixingResult> _runMixing(MixingInput input) =>
    Isolate.run(() => calculateMixing(input), debugName: 'gas-mixing');

final class MixingViewModel extends ChangeNotifier {
  MixingViewModel({Future<MixingResult> Function(MixingInput)? calculate})
    : _calculate = calculate ?? _runMixing;
  final Future<MixingResult> Function(MixingInput) _calculate;
  MixingStatus status = MixingStatus.draft;
  MixingResult? result;
  CalculationFailure? failure;
  int revision = 0;
  int? recipeRevision;
  bool _closed = false;
  bool get current =>
      status == MixingStatus.ready && recipeRevision == revision;
  void invalidate() {
    revision++;
    status = result == null ? MixingStatus.draft : MixingStatus.stale;
    failure = null;
    notifyListeners();
  }

  Future<void> calculate(MixingInput input) async {
    final captured = ++revision;
    status = MixingStatus.calculating;
    failure = null;
    notifyListeners();
    try {
      final answer = await _calculate(input);
      if (_closed || revision != captured) return;
      result = answer;
      recipeRevision = captured;
      status = MixingStatus.ready;
    } on CalculationFailure catch (error) {
      if (_closed || revision != captured) return;
      failure = error;
      status = MixingStatus.failed;
    } catch (_) {
      if (_closed || revision != captured) return;
      failure = const CalculationFailure(
        CalculationFailureCode.nonConvergence,
        'Calculation worker failed.',
      );
      status = MixingStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    revision++;
    super.dispose();
  }
}
