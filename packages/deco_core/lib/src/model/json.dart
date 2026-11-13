import '../numerics/failure.dart';

Never invalidJson(String field) => throw CalculationFailure(
  CalculationFailureCode.invalidInput,
  'Invalid JSON field: $field.',
);
Map<String, Object?> objectValue(Object? value, String field) {
  if (value is! Map<String, Object?>) invalidJson(field);
  return value;
}

List<Object?> listValue(Object? value, String field) {
  if (value is! List<Object?>) invalidJson(field);
  return value;
}

double doubleValue(Object? value, String field) {
  if (value is! num || !value.isFinite) invalidJson(field);
  return value.toDouble();
}

int intValue(Object? value, String field) {
  if (value is! int) invalidJson(field);
  return value;
}

String stringValue(Object? value, String field) {
  if (value is! String || value.isEmpty) invalidJson(field);
  return value;
}

bool boolValue(Object? value, String field) {
  if (value is! bool) invalidJson(field);
  return value;
}

T enumValue<T extends Enum>(Object? value, List<T> values, String field) {
  for (final option in values) {
    if (option.name == value) return option;
  }
  return invalidJson(field);
}
