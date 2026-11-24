# DecoPlanner

Самостоятельное приложение Flutter с чистым Dart-ядром для планирования
погружений. Все47задач реализации OpenSpec приняты, включая10.3 с известными
ограничениями нативного аудита. Работают
редактор последовательности/уровней, фоновый расчёт Bühlmann/VPM и связанные
CCR→bailout сценарии с отдельными результатами, таблица сегментов, темы/единицы
и MOD-инструмент. Проверены нативные macOS OC и CCR→bailout flows;
[реальные снимки интерфейса](docs/ui/runtime/README.md).

Работают локальные документы с автосохранением и переносом JSON, все восемь
газовых инструментов, график и таблица состояний тканей, сравнения, диапазоны,
расход/баллоны и PDF с нативными Save/Print/Share. Численное ядро проходит
1006 тестов, приложение — 267; на macOS выполнены 8 сквозных тестов и отдельная
интерактивная проверка PDF-диалогов. Независимые эталоны покрывают OC/CCR/bailout,
высоту/SI, многоуровневые профили и сетку 10 ft.

Проверка [чистого публикуемого состава](docs/development/public-checkout-validation.md)
прошла: restore/tests/analyze/format, macOS Debug и Android APK без приватного
архива. iOS compile-only проверен с временным target15; стандартный target13
блокируется установленным Xcode SDK.
Непроверенные нативные сценарии доступности сохранены в отчёте;
их успешное прохождение не заявляется.
Точный статус и ограничения платформ —
[в отчёте проверок](docs/development/validation-current.md).

## Telegram Mini App

Планы и настройки хранятся локально. Для переноса планов между устройствами
используйте экспорт и импорт JSON.
[Открыть в Telegram](https://t.me/DecoPlannerBot?startapp) ·
[Открыть в браузере](https://hashev.github.io/DecoPlanner/).

## Разработка

Базовое окружение: Flutter 3.41.6 stable / Dart 3.11.4. Обновление SDK не требуется.

```sh
flutter pub get
cd packages/deco_core
dart pub get
cd ../..
flutter analyze
flutter run -d macos
```

Тесты: `flutter test` из корня, `dart test` из пакета ядра. Нативный сценарий:
`flutter test integration_test/plan_flow_test.dart -d macos`. macOS minimum:12.0.
При работе через агента используются официальный Dart/Flutter MCP для анализа,
тестов и подключения к приложению. Архитектура: root Flutter app + чистый
`packages/deco_core`, без Java/JAR/JavaFX в runtime.

Целевые платформы: iOS, Android, macOS, Windows. Наличие scaffold не означает
успешную сборку или проверку каждой платформы. Матрица фактических проверок
обновляется по мере реализации. CI проверяет PR/main, сборку Windows,
macOS и Android; релизы GitHub Releases выпускаются только по тегам
`vMAJOR.MINOR.PATCH`. [Выпуск и установка](docs/development/releases.md),
[отчет проверки CI/CD](docs/development/reports/ci-release-validation.md).

### Веб-сборка и проверка расчётов

```sh
bash tool/web/build.sh --base-href /DecoPlanner/
python3 tool/web/check_workers.py
```

Скрипт сборки добавляет `planner_worker.dart.js` в `build/web`. Для локальной
публикации в корне сайта укажите `--base-href /`. Проверка запускает Chromium
и сравнивает ответы Web Worker с эталонами. Если `google-chrome` отсутствует
в PATH, передайте путь к браузеру через `--chrome`.
[Публикация в GitHub Pages и настройка Telegram](docs/development/telegram-mini-app.md).

## Материалы

- [UX-проект](docs/ui/README.md) и [SVG-макеты](docs/ui/mockups/README.md).
- [Исследование расчётов](docs/calculations/README.md).
- [Локальный архив оригинала](docs/development/reference.md) — необязателен для приложения.
- [Задачи реализации](openspec/changes/archive/2026-11-13-implement-flutter-decompression-planner/tasks.md).

## Лицензия и участие

Собственный исходный код распространяется под [MIT](LICENSE).
Лицензии шрифтов и остальных сторонних компонентов сохранены отдельно:
[уведомления](docs/development/third-party-notices.md).

Репозиторий публичный. Создание pull request и запись в основной репозиторий
доступны приглашённым collaborators. Правила участия описаны в
[CONTRIBUTING.md](CONTRIBUTING.md). Использование, изменение и распространение
кода по MIT доступны всем; приглашение требуется для участия в этом репозитории.

Оригинальный Windows-дистрибутив и полный анализ сохранены только в игнорируемом
`local/reference/` и не входят в репозиторий или runtime приложения.
Main защищена: изменения только через PR с успешным CI, без обязательного
второго reviewer. Android APK подписывается постоянным ключом; Windows ZIP
и macOS ZIP пока без доверенной подписи издателя. Публикация в магазины и
встроенное автообновление не настроены.
