import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

CalculationSettings settings(DecompressionModel model) => CalculationSettings(
  model: model,
  pressure: PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  ),
  stopGrid: StopGrid.metric(),
  gradientFactors: GradientFactors(low: .3, high: .85),
);
DiveRequest request(DecompressionModel model, {bool ccr = false}) =>
    DiveRequest(
      id: 'range-source',
      settings: settings(model),
      levels: [
        Level(
          depthMetres: 30,
          durationMin: 20,
          breathing: ccr
              ? BreathingGas.ccr(Gas(oxygen: .21), 1.3)
              : BreathingGas.oc(Gas(oxygen: .21)),
        ),
      ],
      switches: [
        GasSwitch(depthMetres: 6, breathing: BreathingGas.oc(Gas(oxygen: 1))),
      ],
    );
void main() {
  test('inclusive aligned axes avoid accumulation and validate bounds', () {
    final axis = RangeAxis(first: .1, last: .4, step: .1);
    expect(axis.length, 4);
    expect(axis.at(3), .4);
    expect(() => axis.at(-1), throwsRangeError);
    expect(() => axis.at(4), throwsRangeError);
    for (final values in [
      [0.0, 1.0, 0.0],
      [2.0, 1.0, 1.0],
      [0.0, 1.0, .3],
      [0.0, 10000.0, 1.0],
      [0.0, double.infinity, 1.0],
    ]) {
      expect(
        () => RangeAxis(first: values[0], last: values[1], step: values[2]),
        throwsA(isA<CalculationFailure>()),
      );
    }
  });
  for (final model in DecompressionModel.values) {
    test('$model grid retains every exact full calculation', () {
      final source = request(model);
      final cells = calculateRange(
        source: source,
        depths: RangeAxis(first: 27, last: 30, step: 3),
        durations: RangeAxis(first: 18, last: 20, step: 2),
        variants: RangeVariant.values,
        budget: CalculationBudget(
          maxIterations: 1200000,
          maxElapsed: const Duration(seconds: 30),
        ),
      ).toList();
      expect(cells.length, 12);
      for (final cell in cells) {
        expect(cell.failure, isNull);
        final independentCall = model == DecompressionModel.vpmB
            ? calculateVpm(cell.request)
            : calculateBuhlmann(cell.request);
        expect(cell.result!.toJson(), independentCall.toJson());
        expect(
          cell.request.switches.length,
          cell.variant == RangeVariant.base ? 1 : 0,
        );
        expect(cell.result!.segments.last.physical.endDepthMetres, 0);
      }
      expect(source.levels.single.depthMetres, 30);
      expect(source.levels.single.durationMin, 20);
      expect(source.switches.length, 1);
    });
    test(
      '$model bailout cells keep individual failures and successful neighbours',
      () {
        final source = request(model, ccr: true);
        final branch = BailoutRequest(
          id: 'escape',
          sourceDiveId: source.id,
          runtimeMin: 19,
          initialOcGas: Gas(oxygen: .21),
        );
        final cells = calculateRange(
          source: source,
          bailout: branch,
          depths: RangeAxis(first: 30, last: 30, step: 1),
          durations: RangeAxis(first: 5, last: 20, step: 15),
        ).toList();
        expect(cells.first.failure, isNotNull);
        expect(cells.first.result, isNull);
        expect(cells.last.failure, isNull);
        final exact = model == DecompressionModel.vpmB
            ? calculateVpmBailout(cells.last.request, branch)
            : calculateBuhlmannBailout(cells.last.request, branch);
        expect(cells.last.result!.toJson(), exact.toJson());
      },
    );
  }
  test('range is lazy, cancellable and globally bounded', () {
    var cancelled = false;
    final source = request(DecompressionModel.buhlmannB);
    Iterable<RangeCell> grid({CalculationBudget? budget, int max = 1000}) =>
        calculateRange(
          source: source,
          depths: RangeAxis(first: 24, last: 30, step: 3),
          durations: RangeAxis(first: 10, last: 20, step: 10),
          maximumCells: max,
          budget: budget,
        );
    final iterator = grid(
      budget: CalculationBudget(isCancelled: () => cancelled),
    ).iterator;
    expect(iterator.moveNext(), isTrue);
    cancelled = true;
    expect(
      () => iterator.moveNext(),
      throwsA(
        isA<CalculationFailure>().having(
          (e) => e.code,
          'code',
          CalculationFailureCode.cancelled,
        ),
      ),
    );
    expect(() => grid(max: 5).toList(), throwsA(isA<CalculationFailure>()));
    expect(
      () => grid(budget: CalculationBudget(maxIterations: 1)).toList(),
      throwsA(
        isA<CalculationFailure>().having(
          (e) => e.code,
          'code',
          CalculationFailureCode.budgetExceeded,
        ),
      ),
    );
  });
}
