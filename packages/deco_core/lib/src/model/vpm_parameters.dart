import '../numerics/failure.dart';
import '../units/units.dart';
import 'json.dart';

final class VpmParameters {
  VpmParameters({
    this.version = 'vpmb-decoplanner-parameters-v1',
    this.nitrogenRadiusMetres = .45e-6,
    this.heliumRadiusMetres = .55e-6,
    this.surfaceTension = .0179,
    this.skinCompression = .257,
    this.onsetImpermeabilityBar = 8.2 * Units.barPerAta,
    this.lambdaPascalMinutes = 6500 / 33 * 101325,
    this.regenerationMin = 20160,
    this.otherGasesBar = 102 / 760 * Units.barPerAta,
    this.criticalVolumeEnabled = true,
  }) {
    if (version.isEmpty) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'VPM parameter version is required.',
      );
    }
    for (final entry in {
      'nitrogenRadiusMetres': nitrogenRadiusMetres,
      'heliumRadiusMetres': heliumRadiusMetres,
      'surfaceTension': surfaceTension,
      'skinCompression': skinCompression,
      'onsetImpermeabilityBar': onsetImpermeabilityBar,
      'lambdaPascalMinutes': lambdaPascalMinutes,
      'regenerationMin': regenerationMin,
      'otherGasesBar': otherGasesBar,
    }.entries) {
      requireFinite(entry.value, entry.key, nonnegative: true);
      if (entry.value == 0) {
        throw CalculationFailure(
          CalculationFailureCode.invalidInput,
          '${entry.key} must be positive.',
        );
      }
    }
    if (skinCompression <= surfaceTension) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Skin compression must exceed surface tension.',
      );
    }
  }
  final String version;
  final double nitrogenRadiusMetres,
      heliumRadiusMetres,
      surfaceTension,
      skinCompression;
  final double onsetImpermeabilityBar,
      lambdaPascalMinutes,
      regenerationMin,
      otherGasesBar;
  final bool criticalVolumeEnabled;
  double radiusScale(int conservatism) {
    const scales = [1.0, 1.1, 1.15, 1.25, 1.35];
    if (conservatism < 0 || conservatism >= scales.length) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'VPM conservatism must be0–4.',
      );
    }
    return scales[conservatism];
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'nitrogenRadiusMetres': nitrogenRadiusMetres,
    'heliumRadiusMetres': heliumRadiusMetres,
    'surfaceTension': surfaceTension,
    'skinCompression': skinCompression,
    'onsetImpermeabilityBar': onsetImpermeabilityBar,
    'lambdaPascalMinutes': lambdaPascalMinutes,
    'regenerationMin': regenerationMin,
    'otherGasesBar': otherGasesBar,
    'criticalVolumeEnabled': criticalVolumeEnabled,
  };
  factory VpmParameters.fromJson(Map<String, Object?> json) {
    double number(String key) => doubleValue(json[key], key);
    return VpmParameters(
      version: stringValue(json['version'], 'version'),
      nitrogenRadiusMetres: number('nitrogenRadiusMetres'),
      heliumRadiusMetres: number('heliumRadiusMetres'),
      surfaceTension: number('surfaceTension'),
      skinCompression: number('skinCompression'),
      onsetImpermeabilityBar: number('onsetImpermeabilityBar'),
      lambdaPascalMinutes: number('lambdaPascalMinutes'),
      regenerationMin: number('regenerationMin'),
      otherGasesBar: number('otherGasesBar'),
      criticalVolumeEnabled: boolValue(
        json['criticalVolumeEnabled'],
        'criticalVolumeEnabled',
      ),
    );
  }
}
