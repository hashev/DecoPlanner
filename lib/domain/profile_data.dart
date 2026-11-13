import 'package:deco_core/deco_core.dart';

final class ProfilePoint {
  const ProfilePoint({
    required this.runtimeMin,
    required this.depthMetres,
    required this.state,
    required this.segmentIndex,
    this.continuesTrace = true,
  });
  final double runtimeMin, depthMetres;
  final CalculationState state;

  /// -1 is the initial physical surface point, never a fabricated tissue value.
  final int segmentIndex;
  final bool continuesTrace;
}

final class TissuePoint {
  const TissuePoint({
    required this.index,
    required this.nitrogenBar,
    required this.heliumBar,
    this.mValueBar,
    this.gradientFraction,
  });
  final int index;
  final double nitrogenBar, heliumBar;
  final double? mValueBar, gradientFraction;
}

final class ProfileData {
  ProfileData({required this.result, required this.settings})
    : points = List.unmodifiable([
        ProfilePoint(
          runtimeMin: 0,
          depthMetres: 0,
          state: result.initialState,
          segmentIndex: -1,
        ),
        for (var i = 0; i < result.segments.length; i++)
          ProfilePoint(
            runtimeMin: result.segments[i].endMin,
            depthMetres: result.segments[i].physical.endDepthMetres,
            state: result.segments[i].endState,
            segmentIndex: i,
          ),
      ]);
  final CalculationResult result;
  final CalculationSettings settings;
  final List<ProfilePoint> points;
  List<ProfilePoint> visiblePoints({required bool ascentOnly}) {
    if (!ascentOnly) return points;
    final indices = <int>{};
    for (var i = 0; i < result.segments.length; i++) {
      final phase = result.segments[i].phase;
      if (phase == SegmentPhase.ascent || phase == SegmentPhase.decompression) {
        indices.add(i);
        indices.add(i + 1);
      }
    }
    return List.unmodifiable([
      for (final index in indices.toList()..sort())
        ProfilePoint(
          runtimeMin: points[index].runtimeMin,
          depthMetres: points[index].depthMetres,
          state: points[index].state,
          segmentIndex: points[index].segmentIndex,
          continuesTrace: connects(points[index], ascentOnly: true),
        ),
    ]);
  }

  bool connects(ProfilePoint point, {required bool ascentOnly}) {
    if (point.segmentIndex < 0) return false;
    final phase = result.segments[point.segmentIndex].phase;
    return !ascentOnly ||
        phase == SegmentPhase.ascent ||
        phase == SegmentPhase.decompression;
  }

  List<TissuePoint> tissues(ProfilePoint point) {
    final model = settings.model == DecompressionModel.vpmB
        ? null
        : BuhlmannModel(
            settings.model == DecompressionModel.buhlmannB
                ? BuhlmannCoefficients.b()
                : BuhlmannCoefficients.c(),
          );
    final ambient = result.pressure.ambientBar(point.depthMetres);
    return List.unmodifiable(
      List.generate(16, (index) {
        final state = point.state.tissues;
        final coefficients = model?.mixedCoefficients(state, index);
        final mValue = coefficients == null
            ? null
            : coefficients.a + ambient / coefficients.b;
        final denominator = mValue == null ? null : mValue - ambient;
        return TissuePoint(
          index: index + 1,
          nitrogenBar: state.nitrogenBar[index],
          heliumBar: state.heliumBar[index],
          mValueBar: mValue,
          gradientFraction: denominator == null || denominator == 0
              ? null
              : (state.nitrogenBar[index] + state.heliumBar[index] - ambient) /
                    denominator,
        );
      }),
    );
  }
}
