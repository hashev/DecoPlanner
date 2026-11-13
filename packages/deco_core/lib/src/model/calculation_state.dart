import '../oxygen/oxygen.dart';
import '../tissues/tissues.dart';
import 'json.dart';
import 'vpm_state.dart';

final class CalculationState {
  const CalculationState({
    required this.tissues,
    required this.oxygen,
    this.vpm,
  });
  final TissueState tissues;
  final OxygenState oxygen;
  final VpmState? vpm;
  Map<String, Object?> toJson() => {
    'tissues': tissues.toJson(),
    'oxygen': oxygen.toJson(),
    'vpm': vpm?.toJson(),
  };
  factory CalculationState.fromJson(Map<String, Object?> json) =>
      CalculationState(
        tissues: TissueState.fromJson(objectValue(json['tissues'], 'tissues')),
        oxygen: OxygenState.fromJson(objectValue(json['oxygen'], 'oxygen')),
        vpm: json['vpm'] == null
            ? null
            : VpmState.fromJson(objectValue(json['vpm'], 'vpm')),
      );
}
