# VPM-B: параметры и физические примитивы

Версия параметров `vpmb-decoplanner-parameters-v1`: N2/He radius0.45/0.55µm,
консерватизм0–4 с множителями1/1.1/1.15/1.25/1.35, gamma0.0179,
gammaC0.257, impermeability onset8.2ATA, tau20160min,
other gases102mmHg. Lambda6500fsw·min =6500/33·101325Pa·min.
Не смешивать эту размерность с одним давлением. Все параметры находятся в
request JSON; внутри примитивов нет static unit/temperature/model state.

Кинетика — те же16компартментов1b, explicit PressureContext и BreathingGas.
При спуске permeable crushing=ambient−gas tension, включая other gases.
Пересечение порога ищется ограниченным solver по аналитическим тканям.
Impermeable cubic решается по безразмерному x=R/Ronset: иначе допуск1e−10
к микроскопическому dimensional polynomial ошибочно принял бы любой радиус.
Используются adjusted initial radii, корректный onset state и maxima каждой
ткани/газа. Неизвестное onset state не подменяется0.

Regeneration сохраняет отдельные regenerated radii/adjusted crushing/initial и
current gradients. Ratio алгебраически сокращён до(Rcrushed/Rregen)·exp(−t/tau),
что задаёт непрерывный предел при crush0 без0/0. В этой точке исходный радиус
сохраняется точно, без лишнего обратного преобразования1/(1/R).

## Независимые проверки

