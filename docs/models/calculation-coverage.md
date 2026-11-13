# Итоговый численный аудит реализации

2026-11-13: полный набор **1006 core tests PASS**, официальный MCP analyze
без ошибок. Аудиты выполняются независимо от приватного архива:

```sh
python3 tool/audit_numerical_fixtures.py
python3 tool/audit_calculation_coverage.py
python3 tool/audit_corrections.py
python3 tool/audit_vpm_multilevel_reference.py
python3 tool/audit_vpm_redescent_reference.py
```

## Принятие результатов

Все140 JSON зарегистрированы с SHA, схемой верхнего уровня, provenance,
областью и полевыми контрактами тестов. Изменение expected или assertions
вызывает отказ публичного аудита; это проверено намеренными изменениями
во временной копии. Оригинальные205 файлов приватного исследовательского
manifest повторно проверены и сохранены. У приложения нет зависимости
от Java, исходного runtime или приватного архива.

[Протокол повторных запусков](reference-reproduction.json) фиксирует20
существующих генераторов с exit0 и побайтно идентичными ожиданиями. Отдельные
повторы новых30 descending VPM,60 redescent VPM и8 B/C imperial profiles также
идентичны. Семь дополнительных native-default diagnostics не считаются
product acceptance и этим повтором не объявляются проверенными.

## Обязательные направления

| Направление | Независимое/аналитическое доказательство |
|---|---|
| B/C1b, GF, OC | Таблицы/ceilings внешнего DecoTengu,19 полных OC stop-search profiles, multilevel, gas/lost/minimum/last stops и imperial |
| B/C CCR/bailout |18 метрических и8 imperial полных профилей, независимая CCR ODE, переключения и разные точки отказа |
| B/C высота/SI |68 сценариев; оба model, все3режима;2000m acclimatized/travel,8848m travel;50цепочек с SI0/45/60/180/1440 |
| VPM physical/CV | Внешний pinned VPM-B,70-digit отдельные корни/физика, crushing/radii/gradients/Boyle;17 corrected OC и5 намеренных swapped diagnostics |
| VPM CCR/bailout |30 full profiles c0–c4, diluent/SP switches, prefix/bubble history, отказ в descent/hold/ascent/stop |
| VPM высота/SI |8 OC и26 CCR/bailout altitude/sequence сценариев;16тканей,22 bubble vectors, saved states и JSON handoff |
| VPM multilevel/units |30 descending и60 partial-ascent/redescent profiles, metric/10ft × c0–c4 × OC/CCR/bailout;30profiles имеют реальные промежуточные stops |
| Oxygen | Baker quadrature всех полос/границ, движение в обе стороны, clipped boundary; SI0/45/60/180/1440, unknown CNS и численный OTU вне1.6ATA |
| EOS/partial-pressure mixing |25 внешних70-digit VdW roots; аналитические balances всех компонентов, maximal retention/drain, оба порядка O2/He и произвольный top-up |
| Continuous blending |486 внешних SciPy/HiGHS LP ideal/real cases, variants1/2, оба пути, caps/drain/impossible/pure/identity |
| Свойства/вспомогательные | Аналитические partial-pressure MOD/END/density/custom mix, balances top-off/equalizer, unit conversions и cost; наблюдённая Z-table с явной interpolation/extrapolation |
| Usage/range |37 внешних quadrature cases, segment/per-gas sums, CCR overlap, zero rates, tank pressure/ratios/groups; range cells сверяются с полным calculator |
| Ошибки/состояние | Неизменяемые16тканей/полный VPM state, input round-trip, NaN/Infinity rejection, zero-time identity, budgets/time/cancel/root failures, независимость порядка запросов |

Эта таблица обозначает применимые контролируемые направления, не полный
Cartesian product всех величин. Нормализация сухого вдоха/мокрого oxygen,
units, travel, state/SI0 и полных метрик приведена в
[контракте источников](reference-normalization.md).

## Проверка исправлений

[Все30 записей](corrections.json) сохранены, ни одна обязательная ветвь
не исключена и не заменена недоступностью. В частности, высота и SI реально
считаются, а их успешные состояния сверяются с независимыми данными.
Только CNS вне согласованной области возвращает причину недоступности согласно
решению владельца; декомпрессия/OTU продолжаются.

Сохраняются различия подтверждённого дефекта, подозрения и scope boundary:
ANY-convergence — правило выбранного VPM; влияние projected-ascent guard
на обычный legacy профиль не доказано, проверен отдельный независимый safeguard
и1116 исходных наблюдений bounded search. Отсутствие резервов — явная область
одного дайвера, не скрытая фиктивная формула. Decompiler copy loop не переносится
в типизированные immutable состояния. Происхождение неофициального оригинала
остаётся ограничением; совпадение не объявляется сертификацией модели.

Ожидания внешних JSON не получены из фактического Dart output. Для аналитических
балансов собственный EOS контролируется отдельно внешними корнями, а уравнения
сохранения проверяются по компонентам. Raw native conventions и известные
ошибки legacy не выравниваются ослаблением допусков или переписыванием данных.
