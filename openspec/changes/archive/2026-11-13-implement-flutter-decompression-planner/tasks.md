# Tasks

Результат apply — работающее приложение и подготовленный локальный репозиторий. Исправленные ветви и независимые эталоны входят в обязательную готовность. CI/CD, remote, commit/push и публикация релизов не выполняются.

## 1. Каталог, scaffold и публикуемый состав

- [x] 1.1 Зафиксировать опись/хеши текущих файлов и минимальный переносимый baseline коэффициентов/смысловых fixtures с provenance; проверить, что оригинальные результаты/исключения сохранены отдельно от будущих исправлений и в public-набор не попали Java-дампы/бинарники.
- [x] 1.2 Переместить исходный дистрибутив и analysis в зеркальный local/reference по design.md; проверить все 205 исходных SHA-256, полноту исследовательского дерева, отсутствие коллизий и работоспособность manifest verify из нового расположения.
- [x] 1.3 Обновить активные reference paths/инструкции и разделить public/private режимы UI-аудита; проверить public UI-аудит без архива, full audit с архивом и отсутствие ложного PASS для недоступных private-проверок, сохранив архивированные OpenSpec-файлы.
- [x] 1.4 Добавить .gitignore/.gitattributes, инициализировать локальный Git только при его отсутствии и подготовить manifest публикуемых файлов; проверить git check-ignore для секретов/кэшей/local и обязательных ресурсов, а dry-run — на отсутствие чужого дистрибутива, workflows, remote и commit.
- [x] 1.5 Создать через официальный MCP root Flutter scaffold четырёх платформ и packages/deco_core без перезаписи существующих материалов, настроить SDK/lockfile/lints; проверить restore и базовый analyze обоих пакетов, описать команды в README/CONTRIBUTING и сделать SVG-индекс доступным из публикуемого набора.

## 2. Исправленная модель и независимые эталоны

- [x] 2.1 Создать docs/models/corrections.md и машиночитаемый реестр всех дефектов/подозрений из limitations.md; для каждого указать целевое правило, источник, область и тесты, отдельно классифицировать VPM ANY/projected-ascent без предположительного исправления.
- [x] 2.2 Получить, зафиксировать версию/хеш и выполнить независимый oracle для сравнимых Bühlmann B/C и VPM-B-профилей; сохранить команды и первый успешный воспроизводимый эталон каждого выбранного варианта, не выдавая старый VPM за VPM-B и не копируя чужой исходник в продукт.
- [x] 2.3 Согласовать единицы, surface/vapor, GF, stop grid, travel, gases/setpoints и state независимых эталонов для OC/CCR/bailout, высоты и SI; проверить документацию модели и сохранить успешные контрольные случаи исправляемых VPM-высоты/повторных ветвей с промежуточными состояниями.
- [x] 2.4 Зафиксировать общую oxygen/recovery policy из первичных источников, её численную область и независимые значения всех используемых полос/границ/движения и SI0/45/60/180/1440; проверить полноту источников и исключить фиктивные high-PO2 константы оригинала.
- [x] 2.5 Оформить legacy_baseline/independent/regression, schema/provenance и полевые допуски до сравнения; проверить повторный запуск источников, независимость происхождения expected values и audit полноты матрицы, не перезаписывая ожидания под новый результат.

## 3. Контракты ядра и физические примитивы

- [x] 3.1 Реализовать immutable requests/results/failures, gases, настройки, 16 тканей и полный VPM state; проверить serialization round-trip, неверный ввод/NaN/Infinity и точное сохранение influencing state, документировать публичный API пакета.
- [x] 3.2 Реализовать canonical units и адаптер исследовательских fixtures с явным ATA/bar/pressure-depth и физической сеткой стопов; проверить round-trip и физически эквивалентные metric/imperial cases без повторного округления.
- [x] 3.3 Реализовать Haldane/Schreiner, inspired-gas preparation и сегменты descent/hold/ascent для OC/CCR/bailout; проверить аналитические состояния всех тканей, travel semantics и movement-only/недостаточную/нулевую длительность.
- [x] 3.4 Реализовать bounded numerical solvers и typed failures с iteration/time budgets; проверить корректные корни, плохие скобки, отсутствие сходимости, конечность и невозможность успешного числа вне решения.

## 4. Bühlmann, кислород и последовательность