Пин первичной реализации:
[bwaite/vpmb](https://github.com/bwaite/vpmb/blob/bec938d84742e42dd43b574beec49ac26f6863ac/vpmb.py).
Источник выполняется без численных изменений; wrapper только снимает состояние
после crushing/regeneration/initial-gradient. Пять80m/30min случаевc0–c4 и
дополнительный200m/30min случай с impermeability сохранены отдельно.
Reference native sea surface1bar, vapour0.0493bar, gradient0.1bar/m;
эта конфигурация задана явно, не объявлена равной другим default surface.

```sh
local/oracles/python-env/bin/python tool/capture_vpm_physical_states.py
local/oracles/python-env/bin/python tool/capture_vpm_high_precision.py
```

Независимый mpmath70digits дополнительно решает onset/cubic по опубликованным
уравнениям и аналитическим тканям. Это позволяет проверять глубокую ветвь
с1e−8bar/1e−15m, сохранив родные приближённые состояния source oracle.
Для permeable c0–c4 дополнительно совпали все промежуточные вектора untouched
oracle с1e−10bar/1e−15m. Expected не читают Dart и не берутся из его фактического
выхода. Проверен отдельный аналитический zero-crushing limit.

Полный OC critical-volume search добавлен ниже. Высота/SI полной последовательности,
CCR/bailout проверены отдельными полными профилями ниже; multilevel ступенчатый спуск — отдельным набором, межуровневый подъём и повторный спуск проверены отдельным60-case набором.

## Градиенты и оценка декомпрессии

VpmGradients реализует current/Boyle ceiling, безразмерный Boyle root,
фазовый surface integral, critical-volume gradient update и критерий ANY≤1min.
Проверены c0–c4 kernel snapshots независимого источника. В первом записанном
Boyle-вызове только radius root уточнён mpmath70digits вместо source tolerance
1e−12m; provenance явно отличает это от untouched whole-schedule benchmark.
Дальнейшие source-native стадии сохраняются отдельно, не записываются из Dart.

```sh
local/oracles/python-env/bin/python tool/capture_vpm_gradient_kernels.py
```

Нулевые tissue gradients и граничные surface integrals обработаны аналитически:
равновесие даёт0, N2-only/He-only excess —1/k соответствующего газа.
Kernels дополнены полным bounded trial search, описанным ниже.

### Projected ascent: классификация

В bytecode legacy возвращаемый кандидат отбрасывается. В поиске1116реальных
source-native первых проверок кандидат не углубился;57source RootException
зарегистрированы отдельно, не названы успешными эталонами. Это не доказательство
для всех входов. [Машинный отчёт](projected-ascent-search.json) фиксирует объём.

Отдельный **синтетический** независимый helper test намеренно подал0m вместо
уже выбранного кандидата и получил51m. Он доказывает контракт защитного helper,
но не ошибку конкретного старого расписания. Стандартная семантика нового
helper использует проверенный возвращённый кандидат; изменённые реальные legacy
числа по этой причине пока не заявляются.

## Полный bounded OC search

`calculateVpm` выполняет реальную подготовку уровней, crushing/regeneration,
поиск начала deco zone по всем16тканям, projected ascent, trial расписания с
Boyle compensation, phase-volume интеграл и relaxation до ANY≤1min.
Принятое расписание переигрывается из состояния конца уровня; только финальный
проход накапливает CNS/OTU. Iteration/time/cancel budget общий для всех поисков.
Невозможный off-gassing gradient и невозможная первая остановка дают typed
nonConvergence, а не System.exit, фиктивное расписание или вечный цикл.

Нормализация oracle **явная**: round-to-even runtime/minStop+0.501; maximum
first stop среди trial итераций в Boyle; MP70digit уточняет cubic/deco-zone roots
по независимым уравнениям. Основной source SHA и численные override записаны.
Это independent normalized reference, не untouched source-native benchmark.
Sea-level calibration1bar для native80m и1.01325bar для legacy replacement
профилей сохраняются отдельно. O2-возможности primary oracle ограничены OC.
Газ выбирается на первой подходящей остановке, как в выбранном VPM, включая
первую остановку мельче заданной switch depth. Физический no-stop ascent
всегда присутствует. Round first stop сохраняет rint(ceiling/step+0.5), затем
применяет физическую last-stop сетку. Stop timing не является display rounding.

До сравнения назначены абсолютные пределы: segment/runtime1e−7min,
all tissue/pressure/gradient arrays1e−8bar, radius arrays1e−15m, phase times1e−7min.
Проверяются **все22вектора**, сохранённые16тканевые snapshots, скаляры, структура,
газ каждого сегмента, полная JSON serialization и независимость порядка запросов.
17полных OC профилей включают c0–c4, CV off, два no-stop, gas switches,
lost oxygen и last stop6m. Пять diagnostic oracle profiles воспроизводят
исходный swapped-gradient дефект; он не возвращается в продукт для совпадения.

```sh
local/oracles/python-env/bin/python tool/capture_vpm_schedules.py
```

## CCR и bailout

`calculateVpmBailout` возвращает отдельный CCR-prefix/OC-suffix результат.
Продолжение использует полное состояние точки отказа: tissues, CNS/OTU,
crushing, радиусы, actual gradients и VPM search context. Surface preparation
и SI выполняются только для источника. Частичный descent пересчитывает crushing
именно до точки отказа. Частичный ascent пересчитывает actual gradient и не
подмешивает градиент ещё не пройденного конца сегмента. Оба расчёта делят budget;
исходный запрос и результат сохраняются. Пока источник пересчитывается внутри
API, чтобы исключить передачу устаревшего состояния.

`vpmb-ccr-bailout-normalized.json`: 30 независимых нормализованных профилей c0–c4,
CCR с/без переключений дилюента/SP, bailout на спуске, его границе и выдержке.
Проверяются весь prefix crushing/radii, каждый segment gas/SP/time/tissues,
все22 конечных bubble-вектора, saved tissue snapshots и скаляры, CNS/OTU по
независимой quadrature. Отдельные тесты проверяют порядок запросов, отказ внутри
ascent/stop, отмену и ошибки.

Upstream OC-only oracle расширен **только** подготовкой inspired pressure:
для постоянного SP используется shifted vapour и normalized inert ratio.
Сам VPM crushing/regeneration/CV/Boyle/search исполняется исходным внешним кодом.
Это явно описанное CCR extension, а не заявление об upstream-native CCR.
Адаптер отклоняет физические сегменты, пересекающие dry ambient=SP; выбранные
профили этой границы не пересекают. Проверка CCR clipping имеется отдельно
на уровне кинетики. 30 полных metric/imperial multilevel descending профилей проверяют OC/CCR/bailout и c0–c4; дополнительно60upward/redescent профилей покрывают оба направления и реальные промежуточные остановки.
Altitude/SI CCR цепочки проверены отдельным набором ниже.

При переходе trial-deco→accepted-NDL сбрасывается scratch `decoPhaseVolumeMin`:
непринятая пробная выдержка не принадлежит итоговому расписанию. Отдельный NDL
выход upstream также пропускает surface actual gradient; адаптер применяет
собственный `calc_max_actual_gradient(0)` после финального подъёма независимо
от наличия пробных остановок. Операция max идемпотентна для обычных профилей.
Повторный захват прежних22 OC/diagnostic профилей сохраняет прежние SHA-256.

```sh
local/oracles/python-env/bin/python tool/capture_vpm_ccr.py
```

## Полные OC высота и повторные погружения

`vpmb-full-altitude-repetitive.json` содержит независимые полные расписания
2000m acclimatized/travel и8848m travel, а также две последовательные OC45m/25min
с21/35 и switch50%/O2 послеSI0/45/60/180/1440. Первичные altitude/repetitive
методы source oracle выполняются без подмены численных формул. Зафиксированы
initial tissue/adjusted radii, каждый конечный segment state, полное конечное
bubble state и независимая Baker quadrature CNS/OTU. Продукт переносит состояние
через JSON перед повторным расчётом; предыдущее состояние не изменяется.

```sh
local/oracles/python-env/bin/python tool/capture_vpm_sequences.py
```

## Полные CCR/bailout высота и повторные погружения

`vpmb-ccr-altitude-repetitive.json` добавляет26 независимых сценариев:
CCR и bailout2000m acclimatized/travel и8848m travel;20цепочек CCR→CCR,
CCR→OC, CCR→bailout и bailout→CCR при SI0/45/60/180/1440. Каждый переход
передаётся через JSON; SI0 сохраняет identity. Проверены initial tissues/radii,
все segment states,22конечных bubble-вектора/saved snapshots и CNS/OTU.
Пройденный источник не изменяется, full-state перенос не ограничивается N2/He.

Для altitude cases явно заданы постоянные SP.7bar на2000m и SP.2bar на8848m:
это держит все trial ascents внутри non-clipped области внешнего адаптера.
SI-цепочки используют обычный профиль с SP1.3/1.4/.7bar. Это границы данного
независимого набора; clipping отдельно проверен independent kinetic quadrature.

Bailout до начала финального подъёма рассчитывает исходные уровни и продолжает
из точки отказа без ненужного CCR-хвоста. Общий лимит100000 evaluations сохранён.
Это существенно для8848m: повторный расчёт всего CCR891.33min плюс OC escape
291.33min исчерпывал один budget; корректный OC escape укладывается в него.
При отказе во время CCR-подъёма полный source schedule по-прежнему нужен
для пройденного prefix и его VPM context.

```sh
local/oracles/python-env/bin/python tool/capture_vpm_ccr_sequences.py
```

Проверки закрывают scope5.4/5.5 совместно с OC-набором. Исходные JAR-исключения
сохранены отдельно и не переписаны.

Подробности нового набора: [VPM multilevel reference](vpm-multilevel-reference.md).

Partial ascent/redescent: [контракт и контроль](vpm-redescent-reference.md).
