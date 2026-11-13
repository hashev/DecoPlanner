# Design

## Context

См. `proposal.md` для цели и объёма. Это реализация продукта, не ещё один макет и не Java-обёртка.

Исходное состояние: Git и Flutter-проект отсутствуют. В корне смешаны Windows-дистрибутив (`business/`, `runtime/`, `update/`, launch scripts), 54 MB анализа, авторские расчётные документы и UX-пакет. Восстановлены численные случаи и известные дефекты, но независимых успешных эталонов исправленных ветвей ещё нет. Требование пользователя: исправления и получение таких эталонов входят в эту работу, а не переносятся за границу готовности.

Текущий SDK прочитан из локального Flutter cache: Flutter 3.41.6 stable, Dart 3.11.4. Dart MCP обнаружил macOS как native target; Chrome не является целевой платформой этого изменения. iOS/Android/Windows runners нужны в проекте, но доступность их сборки/запуска ещё не подтверждена.

Основания: `docs/calculations/{contract,implementation-guide,limitations,validation}.md`, исходные fixtures/coefficient maps, `docs/ui/{screens,flows,design-system,flutter-handoff}.md`, шесть существующих основных спецификаций. Последние сохраняют историческое исследование и целевой UX; новая математика не переписывает факты о старом JAR.

## Goals / Non-Goals

**Goals:** получить приложение со всем описанным функциональным объёмом, чистым Dart-ядром и воспроизводимыми численными проверками; обеспечить работу из публичного набора без исследовательского архива; оставить понятные локальные команды вместо преждевременного CI/CD.

**Non-Goals:** двоичная совместимость с JAR, сохранение математических ошибок ради совпадения, clinical certification, резервная газовая модель, облако, лицензирование оригинала, поддержка Linux/web, подписанные установщики/магазины, GitHub remote/push и workflows. Выбор лицензии собственных исходников остаётся за владельцем; сторонние notices сохраняются, GPL/другой чужой исходник не копируется в приложение под неподходящей лицензией.

## Decisions

### 1. Корень — приложение, ядро — отдельный Dart-пакет

```text
pubspec.yaml, pubspec.lock, analysis_options.yaml, .metadata
lib/
  app/                     # bootstrap, composition, navigation
  data/                    # local documents, file/export adapters
  ui/core/                 # themes, shared input/status/chart components
  ui/features/             # plan, tools, settings + ViewModels
packages/deco_core/
  lib/src/{model,units,tissues,buhlmann,vpm,oxygen,gas,planning}/
  test/{fixtures,model,regression}/
test/                      # ViewModels, repositories, widgets, exports
integration_test/          # real end-to-end product flows
android/, ios/, macos/, windows/
assets/{fonts,help}/
docs/{ui,calculations,models,development}/
tool/                      # public audit/validation commands, not CI
openspec/                  # preserve current specs/history
local/reference/           # ignored; original directory structure
```

Root app depends on `deco_core` by relative path. Core has no Flutter, JavaFX, native FFI, network or file-system dependence; entry points accept immutable typed requests and return results/failures. Tests of core run with the Dart runner. UI/data use MVVM, `ChangeNotifier`/`Listenable`, constructor injection and explicit repositories following official `flutter-apply-architecture-best-practices`; no state-management/DI/codegen framework is needed initially. JSON contracts follow official serialization skill; unit tests follow official Dart testing skill and MCP runner.

Альтернатива — вся математика внутри Flutter widgets или рефлексия к JAR — мешает тестированию, мобильным сборкам и очистке публикуемого набора. Пакет ядра не является обещанием отдельной публикации на pub.dev.

Создавать scaffold сначала в пустом временном каталоге через Dart/Flutter MCP, затем переносить только согласованные файлы. Не запускать генератор поверх существующих документов без проверки коллизий. Базовый SDK не обновлять ради самой новой зависимости; подобрать совместимые версии и сохранить root lockfile. Код использует синтаксис Dart 3.11, не последующие нововведения.

### 2. Перемещение исследования с сохранением контекста

