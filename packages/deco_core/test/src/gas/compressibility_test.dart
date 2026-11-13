import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  const step = RecordedCompressibility20C.stepBar;
  test(
    'all recorded nodes are preserved; interpolation never indexes below zero',
    () {
      final data =
          jsonDecode(
                File(
                  'test/fixtures/parameters/z-observed.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final tables = data['tables'] as Map<String, dynamic>;
      for (final gas in ZGas.values) {
        final values = (tables[gas.name] as List).cast<num>();
        expect(RecordedCompressibility20C.atPressureBar(gas, 0), 1);
        for (var i = 0; i < 40; i++) {
          expect(
            RecordedCompressibility20C.atPressureBar(gas, (i + 1) * step),
            closeTo(values[i], 1e-14),
          );
        }
        for (final pressure in [
          6.889999999,
          6.89,
          6.890000001,
          step - 1e-9,
          step,
          step + 1e-9,
        ]) {
          final actual = RecordedCompressibility20C.atPressureBar(
            gas,
            pressure,
          );
          final expected = pressure <= step
              ? 1 + (values[0] - 1) * pressure / step
              : values[0] + (values[1] - values[0]) * (pressure - step) / step;
          expect(actual, closeTo(expected, 1e-14));
        }
      }
    },
  );
  test(
    'extrapolation is continuous and explicit rather than a hidden clamp',
    () {
      for (final gas in ZGas.values) {
        final edge = RecordedCompressibility20C.atPressureBar(gas, 40 * step);
        final above = RecordedCompressibility20C.atPressureBar(
          gas,
          40 * step + 1,
        );
        expect(above, greaterThan(edge));
        expect(
          RecordedCompressibility20C.atPressureBar(gas, 40 * step + 1e-8),
          closeTo(edge, 1e-10),
        );
      }
      for (final invalid in [-1.0, double.nan, double.infinity]) {
        expect(
          () => RecordedCompressibility20C.atPressureBar(ZGas.oxygen, invalid),
          throwsA(isA<CalculationFailure>()),
        );
      }
    },
  );
}
