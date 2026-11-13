# Текущий проверенный срез

Дата: 2026-11-13. Flutter 3.41.6 / Dart 3.11.4. Все47задач реализации приняты. Задача10.3 закрыта по явному решению
владельца с сохранением документированных ограничений нативного аудита.

## Результаты

- **1006 core tests PASS**, полный повтор после новых VPM и Bühlmann imperial
  эталонов; официальный Dart MCP analyze ядра — без ошибок.
- **266 app unit/widget tests PASS** в финальном прогоне актуальной чистой копии.
- **8 standard native macOS integration tests PASS**: application-support
  storage/recovery, library save/new/open/delete, gas properties, mixing/cost,
  range→full result, OC и CCR→bailout с реальным isolate, темы, отдельная ветвь
  и сохранность исходного CCR.
- **1 interactive native PDF test PASS**: реальный Save success/cancel,
  Print cancel, Share dismissal, preview. Сохранённый PDF побайтно совпал
  с переданным экспортом: 21370 bytes, SHA-256
  `10e59996db4c985ce53e52bc48ddba7c22346a1d387462e8fae349e4a8a048ce`.
  Физическая печать и отправка документа не выполнялись.
- OpenSpec strict validation, public design audit и численные аудиты проходят.
  Статический design audit не заменяет runtime/accessibility проверку.

Основное приложение собрано/запущено на macOS после изменений доступности;
официальный MCP hot reload успешен, runtime errors отсутствуют.
Полный native8/8 повторён после финальных изменений dialogs/safe areas.
Итоговые format/analyze/core/widget/macOS иAndroid builds также прошли
в новой чистой копии. Interactive PDF1 — ранее проверенный сценарий;
повтор с настоящими системными диалогами на этом этапе не выполнялся.

## Расчётные эталоны

[Реестр](../models/numerical-fixtures.md) охватывает **140 JSON** и сохраняет
различия исходных наблюдений, независимых компонентных/полных эталонов,
диагностических native defaults и исправленных regressions. Проверены SHA,
происхождение, конечность чисел и полевые assertion contracts; legacy результаты
не перезаписываются под Dart actual. [Аудит исправлений](../models/corrections.md)
сохраняет все30 записей, включая ограничения происхождения и intentional scope.

Bühlmann B/C:19 независимых OC расписаний (включая multilevel/imperial),
18 CCR/bailout профилей,68 altitude/SI сценариев, ещё8 CCR/bailout профилей
на физической сетке10ft. Проверяются сегменты/газы/SP, ткани, кислород,
время и неизменность исходного запроса.

VPM:17 corrected full OC и5 swapped-gradient diagnostic profiles,
30 CCR/bailout,8 OC altitude/SI и26 CCR/bailout altitude/SI сценариев;
дополнительно30 descending multilevel и60 partial-ascent/redescent profiles,
c0–c4, metric/10ft, OC/CCR/bailout. Последние включают реальные промежуточные
остановки и полный bubble state. Повторные захваты новых90 VPM и8 B/C imperial
профилей дали идентичные SHA. Общие правила —
[normalization](../models/reference-normalization.md).

Continuous blending:486 независимых SciPy/HiGHS ideal/real recipes, оба варианта
и пути, limits/drain/impossible/pure/identity. EOS:25 независимых70-digit корней;
расход:37 независимых quadrature профилей. Остальные газовые свойства/балансы
проверяются аналитическими и сохранёнными исходными controls.

CNS выше1.6ATA недоступен с причиной, декомпрессия и OTU продолжают считаться.
Неизвестный CNS сохраняется в SI и JSON. Projected-ascent guard проверен отдельно;
его влияние на обычные legacy schedules не объявляется доказанным дефектом.
ANY-convergence сохранена по выбранной версии VPM. Не заявляется полный
Cartesian product всех параметров: проверяются применимые зафиксированные ветви.

## Интерфейс и данные

