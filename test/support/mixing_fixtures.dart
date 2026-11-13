import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/tools/mixing_view_model.dart';

MixingInput input({
  MixingMethod method = MixingMethod.partialPressure,
  bool real = false,
  Gas? initial,
  Gas? target,
  double start = 50,
  Gas? topUp,
}) => MixingInput(
  initialGas: initial ?? Gas(oxygen: .21),
  initialBar: start,
  targetGas: target ?? Gas(oxygen: .32),
  targetBar: 200,
  topUpGas: topUp ?? Gas(oxygen: .21),
  method: method,
  realGas: real,
  temperatureKelvin: 294,
  order: FillOrder.oxygenFirst,
  variant: ContinuousVariant.twoStreams,
  path: ContinuousPath.nitroxThenHeliair,
  maximumOxygenFraction: .4,
  maximumHeliumFraction: .6,
);
