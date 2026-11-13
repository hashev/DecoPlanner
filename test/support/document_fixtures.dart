import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/models/planner_document.dart';

PlannerDocument documentFixture({
  String id = 'plan-a',
  String name = 'План А',
  int revision = 1,
}) {
  final settings = CalculationSettings(
    model: DecompressionModel.vpmB,
    pressure: PressureContext(
      surfaceBar: 1.01325,
      waterVapourBar: .0493,
      barPerMetre: .1,
    ),
    stopGrid: StopGrid.metric(),
    gradientFactors: GradientFactors(low: .3, high: .85),
  );
  final source = DiveRequest(
    id: 'source',
    settings: settings,
    levels: [
      Level(
        depthMetres: 45,
        durationMin: 25,
        breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.8),
      ),
    ],
  );
  final branch = BailoutRequest(
    id: 'escape',
    sourceDiveId: source.id,
    runtimeMin: 12.5,
    initialOcGas: Gas(oxygen: .21, helium: .35),
    switches: [
      GasSwitch(depthMetres: 21, breathing: BreathingGas.oc(Gas(oxygen: .5))),
      GasSwitch(depthMetres: 6, breathing: BreathingGas.oc(Gas(oxygen: 1))),
    ],
  );
  final result = calculateVpm(source),
      escape = calculateVpmBailout(source, branch);
  final next = DiveRequest(
    id: 'next',
    settings: settings,
    surfaceIntervalMin: 45,
    initialState: result.finalState,
    levels: [
      Level(
        depthMetres: 24,
        durationMin: 20,
        breathing: BreathingGas.oc(Gas(oxygen: .21)),
      ),
    ],
  );
  final plan = PlanRequest(
    revision: revision,
    dives: [source, next],
    bailouts: [branch],
  );
  final results = {
    'source': StoredCalculation(
      inputRevision: 1,
      dependencyVersion: 'initial',
      result: result,
    ),
    'escape': StoredCalculation(
      inputRevision: 1,
      dependencyVersion: 'source:1',
      result: escape,
    ),
  };
  return PlannerDocument(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026, 11, 13),
    modifiedAt: DateTime.utc(2026, 11, 13, 0, revision),
    plan: plan,
    results: results,
    preferences: PlannerPreferences(
      units: DisplayUnits.imperial,
      theme: DocumentTheme.dark,
      textScale: 1.5,
    ),
    gases: [
      GasPreset(
        id: 'tx2135',
        name: 'Дилюент 21/35',
        gas: Gas(oxygen: .21, helium: .35),
      ),
    ],
    tanks: [
      TankPreset(
        id: 'double12',
        name: 'Спарка 2×12',
        waterLitres: 24,
        workingBar: 232,
      ),
    ],
    settingsPresets: [
      SettingsPreset(id: 'vpm-c2', name: 'VPM c2', settings: settings),
    ],
    comparisons: [
      ComparisonSnapshot(
        id: 'baseline',
        name: 'Сравнение А',
        capturedAt: DateTime.utc(2026, 11, 13),
        plan: plan,
        results: results,
      ),
    ],
    toolDrafts: {
      'mod': {'oxygen': 'abc', 'helium': '', 'po2': '1,4'},
      'mix': {'targetBar': 'NaN'},
    },
  );
}