В `local/reference/` перенести **без изменения байтов** `analysis/`, `business/`, `runtime/`, `update/`, `GUIDE.md`, `run-me.bat`, `dp4.vbs`, `splash.jpg`, `error_log.txt`. Сохранить их взаимные пути: `analysis/tools/manifest.py` вычисляет ROOT через положение файла, поэтому после переноса ROOT становится `local/reference`, а пути манифеста к business/runtime остаются корректными. Перед переносом сохранить опись/хеши, проверить отсутствие целевых коллизий; после — весь манифест 205 файлов и деревья исследования. Не удалять исходные материалы и не заменять манифест пересчитанными значениями.

`docs/calculations`, `docs/ui` и OpenSpec остаются в корне. Активные reference-dependent инструменты/ссылки обновить на `local/reference`; публичные расчётные и UI-документы различают обязательный продуктовый контракт и необязательные приватные доказательства. Ссылки на приватные исходники не выдавать за доступные из чистого GitHub checkout. Архивированные change-файлы сохранить как историю с их исходными путями.

У UI-аудита разделить публичную проверку макетов/контракта и явно запускаемую полную проверку с локальным архивом; отсутствие reference не должно превращаться в ложный PASS 455 исходных элементов или 205 хешей. Генератор legacy map требует private archive; обычная сборка приложения и тесты — нет. Текущие Python-инструменты исследования можно запускать из локального зеркала по обновлённой инструкции.

До перемещения экспортировать минимальные смысловые коэффициенты и тестовые данные, необходимые новому ядру, в его public test/resources. Не переносить обфусцированные дампы всех полей, декомпилированный код, оригинальные картинки/бренд или бинарники. Для каждого переносимого набора фиксировать источник и допустимость включения; при неопределённом происхождении использовать проверяемые опубликованные параметры/новую запись эталона, а не объявлять материал свободно распространяемым.

### 3. Воспроизводимость важнее размера дампа

В Git включить исходники, .metadata, root `pubspec.lock`, платформенные build descriptors/wrappers, локально поставляемые шрифты с notices, авторские документы, компактные численные fixtures и SVG-источники макетов. Тяжёлые PNG/contact sheets и машинные build/coverage logs генерируются локально; публичный индекс макетов должен ссылаться на доступные SVG либо явно опубликованные representative previews, а не на игнорируемые PNG.

`.gitignore`: `local/`, `.DS_Store`, `.dart_tool/`, `.flutter-plugins*`, build/coverage, IDE personal state, Android local.properties/.gradle, Pods/ephemeral/symlinks, DerivedData, пользовательские планы/exports, `.env*` кроме безопасного example, ключи и сертификаты подписи. Использовать точные платформенные шаблоны; **не** скрывать все `.jar`, `.json`, `.png`, lockfiles или platform runners: например, Gradle wrapper может требоваться для сборки. Сохранять поддерживаемые platform dependency lockfiles, где это предписано scaffold.

`.gitattributes`: нормализация text, LF для Dart/YAML/shell, при необходимости CRLF для Windows scripts, binary для реально бинарных ресурсов. При отсутствии `.git` инициализировать локальную main-ветку после установки ignore; существующий репозиторий не переинициализировать. Подготовку состава проверить `git check-ignore`, списком untracked/tracked и dry-run, не выполнять root commit/push. Служебные `.agents`/`.opencode` сохранить, отдельно просмотреть их состав; не удалять пользовательские инструкции как «мусор».

README/CONTRIBUTING описывают SDK, local run/test/build, математику/ограничения, состав репозитория и отсутствие CI/CD. Добавить notices/provenance и статус собственной лицензии без выбора за владельца. Временный чистый каталог собирать только из публикуемого manifest, без local/reference и без скрытых исключений developer machine. Это проверка будущего checkout до первого коммита.

### 4. Математический контракт, единицы и state

