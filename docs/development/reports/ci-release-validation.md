# Проверка CI и выпуска

Изменение configure-ci-and-tag-releases, 2026-11-14. Это промежуточный отчет;
незавершенные пункты задач не считаются проверенными.

## Локально

- Официальный Dart MCP: анализ приложения без ошибок, 266 тестов приложения
  и 1006 тестов ядра прошли.
- 20 Python unit tests release tooling: версии/границы, отказ gate при
  failure/cancelled/skipped, неполный runtime/APK, неверный SHA, тег вне main,
  повреждение артефакта, частичная загрузка и безопасный повторный выпуск.
- Публичные Python-аудиты и strict OpenSpec: прошли без local/oracles.
- actionlint: workflows прошли проверку.

## Android

На Medium_Phone_API_36.0 (API 36) установлен настоящий release APK 0.1.0
(versionCode 1000, applicationId io.github.hashev.decoplanner). Через экран
приложения сохранен план «Новый план» с одним погружением. APK 0.1.1
(versionCode 1001) с тем же сертификатом установлен `adb install -r`.
После force-stop/relaunch библиотека содержит тот же сохраненный план;
UI hierarchy до/после проверена. Оба APK прошли apksigner и проверку
applicationId/versionName/versionCode. QA-версии не опубликованы.

SHA-256 публичного сертификата:
`9B4B027F83F9450F6080389156E7E3E513D20500D56AD24D8FFBD33F4B12CB60`.

Gradle :app:assembleRelease без переменных подписи завершается ошибкой
`Release signing requires DECOPLANNER_ANDROID_KEYSTORE`; fallback отсутствует.
GitHub environment release содержит четыре signing-секрета и ожидаемый отпечаток сертификата.
Резервная копия keystore проверена по содержимому и извлечением сертификата;
пути и ограничения локальной копии описаны в releases.md.

## Hosted CI

PR: https://github.com/hashev/DecoPlanner/pull/1.
Первый прогон 43574469523 обнаружил отсутствие core test dependencies до
root analyze в чистом checkout. Restore переставлен перед анализом.
Windows/macOS/Android build jobs первого прогона прошли, итоговый gate
завершился failure. Этот неуспешный прогон также служит проверкой, что общий gate не становится
успешным при ошибке зависимого задания. Прогон 43575035734: checks, Windows package/launch, Android build прошли.
macOS app собрано и запущено; команда Launch Services open не завершилась,
хотя процесс приложения работал. Устаревший прогон отменен; smoke исправлен
на проверку процесса с ограниченным ожиданием и завершением launcher.
Результаты окончательного прогона будут добавлены после завершения.

## Ограничения локальной macOS проверки

Xcode 27.1 на этой машине: Flutter 3.41.6 release_unpack_macos не проходит
lipo -verify_arch для universal framework, хотя lipo -archs показывает
arm64 и x86_64. SDK и расчетный код не изменялись ради обхода. Окончательная
проверка macOS выполняется на согласованном hosted macos-15, включая сборку,
упаковку, запуск app с quarantine и нативный integration test.

Публичный релиз/реальный тег не создавался. Защита main включается после
получения успешного CI с зарегистрированным check context.
