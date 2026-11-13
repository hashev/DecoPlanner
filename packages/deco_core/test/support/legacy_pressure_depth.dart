import 'package:deco_core/deco_core.dart';

/// Only the research boundary uses pressure-depth units. Values here come from
/// contract.md, not from a global display-units flag in the application.
final class LegacyPressureDepth {
  LegacyPressureDepth({required this.depthUnitsPerAta}) {
    requireFinite(depthUnitsPerAta, 'depthUnitsPerAta', nonnegative: true);
    if (depthUnitsPerAta == 0) throw ArgumentError.value(depthUnitsPerAta);
  }
  factory LegacyPressureDepth.metric() =>
      LegacyPressureDepth(depthUnitsPerAta: 10.1325);
  factory LegacyPressureDepth.imperial() =>
      LegacyPressureDepth(depthUnitsPerAta: 33);
  final double depthUnitsPerAta;
  double toBar(double native) => Units.ataToBar(native / depthUnitsPerAta);
  double fromBar(double bar) => Units.barToAta(bar) * depthUnitsPerAta;
}