Канонические физические величины ядра: глубина в m, время в min, давление в bar, доли газа 0..1; VPM radii в m, прочие pressure conversions явно на границах. ATA переводится по явному коэффициенту, не меняется подпись bar↔ATA. Гидростатическое преобразование, vapor pressure, коэффициенты и модельные настройки входят в параметры с идентификатором версии. Legacy pressure-depth и imperial constants конвертируются адаптером fixtures, не живут как скрытый глобальный unit index.

Шаг стопов и последний стоп — физические величины. Переключение отображения m↔ft не меняет уже заданную сетку: новый imperial-default 10ft и существующая metric-сетка 3m — разные входы, это учитывается при сравнении источников. Проценты UI и доли ядра, CNS fraction и UI percent различаются типами/полями. Не округлять ткани/газы/состояние при сохранении и повторном использовании.

Смысловые модели: PlanRequest, DiveRequest, Level, Gas, CalculationSettings, TissueState[16], VpmState, Segment, Stop, CalculationResult, CalculationFailure. Состояние VPM включает необходимые radii/crushing/gradients/phase-volume величины, а не только N2/He. Последовательность погружений и bailout передают корректное исходное состояние; bailout — отдельная ветвь, не незаметное изменение CCR.

Уровни разворачиваются в descent/hold/ascent по восстановленному правилу учёта travel. Если travel исчерпывает длительность, не создавать нулевой constant-segment; если времени недостаточно — ошибка входа. Изменение setpoint/дилюента и эффективного вдохновляемого газа происходит в отдельном слое подготовки сегментов. Чистая tissue propagation используется планировщиком, кислородом, расходом и графиками без повторного чтения UI-строк.

### 5. Исправленная модель вместо воспроизведения дефектов

Создать `docs/models/corrections.md` и machine-readable registry: `id`, source defect/suspicion, целевое правило, источник, версия, область, reason, tests, независимые fixtures, допустимые отличия от legacy. Пользователь выбрал исправления. Product API не предлагает «compatibility mode» с молчаливым возвратом ошибок оригинала; legacy нужен как отдельный тестовый baseline.

| Группа | Целевой результат / способ принятия |
|---|---|
| VPM OC altitude context | Явная инициализация до использования; независимый успешный профиль и state, не только устранение NPE. |
| VPM SI index/full state | Ровно 16 тканей, корректные пузырьковые состояния и independent repetitive reference. |
| CCR altitude arrays overwritten | Целевая инициализация из выбранной модели сохраняется; проверить ткани и градиенты, не только финальный runtime. |
| SI=0, inclusive cycle, CNS integer hours | Нулевой интервал — identity; аналитическая tissue propagation на реальную длительность; согласованная непрерывная модель восстановления CNS, отдельно проверенная на 0/45/60/180/1440 min. |
| High-PO2 CNS и потерянная верхняя полоса движения | Общая oxygen policy для всех режимов, проверка каждой полосы/границы и движения; значение CNS вне опубликованной области даёт типизированную причину недоступности этой метрики, не выдуманную константу; декомпрессия и OTU продолжаются. |
| Root brackets, VPM/Q infinite iterations | Конечные iteration/time budgets и явная ошибка; отсутствие скобки не возвращает произвольное число. |
| Z boundary, real-gas drain, continuous limits | Непрерывные физически допустимые границы и проверенный mass balance; расширить покрытие, не clamp отрицательных остатков без доказательства. |
| VPM ANY convergence и discarded projected candidate | Сначала классифицировать относительно выбранной версии VPM-B. Подозрение не означает доказанный дефект: нельзя механически заменить ANY на ALL или прибавить discarded value без модельного источника. |
| Chart interpolation/surface mismatch | Графики строятся из новых реальных сегментов/state и единого pressure context, не из отдельного legacy алгоритма. |

Решение владельца при apply: стандартная остановка O2 на20ft даёт1.606ATA и не должна блокировать декомпрессию. CNS выше1.6ATA отображается как недоступный с причиной; неизвестность переносится по последовательности и не подменяется нулём. OTU остаётся самостоятельной накопленной дозой. Прямой CNS evaluator сохраняет доменную ошибку, production adapter превращает её в статус только метрики.

