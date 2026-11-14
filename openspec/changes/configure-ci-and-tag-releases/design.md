# Design

## Context

См. proposal.md. Репозиторий hashev/DecoPlanner публичный, main пока без защиты, workflows отсутствуют; действует collaborators_only. В Android стоит com.example.deco_planner и debug signing для release, macOS содержит шаблонные идентификатор/copyright. Flutter 3.41.6 / Dart 3.11.4, root lockfile фиксирован. README определяет flutter analyze/test, отдельный dart test ядра и integration_test/plan_flow_test.dart на macOS. Ручной PDF-тест требует взаимодействия и не подходит CI.

В /Users/yurik/Projects/ffido/.github/workflows/release.yml проверена схема отдельного android-sign job: постоянный keystore из Secrets, временный файл с chmod 600, универсальный flutter build apk, проверка сертификата при упаковке. Переносится принцип, не ключ, не серверный updater и не триггер master: у DecoPlanner релизы только по тегу.

## Goals / Non-Goals

**Goals:** чистый checkout, единый обязательный статус, согласованная версия трех платформ, устанавливаемый и обновляемый APK.

**Non-Goals:** изменение lib/ и расчетов, новые способы доставки, генерация частных эталонов, автоматическое обновление приложения. Не переносить всю инфраструктуру ffido.

## Decisions

### CI и единый gate

.github/workflows/ci.yml на pull_request в main и push main; общую проверку переиспользует tag workflow через workflow_call. Не применять path filters к обязательным заданиям. Стабильный уникальный статус `DecoPlanner CI gate` с always() проверяет results всех обязательных jobs, включая cancelled/skipped. PR job использует contents:read, без pull_request_target, без release environment и секретов. Actions фиксируются полным SHA, runner images — явными версиями; SDK строго 3.41.6. Зависимости восстанавливаются с проверкой root lockfile; core резолвится из собственного pubspec (lockfile пакета не публикуется).

Проверки: dart format --output=none --set-exit-if-changed для lib, test, integration_test, test_driver и lib/test ядра; flutter analyze; анализ и dart test в packages/deco_core; flutter test в корне. Публичные Python-аудиты numerical_fixtures, calculation_coverage, corrections, settings_features, vpm_multilevel_reference, vpm_redescent_reference; docs/ui/tools/audit_design.py; openspec validate --specs --strict и strict-валидация активных changes. Не запускать recapture с local/oracles. Учитывать side effect design-аудита при проверке чистоты; не менять хешированные исходные эталоны/лицензии ради whitespace.

Build matrix: Windows x64 на windows-2022, macOS на macos-15, Android на ubuntu-24.04 с Java 17 и требуемым Android SDK/NDK. На macOS также обязательный flutter test integration_test/plan_flow_test.dart -d macos с timeout. Не запускать manual/pdf_dialogs_test.dart с --run-skipped. PR Android использует явно выделенную validation/debug сборку; публичный release никогда не получает debug fallback. Альтернатива только Linux-тестов исключена: не выявляет проблемы Windows/macOS plugins и упаковки.

### Версии и триггеры

release.yml: только push tags v*, затем строгая проверка vMAJOR.MINOR.PATCH без prerelease/leading zeros. Checkout точного SHA с полной историей, проверка достижимости из origin/main до чтения секретов. Повторить CI на этом SHA, не полагаться на старый статус PR. Версия из тега передается --build-name; versionCode = major*1000000 + minor*1000 + patch, minor/patch 0..999, результат 1..2100000000. Неподдерживаемые версии отклоняются до сборки; публичная новая версия должна быть выше последней выпущенной. Общий скрипт версии покрыть нормальными/граничными/некорректными входами. Альтернатива run_number не выбрана: привязывает Android версию к счетчику workflow, а не версии продукта.

### APK и постоянная идентичность

До первой публикации принять идентификатор io.github.hashev.decoplanner для Android и macOS, обновить Android namespace/package согласованно с MainActivity, заменить scaffold copyright. Это меняет идентичность ранее установленных debug-сборок; они не считаются публичной линией обновлений. Windows bundle получает корректные product/company/version metadata без изменения расчетного кода.

