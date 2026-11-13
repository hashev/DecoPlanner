import '../model/json.dart';

enum CalculationFailureCode {
  invalidInput,
  outsideModelDomain,
  invalidBracket,
  impossibleMixture,
  nonFinite,
  budgetExceeded,
  nonConvergence,
  cancelled,
}

final class CalculationFailure implements Exception {
  const CalculationFailure(this.code, this.message, {this.iterations = 0});

  final CalculationFailureCode code;
  final String message;
  final int iterations;

  Map<String, Object?> toJson() => {
    'code': code.name,
    'message': message,
    'iterations': iterations,
  };
  factory CalculationFailure.fromJson(Map<String, Object?> json) {
    final iterations = intValue(json['iterations'], 'iterations');
    if (iterations < 0) invalidJson('iterations');
    return CalculationFailure(
      enumValue(json['code'], CalculationFailureCode.values, 'code'),
      stringValue(json['message'], 'message'),
      iterations: iterations,
    );
  }
  @override
  String toString() => 'CalculationFailure(${code.name}): $message';
}
