# Независимые численные источники

Все внешние реализации находятся исключительно в игнорируемом `local/oracles`.
Приложение не импортирует Python/C/C++/Java и не запускает эти процессы.
Публичные JSON — результаты внешнего исполнения с происхождением, а не копии
реализаций. Для каждого набора ниже отдельно указаны native conventions,
нормализация и пределы применимости.

Новые нормализованные наборы CCR/bailout: 18 Bühlmann B/C профилей
(`tool/capture_buhlmann_bailout.py`, независимая CCR ODE quadrature, внешний
DecoTengu и перебор stop grid) и30 VPM c0–c4 профилей
(`tool/capture_vpm_ccr.py`, внешний VPM с явно ограниченным constant-SP
inspiration adapter). Оба включают независимую Baker quadrature CNS/OTU.
Подробные соглашения и пределы описаны в [Bühlmann](buhlmann.md) и [VPM](vpm.md).
`tool/capture_vpm_ccr_sequences.py` дополнительно фиксирует26 полных CCR/bailout
altitude/SI сценариев с initial tissues/radii, полными bubble states и кислородом.
Altitudes явно используют SP.7bar на2000m и SP.2bar на8848m внутри non-clipped
области oracle adapter; SI-цепочки используют стандартный1.3/1.4/.7bar профиль.
`tool/capture_buhlmann_oc_schedules.py` фиксирует19 полных независимых OC
расписаний B/C, включая multilevel/imperial и gas/minimum/last-stop branches.
Здесь независимы и ткани, и поиск остановок; это шире прежнего tissue replay
на уже наблюдённом расписании.
`tool/capture_buhlmann_sequences.py` добавляет68 полных B/C altitude/SI сценариев
для OC/CCR/bailout. На высоте сохранён стандартный CCR SP1.3/1.4/.7bar с
независимой clipped-inspiration ODE quadrature; SI включает все0/45/60/180/1440.

## Bühlmann B/C

