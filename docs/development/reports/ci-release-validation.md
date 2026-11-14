# Проверка CI и выпуска

Изменение configure-ci-and-tag-releases, 2026-11-14.

## Автоматические проверки

[Hosted CI 43576858892](https://github.com/hashev/DecoPlanner/actions/runs/43576858892)
успешен: checks, Windows, macOS, Android и DecoPlanner CI gate. Код PR:
727207c2970cea87e8b4a14aa4a72db8ac574f6d; проверяемый merge SHA:
ec73f5f3846c10905fcf81ce4b3ce299b3bd9a7f.

- Анализ без ошибок, форматирование 137 Dart-файлов без изменений.
- 266 тестов приложения, 1006 тестов ядра, 24 теста release tooling.
- Публичные Python-аудиты, compileall, actionlint, strict OpenSpec validation.
- macos-15: universal release app, проверка bundle/version/minimum 12.0,
  arm64+x86_64 всех Mach-O, запуск распакованной app с quarantine,
  8 нативных integration tests. Подтвержден App Translocation; smoke отслеживает
  новый PID, не предполагая сохранения исходного пути executable.
- windows-2022: release ZIP с app-local MSVC runtime и уведомлением Microsoft,
  проверка numeric/string version и запуска распакованного executable.
- ubuntu-24.04 / Java 17: Android validation build без signing-секретов.

Прогон 43574469523 с ошибкой обязательного analyze дал failure в итоговом gate;
причина — порядок восстановления core test dependencies в чистом checkout —
исправлена. Отмененные/пропущенные задания также покрыты unit tests gate.
Ручной PDF-тест не запускался unattended. Старые прогоны во время отладки
smoke отменены; успешность заявлена для указанного полного прогона.

## Настоящие release APK

На Medium_Phone_API_36.0 установлен release APK 0.1.0 (versionCode 1000,
applicationId io.github.hashev.decoplanner). Через приложение сохранен план
«Новый план» с одним погружением. APK 0.1.1 (versionCode 1001) с тем же
сертификатом установлен adb install -r. После force-stop/relaunch библиотека
содержит тот же план; UI hierarchy до/после проверена. Оба APK прошли
apksigner и проверку applicationId/versionName/versionCode. Emulator остановлен.

Gradle assembleRelease без переменных подписи завершился ошибкой
`Release signing requires DECOPLANNER_ANDROID_KEYSTORE`, без debug fallback.
Отдельный постоянный keystore создан, защищенная локальная копия восстановлена
и проверена. GitHub environment release содержит четыре секрета, допускает
только теги v*, без required reviewers. Repository-wide копий секретов нет;
ожидаемый сертификат хранится в ANDROID_CERT_SHA256. Ограничения резервной
копии на одном компьютере и процедура восстановления описаны в releases.md.

## Комплект без публикации

Windows/macOS ZIP скачаны из успешного hosted-прогона. Из отдельного чистого
worktree на точно том же merge SHA собран подписанный универсальный Android APK
1.2.3+1002003; root lockfile не изменился. Проверены подпись, версии и три ABI.
Все три настоящих артефакта собраны общим package.py assemble в manifest и
SHA256SUMS; суммы всех файлов проверены. Публичные SHA/metadata сохранены в
[QA manifest](ci-release-qa-manifest.json). Бинарные QA-файлы остаются в
игнорируемом local/validation/; CI artifacts хранятся три дня.

Publisher проверен через mock GitHub API: частичная загрузка оставляет draft,
повторный запуск не перезаписывает assets, несовпадение SHA, перемещение тега,
повреждение файлов и неполный комплект блокируют публикацию. Реальная
публикация GitHub Release не выполнялась; первый реальный тег выбирает владелец.

## Main

Active ruleset 27256688: PR + строгий DecoPlanner CI gate от GitHub Actions
(app 15368), reviews=0, дополнительное approval для unattributed changes
отключено, bypass отсутствует; force push и deletion запрещены. Репозиторий
остался public, политика PR — collaborators_only. После включения защиты
GitHub сообщил CLEAN для green PR при нуле reviews.

Контрольные попытки push/merge без CI и проверка неизменности main выполняются
перед финальным завершением задачи; результаты будут добавлены ниже.

## Ограничения

Локальный Xcode 27.1 несовместим с Flutter 3.41.6 lipo -verify_arch в этой
universal release-сборке; SDK не изменялся ради обхода. Вместо этого macOS
release/packaging/runtime проверены на macos-15 hosted runner. Runtime на
macOS 12 и обычной пользовательской Windows-машине отдельно не проверялся.
Windows без Authenticode, macOS без Developer ID/notarization — ограничения
установки описаны в releases.md. Stores, iOS, встроенный updater вне этой задачи.