- [x] 4.1 Реализовать проверенные B/C coefficients, mixed a/b, GF ceiling и поиск первой остановки; пройти synthetic/independent tissue cases, проверить ведущую ткань и границы GF, описать выбранное правило интерполяции.
- [x] 4.2 Реализовать полный OC schedule, ascent/stop search, lost/deco gas switches, minimum/last stops и raw/display separation; сравнить все сегменты/остановки/ткани с согласованными baseline и independent fixtures, включая multilevel и imperial.
- [x] 4.3 Реализовать CCR setpoint/diluent и связанную bailout-ветвь на Bühlmann; проверить независимые профильные результаты и переход CCR→OC без изменения исходного плана, включая смену дилюента/PO2 и отсутствие переключений.
- [x] 4.4 Реализовать altitude/acclimatization/travel и непрерывное восстановление на SI, общие CNS/OTU для всех фаз; проверить независимые высотные/повторные примеры, SI=0 identity, все oxygen bands и intentional differences от legacy, обновить correction registry.

## 5. VPM-B и исправленные проблемные ветви

- [x] 5.1 Реализовать explicit radii/crushing/regeneration/gradients и консерватизм0–4 по зафиксированной версии модели; проверить независимые промежуточные состояния и отсутствие глобального unit/model state.
- [x] 5.2 Реализовать critical-volume, projected ascent и decompression search с выбранной доказанной семантикой и ограничением итераций; проверить baseline/independent нормальные профили c0–c4, успешную сходимость и типизированные failures вместо бесконечного цикла.
- [x] 5.3 Подключить VPM к OC/CCR/bailout и газовым/setpoint-переходам; проверить согласованные полные эталоны всех режимов, структуру остановок, ткани и bubble state, а также независимость порядка запросов.
- [x] 5.4 Исправить OC altitude initialization и CCR altitude state overwrite по correction registry; пройти независимые успешные acclimatized/travel cases с проверкой состояния и расписания, сохранить исходные JAR-ошибки как отдельную историю.
- [x] 5.5 Исправить VPM repetitive/SI indexing и перенос полного состояния; проверить SI0/45/60/180/1440 и цепочки OC/CCR/bailout по независимым данным, обновить матрицу и документацию, не заменяя эти функции недоступностью.

## 6. Газовые расчёты и производные результаты

- [x] 6.1 Реализовать MOD/min depth/END, density/equivalent air depth и custom mix с вариантами наркотичности O2; проверить аналитические и сохранённые корректные примеры, граничные составы и ошибки вместо Infinity/отрицательных долей.
- [x] 6.2 Реализовать ideal/real partial-pressure mixing, порядок O2/He и разные top-up gases с finite solver state; проверить независимый mass balance, normal/drain/impossible, исправленные real-gas drain и табличную границу Z без скрытого clamp.
- [x] 6.3 Реализовать continuous blending варианты1/2 и применимые пределы потоков; проверить независимые контрольные потоки/балансы, граничные limits, стравливание и невозможные смеси, документировать численные отличия от ошибочных исходных ветвей.
- [x] 6.4 Реализовать top-off, equalizer, tank conversion и volumes/cost; проверить аналитические/эталонные cases, разные единицы/порядок цен, нулевую цену, одинаковые давления и отклонение неверных объёмов.
- [x] 6.5 Реализовать OC/CCR/bailout segment gas usage, tank pressure, ratios/groups и range calculation из реального schedule; проверить суммы/единицы/группировки и ошибки отдельных range-cases, документировать отсутствие резервов и различие runtime/ascent/deco.

## 7. Runtime, документы и восстановление

- [x] 7.1 Создать production worker adapter на управляемом isolate с progress/cancel/timeout и version matching; проверить запоздалые ответы, отмену, превышение бюджета и сохранение отзывчивости без fixture-based production backend.
- [x] 7.2 Реализовать ViewModels/state для последовательности, газа, параметров, результата и tool drafts; проверить invalidation всех зависимых dive/bailout, сохранность ввода, theme/zoom без лишней invalidation и восстановление после ошибки.
- [x] 7.3 Реализовать versioned JSON persistence планов, настроек, справочников и сравнения с безопасной записью/last-good recovery; пройти round-trip и fault injection каждой стадии, повреждённый файл и изменение modelVersion без потери предыдущего документа.
- [x] 7.4 Реализовать list/open/save/rename/delete и автосохранение, JSON import/export через platform adapters; проверить отмену, unsupported schema, oversized/invalid document и стабильность текущего плана, описать схему и восстановление в документации.

## 8. Адаптивный UI планирования