[DecoTengu](https://wrobell.dcmod.org/decotengu/) 0.14.1, отдельное приватное
Python-окружение. Модульные SHA-256 записаны в каждом JSON. B использует первую
ткань 1b, C — 1a; собственные исходные доли N2 и surface/vapor тоже записаны.
Установка и повторный захват из корня:

```sh
python3 -m venv local/oracles/python-env
local/oracles/python-env/bin/pip install decotengu==0.14.1
local/oracles/python-env/bin/python tool/capture_independent_references.py
```

Профиль: OC air, 30 m, runtime дна20 min, спуск10/подъём9 m/min, GF30/85.
Фиксируются полный список остановок, runtime и все 16 пар тканей.
Отличия соглашений нельзя устранять перезаписью результата под наше ядро.

## VPM-B

[Исходный проект](https://github.com/bwaite/vpmb), commit
`bec938d84742e42dd43b574beec49ac26f6863ac`. Поддерживается VPM-B, не исходный
VPM. Независимый Python исполняется без изменения численных исходников.

```sh
git clone https://github.com/bwaite/vpmb.git local/oracles/vpmb
git -C local/oracles/vpmb checkout bec938d84742e42dd43b574beec49ac26f6863ac
local/oracles/python-env/bin/python tool/capture_independent_references.py
```

Профиль автора `msw_simple`: OC trimix15/45, 80 m, runtime дна30 min.
Программа захвата проверяет **точное равенство** вывода авторскому expected.json
после удаления только времени запуска. SHA-256 обоих источников сохранены.
Полные финальные ткани, радиусы и native pressure также экспортированы.
Игнорируемые upstream поля setpoint удалены из запроса: этот oracle **OC-only**.
Этот native smoke case не проверяет высоту/повторные/CCR ветви; они проверяются
отдельными нормализованными наборами, перечисленными выше.

Дополнительный запуск C выполняется `python3 tool/build_vpmb_reference.py`;
на современном macOS переименовывается только конфликтующий символ strlcpy
в приватной копии, исходники и точные хеши преобразования сохраняются локально.
C-вывод не подменяет JSON эталона Python и не включается в приложение.

## Воспроизводимость

`tool/capture_independent_references.py` создаёт три файла в
`packages/deco_core/test/fixtures/independent`. Два последовательных запуска
должны давать те же SHA-256. Авторские fixtures и legacy_baseline не переписываются.
Нормализация режимов, высоты, SI и полевые допуски зафиксированы отдельно
в reference-normalization.md и numerical-fixtures.json.

## CCR ткани: Subsurface

Commit `7f2610cee4572ebc1795c48d054616a51d457eec`; заголовки libdivecomputer
`14f92934c0aedbba7a5aafe8915e8a96d944335c`. В приватных checkout численные
`deco.cpp` и `gas.cpp` компилируются без изменений. Наш harness задаёт только
режим/config plumbing, начальное давление и один CCR hold. Qt6 и clang нужны
лишь для воспроизведения эталона, не для приложения:

```sh
python3 tool/capture_subsurface_tissues.py
```

В двух JSON записаны B/VPM vapour, все 16 N2/He и хеши численных исходников и
harness. Это **проверка распространения тканей при постоянном CCR**, не полный
план и не независимый контроль bubble-state. Для tissue harness достаточно
приватных заголовков. Полная сборка и отдельный захват source-native планов
теперь доступны через `tool/build_subsurface_reference.py` и
`tool/capture_subsurface_plans.py`; их соглашения не подменяют нормализованные
регрессии. Начальная доля N2 upstream равна0.781.

У `factor()` upstream округлённый коэффициент ln(2)/60 =0.01155245301.
Dart использует `math.ln2`. Поэтому исходный тест с фиксированным1e-12bar
неверно предполагал одинаковые константы и был заменён **аналитическим**
ограничением ошибки: `|Pinspired-Pinitial| * duration * |deltaLn2| / halfTime`
плюс1e-14bar для арифметики. Эта граница вычисляется из входов/исходной
константы, не из полученного Dart-расхождения; снимки oracle не изменены.

## Полные CCR/bailout: Subsurface native planner

Пин тот же `7f2610cee4572ebc1795c48d054616a51d457eec`, требуемый **fork** libdc
из git submodule: `469f28d17ed05112496f176006eccccc9f8fdc73`.
Homebrew libdivecomputer0.9.0 оказался API-несовместим с этим checkout;
воспроизведение использует подмодуль, собранный в приватный local prefix.
На текущем Mac для сборки reference установлены hidapi/autoconf/automake/libtool;
это не Flutter runtime зависимости. Требуются также установленные CMake,
pkg-config, Qt6 и native libraries, которые обнаруживает CMake/pkg-config.

```sh
git -C local/oracles/subsurface submodule update --init --depth 1 libdivecomputer
python3 tool/build_subsurface_reference.py
python3 tool/capture_subsurface_plans.py
```

Build/capture helpers проверяют commits и отсутствие изменений core/deco.cpp,
core/planner.cpp. В ходе настройки доступны только native CLI компоненты;
GUI Subsurface не запускается. Link flags берутся из действительных pkg-config
зависимостей, а не из подмены численного кода. Собственные harness только задают
входы и выгружают native точки/ткани. Исходник внешнего ядра в продукт не копируется.

Получены4source-native полных плана60m/20min, diluent20/21, SP1.3bar:
C1b CCR1980s, C1b bailout3060s, VPM-B CCR2040s, VPM-B bailout3060s.
C1b bailout совпал с авторским TestPlan::testCcrBailoutGasSelection (51min).
У остальных не заявляется отдельный author-owned expected. Subsurface комментарий
в header упоминает B, но действительные N2a соответствуют **C1b**; label фиксирует
проверенную таблицу. Его VPM параметры/консерватизм и GF/stop/time conventions
нельзя автоматически объявлять равными нашему варианту. Эти JSON пока не
нормализованные product regression; роль этих дополнительных наблюдений и согласование основных источников описаны в [normalization contract](reference-normalization.md).

## Continuous blending: независимый LP

486 ideal/real cases двух вариантов и обоих путей variant1 проверены через
SciPy1.18.1/HiGHS dual simplex, отдельно от Dart vertex enumeration.
Generator, binary hashes, exact command и заранее назначенные допуски —
[смешивание](mixing.md#continuous-blending), fixture `continuous-highs.json`.
Original normal control сохранён отдельно; исправленные caps не принимаются
по старому результату.

## Расход по независимым расписаниям

`gas-usage-quadrature.json`: 37 B/C OC/CCR/bailout профилей, mpmath 70-digit
quadrature, provenance исходных расписаний и генератора, допуск 1e-8 L.
Повторить: `local/oracles/python-env/bin/python tool/capture_usage_reference.py`.
Подробности и границы модели: [расход/диапазоны](gas-usage-range.md).

## Многоуровневый VPM, metric/imperial

30 независимых полных ступенчатых спусков OC/CCR/bailout, c0–c4;
все сегменты/ткани/bubble state и oxygen quadrature. Канонические физические
сетки3m и10ft=3.048m. Отдельно сохраняется усечённая upstream display depth.
[Нормализация и область descending profiles](vpm-multilevel-reference.md).
Генератор не использует Dart output;31 focused tests проходят на default budget.

Дополнительно60 независимых VPM partial-ascent/redescent profiles: обоими
наборами единиц, всеми c0–c4, OC/CCR/bailout, с/без реальных промежуточных
остановок. Полный state/oxygen/runtime и повторный захват побайтно совпали.
[Описание](vpm-redescent-reference.md); [общий контракт](reference-normalization.md).

Полный [реестр ролей, SHA и полевых контрактов](numerical-fixtures.md);
[B/C CCR/bailout 10 ft](buhlmann-imperial-reference.md).