P01–P08, T01–T08, документы/автосохранение, JSON import/export, настройки,
справочники, профиль/сравнения, диапазоны и PDF подключены к настоящему ядру.
Worker покрыт cancel/timeout/budget, stale/version/dependency mismatch,
malformed response, unexpected exit и отзывчивостью родительского isolate.
Persistence: полные snapshots, SHA-256,11-stage fault injection/last-good,
old modelVersion→stale, future schema без перезаписи.

Widget проверки:375/599/600/999/1000/1440px, landscape740×375, text100/200%,
обе темы, dirty Back/Cancel/Save, validation/focus/scroll к ошибке,
keyboard inset180px, dependency invalidation трёх dive/трёх bailout,
profile zoom/pan/keyboard, result/stale/error recovery, immediate range cancel.
Смена темы/единиц не меняет физический результат.

Автоматические guidelines label/48-target/contrast проверены для видимой области
основных разделов с прокруткой; reduced motion — через accessibility features.
Они не объявляются аудитом всех экранов или настоящим screen reader тестом.
[RT01–RT12 и оставшаяся доступность](runtime-accessibility.md),
[PDF](pdf-reports.md), [реальные кадры](../ui/runtime/README.md).

Native PDF Print deadlock исправлен `dynamicLayout:false` для frozen A4;
есть unit regression и реальный Print cancel. Предыдущие зависшие/ошибочные
запуски не считаются PASS. Ненадёжные Flutter Driver pointer commands заменены
стандартным integration_test binding. Завершались только собственные оставшиеся
тестовые процессы; unrelated приложения не перезапускались.

## Платформы и ограничения

| Платформа | Configured | Built | Launched | Exercised | Ограничение |
|---|---|---|---|---|---|
| macOS | Да | Debug | Да |8 standard +1 interactive native, основной app | Release/signing/installer не проверены |
| iOS | Да | Compile-only с временным target15 | Нет | Widget layouts | Стандартный target13 не поддерживается текущим SDK; simulator не установлен |
| Android | Да | Debug APK | Нет | Widget layouts | Устройство/эмулятор не подключены; native runtime не проверен |
| Windows | Да | Не проверено | Нет | Widget layouts | Требуется Windows host |

macOS minimum12.0 согласован с установленным Xcode SDK и pods. Native mobile
keyboard/insets, OS Back/share sheets, Dynamic Type, VoiceOver/TalkBack/Narrator
и полный keyboard/focus audit остаются открытыми. Native JSON Open/Save также
не пройдены; adapter success/cancel/failure проверены тестами.

[Чистый публикуемый checkout](public-checkout-validation.md): restore,1006core/266app
tests,analyze,format131/0changed,public audits иmacOS Debug build прошли.
Итоговый runtime/accessibility аудит остаётся открытым. Git остаётся
без remote/commit/push, CI/CD/signing/релизы — отдельная задача. Оригинальный
Java-дистрибутив/исследовательский архив не входят в runtime и public manifest.

Android: `flutter build apk --debug` в чистой public копии — PASS. Первый
запуск восстановил Gradle8.14 и установил нужный SDK Platform34 по уже принятой
лицензии; SDK проекта и constraints не менялись. Предупреждения Java source/target8
в сторонних компонентах не подавлялись. APK не устанавливался и не запускался.

## Последний этап10.3

Исправлены Escape для modal editors/confirmations с сохранением dirty checks,
reduced-motion dialog transitions, semantic names иконок и safe areas отдельных
routes/численных таблиц. Новая чистая public копия:1006core +266app PASS,
137Dart files format/0changed,analyze без ошибок,macOS Debug иAndroid APK PASS.
Native integration8/8 повторён после финальных изменений. Подробности и
незавершённый VoiceOver/RT audit — [доступность](runtime-accessibility.md).
VoiceOver временно включён по разрешению и возвращён off; его речь не удалось
наблюдать через Computer Use, успех screen-reader проверки не заявляется.

10.3 принята владельцем с известными ограничениями;47/47tasks complete.
Непроверенные native screen-reader/RT cases не преобразованы в PASS.
Изменение архивировано в `openspec/changes/archive/2026-11-13-implement-flutter-decompression-planner`.
Четыре новые основные спецификации синхронизированы; strict validation:10/10 PASS.
