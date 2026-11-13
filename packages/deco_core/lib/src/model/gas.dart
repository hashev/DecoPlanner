import '../numerics/failure.dart';
import '../units/units.dart';
import 'json.dart';

final class Gas {
  Gas({required this.oxygen, this.helium = 0}) {
    requireFinite(oxygen, 'oxygen', nonnegative: true);
    requireFinite(helium, 'helium', nonnegative: true);
    if (oxygen + helium > 1) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Gas fractions exceed one.',
      );
    }
  }
  final double oxygen;
  final double helium;
  double get nitrogen => 1 - (oxygen + helium);
  Map<String, Object> toJson() => {'oxygen': oxygen, 'helium': helium};
  factory Gas.fromJson(Map<String, Object?> json) => Gas(
    oxygen: doubleValue(json['oxygen'], 'oxygen'),
    helium: doubleValue(json['helium'], 'helium'),
  );
}

enum BreathingMode { oc, ccr }

/// A gas change is separate from a propagation segment. Bailout is represented
/// by a CCR prefix and OC suffix, never by changing the prefix's source state.
final class BreathingGas {
  BreathingGas.oc(this.gas) : mode = BreathingMode.oc, setpointBar = null;
  BreathingGas.ccr(this.gas, double setpoint)
    : mode = BreathingMode.ccr,
      setpointBar = setpoint {
    requireFinite(setpoint, 'setpointBar', nonnegative: true);
    if (setpoint == 0 || gas.nitrogen + gas.helium == 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'CCR needs a positive setpoint and inert diluent fraction.',
      );
    }
  }
  final Gas gas;
  final BreathingMode mode;
  final double? setpointBar;
  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'gas': gas.toJson(),
    'setpointBar': setpointBar,
  };
  factory BreathingGas.fromJson(Map<String, Object?> json) {
    final gas = Gas.fromJson(objectValue(json['gas'], 'gas'));
    final mode = enumValue(json['mode'], BreathingMode.values, 'mode');
    if (mode == BreathingMode.oc) {
      if (json['setpointBar'] != null) invalidJson('OC setpointBar');
      return BreathingGas.oc(gas);
    }
    return BreathingGas.ccr(
      gas,
      doubleValue(json['setpointBar'], 'setpointBar'),
    );
  }
}
