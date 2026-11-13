# Контракты deco_core

Pure Dart, без Flutter/JVM/файлов/сети. Экспорт — lib/deco_core.dart.
Канонические единицы: m, min, bar, fractions0..1; радиусыm; lambdaPa·min.
Преобразование отображения/исследовательских единиц выполняется на границе.

- PlanRequest: schemaVersion1, calculationModelVersion, revision, непустая
  последовательность DiveRequest и отдельные BailoutRequest с sourceDiveId.
- DiveRequest: immutable уровни/переключения, settings, SI и необязательное полное
  initialState. Level хранит фактический BreathingGas; CCR setpoint вbar.
- CalculationSettings: B/C/VPM, физический pressure context/stop grid, GF, скорости,
  минимум, travel convention, RMV/OCR, высотные входы, VPM параметры и conservatism.
  AltitudeSettings сохраняет исходные высоты и travel/wait. Подготовка поверхности
  и полный state transfer проверены независимыми B/C/VPM OC/CCR/bailout профилями.
- CalculationState: TissueState, OxygenState, optional VpmState.
- TissueState: ровно16 N2 и16 He, без округления.
- VpmState:22вектора радиусов/crushing/градиентов/phase/onset, три сохранённых
  tissue snapshots (segment/ascent/deco start), surface/vapour/other pressure,
  first stop/deco-zone/runtime и counters. Параметры отдельно в запросе.
- Segment: физическое движение/hold, phase, raw start/end time и endState.
  CalculationResult сохраняет начальный state и непрерывные сегменты; finalState,
  runtime и Stop-представление выводятся из них, без второй изменяемой копии.
- CalculationFailure: code/message/iterations и JSON. InvalidInput, outside domain,
  impossible mixture, nonfinite, budget, bracket и nonconvergence различаются.

Все коллекции скопированы и закрыты для изменения. Конструкторы и JSON читатели
отклоняют неверную форму, длины/диапазоны, NaN/Infinity и отсутствующие обязательные
поля; unknown schema/model version не принимается. JSON сохраняет исходные double,
а не форматированный UI текст. Результаты проверяют непрерывность времени/глубины
и согласованность счётчиков длительности.

CNS — число либо явная недоступность с типизированной причиной. null без причины
невалиден. Неизвестный CNS нельзя превращать в0 при JSON/SI; OTU хранится отдельно.
Политика и решение владельца описаны в [oxygen.md](oxygen.md).

Готовность API и готовность всех режимов различаются. `calculateBuhlmann`,
`calculateVpm` и отдельные `calculateBuhlmannBailout`/`calculateVpmBailout`
выполняют реальный bounded calculation; production worker поддерживает оба вида
запросов. CCR-prefix сохраняет ткани/кислород/VPM state, OC escape получает свой
ID. B/C/VPM altitude/SI OC/CCR/bailout проверены отдельными наборами.
Общая multilevel/imperial матрица остаётся открытой, особенно для VPM.

Тесты контрактов: независимые уникальные значения каждого VPM вектора,
полный nested JSON round-trip, custom VPM/altitude settings, bailout identity,
result/unknown CNS и отказ на повреждённых/нечисловых данных.

## Контекст высоты в результате

CalculationResult сохраняет фактический PressureContext отдельно от настроек
документа. При altitude initialization surfaceBar получается из явно заданной
sea-level calibration и высоты; графики и повторное чтение результата должны
использовать этот контекст. Bühlmann adapter применяет подготовку поверхности
и SI до первого сегмента; переданное initialState не переинициализируется
равновесием. B/C и VPM integration подтверждены независимыми полными
OC/CCR/bailout altitude/SI наборами с intermediate state snapshots.

`continuousMix` возвращает ContinuousRecipe с pure prefill и1/2 feed streams,
их составами/количествами и промежуточными давлениями. Максимальные O2/He доли
проверяются совместно с retained gas; варианты/допуски — [mixing](mixing.md).

`calculateGasUsage`, `TankRequirement`, `TimeRatio` и `calculateRange`:
[определения фаз, расход без резервов, группировки и границы диапазона](gas-usage-range.md).