Область расчётов и кислородной модели фиксируется до реализации исправлений; валидные случаи VPM-высоты/SI нельзя заменить permanent unavailable. Отказ для действительно недопустимого ввода/несходимости остаётся частью API. Наличие неподтверждённой исправленной ветви оставляет соответствующую задачу открытой, не меняет scope на UI-only.

### 6. Независимые эталоны — отдельный продукт этой работы

Три набора данных: неизменённые `legacy_baseline` из исследования; `independent` с явно согласованной моделью; `regression` с целевыми исправлениями и ссылками на независимое основание. Компактные публичные fixtures используют смысловые имена, входы, expected output, units, model/version, source/version/hash, command, provenance, tolerance и rationale. Ошибочные JAR-случаи не преобразовывать в expected-success путём записи фактического нового выхода.

Начальные кандидаты источников, проверенные при propose:

- [Исходный расчёт Subsurface](https://github.com/subsurface/subsurface/blob/master/core/deco.cpp): доступный первичный код независимой реализации. Зафиксировать commit и режимы модели; это пока не выполненный oracle и не разрешение копировать код в Dart.
- [Авторская программа VPM на Fortran, архивная копия](https://www.pvv.org/~olafb/dir-no/library/deco/VPM%20Decompression%20Program%20in%20Fortran.pdf): найденный кандидат, полное чтение не подтверждено из-за timeout. До использования установить версию VPM/VPM-B, поддержку нужных условий, источник и воспроизведение. Старый VPM нельзя выдавать за тождественный VPM-B.
- [NOAA Diving Standards & Safety Manual, редакция 2023](https://www.omao.noaa.gov/sites/default/files/2023-05/NDSSM%20MAY%202023%20FINAL.pdf): первичный документ для сверки области и терминов кислородной политики, не автоматически готовая полная таблица/алгоритм CNS recovery. Нужные численные правила и их редакцию получить явно.

Получить и выполнить независимый oracle для сравнимых полных профилей Bühlmann/VPM, включая высоту и повторные погружения. Для CCR/bailout отдельно согласовать breathing-gas/setpoint semantics и состояния; отсутствие поддержки у одного oracle требует другого независимого способа, не отказа от заявленного режима. Haldane/Schreiner, SI, свойства газа и mass balance дополнительно проверять аналитическими случаями и invariants. Написанный на другом языке буквальный перевод того же дефектного фрагмента не считается независимым источником.

До сравнения выровнять surface/vapor/water, a/b variant, GF policy, travel, stop grid, газовые пороги, CCR и rounding. Нормализовать физические raw results; presentation compatibility проверять отдельно. Структура стопов и выбранные газы сравниваются точно в согласованной модели. Для raw значений назначить scale-aware field tolerances до прогона и зафиксировать в fixtures; не расширять допуски ради прохождения. Различия модельных соглашений документируются отдельно, а не прячутся в большом epsilon.

Матрица включает B/C/VPM c0–c4 × OC/CCR/bailout, metric/imperial с равными физическими настройками, normal/multilevel/gas loss/switches, altitude acclimatized/travel, SI0/45/60/180/1440, кислородные полосы/движение, solver failures и gas mixing limits/drain. Не требуется бессмысленное декартово произведение всех параметров, но каждая применимая ветвь и каждый исправляемый дефект имеют отдельный успешный или ошибочный тест с причиной.

### 7. Сегменты → все производные результаты

Ядро возвращает не только stop table: raw segments/tissue snapshots, runtime, ascent/deco times, off-gassing context, CNS/OTU, GF/применимые VPM величины, gas usage и данные для ratios. Расход OC — segment pressure/RMV, CCR — дилюент/OCR с отдельными газами; баллон меняет давление расхода, не расписание. «Без резервов» остаётся видимой подписью.

MOD/END/density/custom mix, partial/continuous ideal/real blending, top-off, equalizer, conversion и cost — чистые сервисы того же Dart-пакета с единым units context. Не переносить static Q unit state. Рецепт содержит discriminated success/drain/impossible/failure, шаги и pressures/quantities; negative residuals разбираются по доказанному правилу, не молча обнуляются. Top-up cost фиксированная плата. Свойства и балансы проверяются независимо; обычные корректные legacy cases сохраняют свою сравнительную ценность.

### 8. Рабочий Flutter UI по существующему контракту

Реализовать P01–P08, T01–T08, S01–S02, а не вставлять SVG в приложение. Использовать `docs/ui/feature-map.json` как checklist покрытия; каждое включённое поле/действие связывается с реальным control/handler и тестом/ручным сценарием. Мобильные формы, desktop stop table/detail, профиль/ткани/ratios, range result и PDF-preview получают реальные данные ядра. Демо не является production data source.

`LayoutBuilder`: <600 sequential NavigationBar, 600–999 Rail/detail, ≥1000 editor+result; крупный текст может раньше включить sequential layout. Общая state-модель переживает resize. Material controls, `Form`, ошибки/summary, видимые units, поддержка запятой/точки, light/dark tokens, hit targets≥48, keyboard/focus, safe areas и reduced motion соответствуют UX-пакету. Численная таблица является доступным эквивалентом графика; интерактивность CustomPainter отделена от реальных данных. Не копировать подозрительную legacy chart interpolation.

Русский интерфейс и терминология существующих макетов — первый язык; не строить переводческий продукт сверх этой задачи. Шрифты и базовая справка поставляются локально с правами/лицензиями; runtime network font loading отсутствует. Реальное приложение не показывает FXML IDs, Java symbols, fixture IDs или технические revision как пользовательские подсказки.

### 9. Worker, отмена и версии

UI/ViewModel формирует immutable request с requestId/inputRevision/dependencyVersion. Планирование выполняется в отдельном управляемом Dart isolate; отмена/таймаут прекращают worker, а stale response отбрасывается независимо от timing. Solver iteration budgets остаются внутри ядра: isolate kill не является математическим критерием сходимости. Прогресс range-вычислений ограничен и не накапливает неограниченные задачи.

Редактирование раннего dive инвалидирует зависимые dive/bailout, не уничтожая draft. Theme/zoom/раскрытие не меняют physical revision. Структурированные ошибки различают input, unsupported/out-of-domain, no-convergence, cancelled, timeout и persistence/export. Пользователь получает причину и recovery action, диагностические детали — отдельно.

### 10. Хранение, обмен и PDF

App data directory через platform adapter; versioned JSON schema v1 для библиотек, настроек, планов и snapshot metadata. Файловый repository делает проверяемую запись через temp/flush/replace с последней корректной резервной копией; учитывать Windows replace semantics и ошибки каждой стадии. Повреждённый файл не вызывает автоматическую перезапись пустым планом: восстановить last-good либо предложить явное действие. Импорт ограничен по размеру/структуре и валидируется до изменения текущего документа.

Вместе с результатом сохранять modelVersion, input/dependency hash и полноту состояния. При обновлении модели старый result становится stale; план остаётся доступным для пересчёта. Не хранить пользовательские файлы в исходном репозитории. Автосохранение draft с debounce дополняет явные save/open/rename/delete, не обещая disk commit до успешного завершения записи.

JSON export переносит физические настройки и schemaVersion; PDF содержит исходные условия/единицы, модель/версию, таблицу и статус. Range PDF включает условия диапазона и ошибки отдельных ячеек, без выдуманных значений. Preview формируется локально; native print/share/save cancel не теряет документ.

Dart MCP package search подтвердил кандидаты `path_provider`, `file_selector`, `printing`; для PDF — связанный `pdf`, для paths — `path`. Версии выбрать совместимые с текущим SDK в apply; latest из поиска не считать обещанием совместимости. Platform-specific save/share поддержать адаптерами, проверяя возможности каждой ОС: одна desktop API не выдаётся за работающую на mobile. Прямое использование штатных API/минимального числа пакетов предпочтительнее новой БД и сложной маршрутизации.

### 11. Проверки и честная платформенная готовность

Core: unit/regression/differential, все 16 тканей, model state, состав/порядок/время стопов, конечность, conservation, round-trip units/state, отсутствие order dependence. App: ViewModel stale/cancel/dependencies, storage fault injection/schema/version, widget forms/navigation/a11y/resize/theme, integration flows OC→result, CCR→bailout, repetitive VPM/altitude, инструменты, save/reopen/import/PDF. Никакой seed из fixtures не подменяет core в end-to-end тесте.

`dart format`, Flutter/Dart analyze, unit/widget tests через официальный Dart MCP, native build macOS и запущенный relevant app — минимальная доступная проверка. При редактировании executable `lib/` подключаться к relevant running app; hot reload для widget/simple changes, hot restart для initialization/global/fundamental logic по `/Users/yurik/.codex/flutter-agent-plugins/rules/flutter-hot-reload.md`. Если app не запущен, сообщать отсутствие runtime validation; не стартовать чужое приложение. Созданный планер можно запускать в рамках его реализации.

На iOS/Android выполнить доступные toolchain/build проверки; iOS unsigned build не заменяет device test. Windows требует Windows toolchain — на текущем macOS его проверка не заявляется. Зафиксировать platform matrix `configured / built / launched / exercised / blocked(reason)` и точные невыполненные сценарии RT01–RT12. Отсутствие чужой платформы — ограничение среды, а не выполненный тест; отсутствие требуемого исправленного численного эталона — незавершённость реализации и не принимается как аналогичная средовая оговорка.

Заключительная isolated publish-tree проверка запускает public анализ/тесты/build без local/reference; все runtime assets и зависимости доступны после штатного restore. Сетевой доступ при получении development dependencies допустим, при запуске/вычислении приложения не требуется. CI/CD намеренно отсутствует.

## Risks / Trade-offs

- [Независимый VPM-B oracle может иметь иные соглашения или не покрывать CCR] → ранний acquisition/normalization до реализации, отдельные references и аналитические проверки; незавершённый oracle не скрывается отключением функции.
- [Некоторые «подозрения» в исходнике могут быть модельными решениями] → correction registry различает подтверждённый дефект и непроверенное предположение; первичный источник до изменения численного правила.
- [Смешивание scientific corrections и exact legacy compatibility] → отдельные baselines, versioned corrected model и явные intentional differences без изменения старых expected JSON.
- [Очистка каталога ломает ссылки/инструменты] → зеркальная local/reference структура, полный SHA audit и обновление активных callers; чистая сборка без private references.
- [Большой функциональный объём] → законченные группы задач с тестами внутри каждой, численное ядро до UI binding; не принимать заглушки за завершённое приложение.
- [Непроверенные mobile/Windows plugin capabilities] → platform adapters и матрица фактических проверок; не объявлять успешный запуск по одному наличию runner.
- [Неопределённые права на исследовательские/чужие материалы] → исключить оригинал и чужой код, фиксировать происхождение новых параметров/fixtures/assets; не назначать собственную лицензию без владельца.

## Migration Plan

1. Опись/хеши и публикуемый состав; перенос оригинала/analysis в local/reference, обновление активных инструментов без изменения архивированных доказательств.
2. Локальный Git/ignore, root scaffold и package core без коллизий; восстановление публичного рабочего набора и optional reference procedures.
3. Зафиксировать corrected model и независимые sources/fixtures; реализовать ядро с регрессиями, затем production UI/data/export.
4. Проверить доступные платформы и изолированное дерево, представить результаты и неподтверждённые платформы. Не делать remote/commit/push и CI/CD.

Откат переноса выполняется по описи обратным перемещением только перенесённых файлов с проверкой хешей; пользовательские новые планы предварительно сохраняются отдельно. Исследовательский манифест не переписывается, старые данные не удаляются. Изменения документов/кода можно откатывать отдельно от local archive; Git history до первого коммита не обещается как резервная копия.