- [x] 8.1 Реализовать app shell, три destinations, темы/локальные шрифты/справку и adaptive layout по UX-пакету; проверить widget resize599/600/999/1000/1440, small phone/landscape и text200%, сохранить notices ресурсов и реальные скриншоты.
- [x] 8.2 Реализовать P01/P02: последовательность/интервалы, режимы, уровни и actions, validation/summary/units и безопасные подтверждения; пройти widget-сценарии добавления/перестановки/отмены/удаления и реальный OC→calculation flow.
- [x] 8.3 Реализовать P03 и S01/S02: наборы/потеря газов, CCR switches, модели/GF/VPM, высота/RMV/OCR, баллоны и настройки вида; проверить применимость, Save defaults против Apply, units switch и покрытие legacy feature-map.
- [x] 8.4 Реализовать P04/P06: реальную таблицу/раскрытие, все применимые показатели, расход/баллоны, статусы empty/invalid/calculating/ready/stale/error; проверить core-backed widget/integration tests и доступность всех desktop-полей на mobile.
- [x] 8.5 Реализовать P07: переход из CCR, точку bailout и явные CCR/OC-сегменты с отдельными результатами; проверить полный CCR→bailout flow, invalidation при изменении источника и отсутствие изменения исходного CCR-плана.

## 9. Газовые инструменты и анализ в приложении

- [x] 9.1 Реализовать T01–T03 с реальным ядром, применимыми ограничениями и явным переносом газа; пройти form/widget/integration cases normal/error/stale и проверить, что результат меняется при новых входах.
- [x] 9.2 Реализовать T04/T08: методы/варианты mixing, steps/drain/impossible, баллон/цены/стоимость и recipeRevision; проверить end-to-end смену рецепта, стравливание, невозможную смесь, актуальность и суммы.
- [x] 9.3 Реализовать T05–T07 с сохранением отдельных draft; пройти normal/boundary/error cases в metric/imperial, navigation/back и сохранение значений без неявного толкования новых единиц.
- [x] 9.4 Реализовать P05: профиль/точки, сравнения, только ascent, ткани/M-values, ratios и доступные численные представления; проверить соответствие данным сегментов, легенду/оси, keyboard/touch и отсутствие legacy surface/interpolation расхождений.

## 10. Range tables, PDF и сквозная доступность

- [x] 10.1 Реализовать P08: глубина/время/шаги, базовый и no-gas/no-switch варианты, progress и матрицу/список; проверить real-core результаты, отмену больших диапазонов, ошибки отдельных ячеек и переход к полному результату.
- [x] 10.2 Реализовать локальное PDF-формирование результатов/range, preview, native print/save/share adapters; проверить содержимое/единицы/модель/актуальность, визуальный PDF-render, offline fonts, cancel/failure recovery и заявленные возможности каждой доступной платформы.
- [x] 10.3 Проверить и исправить весь UI по RT01–RT12 и требованиям accessibility: focus order/return, screen-reader labels, error announcements, 48 targets, контраст обеих тем, text scaling, клавиатура, safe areas и reduced motion; добавить смысловые widget/integration regressions, зафиксировать фактически выполненные проверки.
  - Принято владельцем по явному решению «Давай считать что 10.3 готова». Непройденные нативные проверки остаются ограничениями в docs/development/runtime-accessibility.md; они не объявляются PASS.

## 11. Интеграционная готовность и GitHub preparation

- [x] 11.1 Выполнить полный численный coverage/correction audit: все применимые модели/режимы/единицы/высота/SI/oxygen/mixing, provenance и назначенные допуски; проверить, что ни одна обязательная исправленная ветвь не исключена, не заменена заглушкой и не принята по собственному фактическому output.
- [x] 11.2 Выполнить format/analyze/unit/widget/integration и native macOS build/run по официальному MCP и hot reload/restart rule; провести доступные mobile-проверки, составить честную configured/built/launched/exercised/blocked матрицу четырёх платформ с точными ограничениями среды.
- [x] 11.3 Развернуть только публикуемый manifest в чистой временной директории без local/reference и повторить restore, public audits/tests и доступную сборку; проверить secrets/ignore/links/assets/notices, обновить README и итоговый отчёт, оставить Git без remote/commit/push и без CI/CD.

## Workflow follow-up

- После отдельного решения владельца выбрать лицензию, создать GitHub remote и отправить подготовленные исходники.
- CI/CD, signing, установщики и публикацию в магазинах оформить отдельным изменением.