При apply создать отдельный release-keystore DecoPlanner вне Git, подготовить защищенную резервную копию и загрузить через gh secret set без вывода значений. Secrets: ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS; variable ANDROID_CERT_SHA256 — отпечаток публичного сертификата. Пароли не хранить в tracked файлах или shell history. Проверить восстановление копии и совпадение сертификата. Отсутствие безопасного места резервной копии — конкретный блокер первого выпуска, не повод использовать debug ключ.

Только release-job восстанавливает ключ во временный файл, ограничивает доступ и удаляет его при любом результате. Gradle release требует явную release signing config. Проверять apksigner verify --print-certs и сравнение SHA-256. Собирать универсальный APK, не AAB. Проверить две последовательные подписанные QA-версии на Android emulator: установка A, сохранение тестового плана, adb install -r B, сохранность данных; QA APK не публиковать как релиз. Автообновление из интерфейса не добавлять.

[Flutter Android deployment](https://docs.flutter.dev/deployment/android) описывает release-подпись. Ключ приложения ffido не читается и не используется.

### Комплект релиза и публикация

Windows ZIP содержит весь build/windows/x64/runner/Release, а не только exe. CMake InstallRequiredSystemLibraries добавляет app-local MSVC runtime и notice Microsoft; упаковщик отклоняет отсутствие обязательных DLL. macOS ZIP создается ditto с сохранением структуры .app; выпускать universal arm64+x86_64, проверить lipo для исполняемых файлов/встроенных нативных библиотек, сборку обоих slices и deployment target 12.0. Если зависимость не собирается в нужную архитектуру — выпуск блокируется, состав поддержки не сужается молча. Android APK универсальный. Имена содержат продукт, версию, OS и архитектуры; публикуются SHA256SUMS и manifest версии/SHA/архитектур/сертификата Android/статуса desktop-подписи.

Windows без Authenticode и macOS без Developer ID/notarization — осознанное начальное ограничение, не требующее покупки аккаунтов в этой задаче. Инструкции описывают обычный download/install и предупреждения ОС; проверить открытие macOS сборки, загруженной с quarantine, и Windows ZIP на чистом окружении. Не утверждать успешную установку по одному факту компиляции.

Build jobs имеют contents:read; только финальный publisher получает contents:write после успеха всех jobs. Создать draft, загрузить и проверить весь комплект, затем публиковать. Concurrency на тег не отменяет текущую публикацию. Повторный запуск опубликованного тега проверяет SHA/manifest и завершает без замены assets; несовпадение — ошибка. Не использовать --clobber. Прерванный draft допускает восстановление только после проверки исходного SHA; нельзя автоматически удалять опубликованные версии.

[GitHub workflow events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push) определяет tag push trigger.

### Защита main

Ruleset main: active, require pull request, required approving review count 0, обязательный `DecoPlanner CI gate`, strict актуальность относительно main, без bypass, запрет force push/deletion. Не включать read-only lock и не требовать внешнего reviewer. Сохранить public и collaborators_only. Проверить API и отклонение контрольного прямого push без изменения ветки. Предпочесть ruleset классической branch protection из-за явного отсутствия bypass; не создавать два конкурирующих набора правил.

[GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) объясняет required status checks и admin bypass по умолчанию; для этого проекта обходов не настраивать.

## Risks / Trade-offs

- Потеря ключа Android → защищенная резервная копия до первого релиза; без нее обновления существующей установки невозможны.
- Hosted runners и GUI integration → проверить реальный прогон; timeout/ошибка остаются красным gate, без continue-on-error.
- Windows/macOS без доверенной подписи → документировать ограничения и проверить установку; сертификаты отдельной задачей.
- Ruleset может заблокировать bootstrap → сначала PR с реально выполненным CI и известным context, затем защита, затем merge через PR.
- Первый публичный тег задает версию продукта → QA без публичного релиза; не выбирать и не публиковать реальный первый тег за владельца.

## Migration Plan

1. Реализовать в отдельной ветке; проверить scripts/workflows/сборки. Настроить отдельный Android ключ и Secrets без коммита секретов.
2. Открыть PR, получить успешный CI. Включить main ruleset с проверенным именем статуса, проверить API, merge только через PR.
3. Проверить signing/установку и упаковку без публикации (локально/validation workflow без contents:write). Первый реальный тег публикуется по отдельному указанию владельца с выбранной версией; инфраструктура не требует тестового публичного релиза.
4. Откат workflow через исправляющий PR. Опубликованные теги/файлы не переписывать; исправления доставлять новой версией, постоянный ключ сохранять.
