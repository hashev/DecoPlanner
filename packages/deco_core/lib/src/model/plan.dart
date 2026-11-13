import '../numerics/failure.dart';
import '../units/units.dart';
import 'gas.dart';
import 'json.dart';
import 'request.dart';

const calculationModelVersion = 'deco-core-calculation-v1-dev';

final class BailoutRequest {
  BailoutRequest({
    required this.id,
    required this.sourceDiveId,
    required this.runtimeMin,
    required this.initialOcGas,
    Iterable<GasSwitch> switches = const [],
  }) : switches = List.unmodifiable(switches) {
    if (id.isEmpty || sourceDiveId.isEmpty) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Bailout identity is required.',
      );
    }
    requireFinite(runtimeMin, 'bailout runtimeMin', nonnegative: true);
    if (this.switches.any((s) => s.breathing.mode != BreathingMode.oc)) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Bailout switches must be OC.',
      );
    }
  }
  final String id, sourceDiveId;
  final double runtimeMin;
  final Gas initialOcGas;
  final List<GasSwitch> switches;
  Map<String, Object?> toJson() => {
    'id': id,
    'sourceDiveId': sourceDiveId,
    'runtimeMin': runtimeMin,
    'initialOcGas': initialOcGas.toJson(),
    'switches': switches.map((s) => s.toJson()).toList(),
  };
  factory BailoutRequest.fromJson(Map<String, Object?> json) => BailoutRequest(
    id: stringValue(json['id'], 'id'),
    sourceDiveId: stringValue(json['sourceDiveId'], 'sourceDiveId'),
    runtimeMin: doubleValue(json['runtimeMin'], 'runtimeMin'),
    initialOcGas: Gas.fromJson(
      objectValue(json['initialOcGas'], 'initialOcGas'),
    ),
    switches: listValue(
      json['switches'],
      'switches',
    ).map((s) => GasSwitch.fromJson(objectValue(s, 'switch'))),
  );
}

final class PlanRequest {
  PlanRequest({
    required this.revision,
    required Iterable<DiveRequest> dives,
    Iterable<BailoutRequest> bailouts = const [],
    this.modelVersion = calculationModelVersion,
  }) : dives = List.unmodifiable(dives),
       bailouts = List.unmodifiable(bailouts) {
    if (revision < 0 || modelVersion != calculationModelVersion) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Unsupported model version or invalid revision.',
      );
    }
    final ids = this.dives.map((d) => d.id).toSet();
    if (this.dives.isEmpty ||
        ids.length != this.dives.length ||
        this.bailouts.map((b) => b.id).toSet().length != this.bailouts.length) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Plan needs dives and unique identities.',
      );
    }
    for (final bailout in this.bailouts) {
      if (ids.contains(bailout.id)) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Bailout and dive identities must be distinct.',
        );
      }
      if (!ids.contains(bailout.sourceDiveId)) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Bailout source does not exist.',
        );
      }
    }
  }
  final int revision;
  final String modelVersion;
  final List<DiveRequest> dives;
  final List<BailoutRequest> bailouts;
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'modelVersion': modelVersion,
    'revision': revision,
    'dives': dives.map((d) => d.toJson()).toList(),
    'bailouts': bailouts.map((b) => b.toJson()).toList(),
  };
  factory PlanRequest.fromJson(Map<String, Object?> json) {
    if (intValue(json['schemaVersion'], 'schemaVersion') != 1) {
      invalidJson('schemaVersion');
    }
    return PlanRequest(
      revision: intValue(json['revision'], 'revision'),
      modelVersion: stringValue(json['modelVersion'], 'modelVersion'),
      dives: listValue(
        json['dives'],
        'dives',
      ).map((d) => DiveRequest.fromJson(objectValue(d, 'dive'))),
      bailouts: listValue(
        json['bailouts'],
        'bailouts',
      ).map((b) => BailoutRequest.fromJson(objectValue(b, 'bailout'))),
    );
  }
}
