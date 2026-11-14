# Участие и разработка

Репозиторий публичный, вклад в основной проект принимается только от
приглашённых collaborators. Только они могут создавать pull request и имеют
право записи. Приглашения выдаёт владелец репозитория.

Эта политика относится к работе в репозитории GitHub и не ограничивает
права использования, изменения, форка или распространения кода по MIT.

## Разработка

Использовать Flutter 3.41.6 / Dart 3.11.4 и root pubspec.lock. Не обновлять SDK
или зависимости без необходимости для задачи. Core не зависит от Flutter,
сети, файлов оригинала или глобальных настроек процесса.

Основные каталоги: lib — приложение; packages/deco_core — модели и вычисления;
docs — контракты/дизайн; openspec — история и задачи; local — игнорируемые архивы.

Перед изменением прочитать актуальные спецификации. Функция считается готовой
после реализации и её проверки; scaffold и fixtures не подменяют вычисление.
Исходные результаты legacy неизменны. Исправленные расчёты требуют независимых
эталонов и заранее назначенных допусков.

Проверки: format, analyze, Dart unit tests, Flutter widget/integration tests,
доступные native builds. При использовании агента применять официальный Dart
MCP для analyze/test. Изменения executable Flutter lib проверять hot reload;
initialization/global/fundamental logic — hot restart релевантного приложения.
Если оно не запущено, честно фиксировать отсутствие runtime-проверки.

Не коммитить local/reference, пользовательские документы, ключи, .env, кэши,
сборки и генерируемые PNG-превью. SVG/metadata и нужные платформенные wrapper
файлы не должны теряться из-за широких ignore. CI/CD, release signing
и публикация релизов выполняются отдельной явно порученной задачей. Commit и push допустимы в рамках согласованной работы
с репозиторием; перед ними проверяется staged diff и состав файлов.

## Обязательный CI

Изменения main проходят только через PR и успешный `DecoPlanner CI gate`;
второе approving review не требуется. PR выполняется с contents:read без
секретов выпуска. Форматирование проверяется командой:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver packages/deco_core/lib packages/deco_core/test
```

Дополнительно выполняются `flutter analyze --fatal-infos`, `flutter test`,
`dart analyze --fatal-infos` и `dart test` в packages/deco_core,
`python3 -m unittest discover -s tool/release/tests -v` и
`python3 tool/release/audits.py` (OpenSpec 2.0.0).
Платформенные проверки: Windows release, macOS release и автоматический
`integration_test/plan_flow_test.dart`, Android debug без release-ключа.
Ручные PDF-диалоги не запускаются unattended.

Агент для analyze/test использует официальный Dart MCP; приведенные CLI-команды
предназначены также для воспроизведения CI человеком.
Процесс релиза и установки описан в [releases.md](docs/development/releases.md).
