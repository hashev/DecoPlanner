# Выпуск и установка

Этот документ описывает планируемый CI/CD. Пока изменение
`configure-ci-and-tag-releases` не завершено, наличие инструкции не означает,
что workflows, подпись или защита GitHub уже настроены.

## Версия

Публичный выпуск запускается push тега `vMAJOR.MINOR.PATCH` на коммите из main.
Примеры: `v0.1.0`, `v1.2.3`. Prerelease, build suffix, ведущие нули и
`v0.0.0` не допускаются. Minor и patch находятся в диапазоне 0..999.
Android versionCode равен `major * 1000000 + minor * 1000 + patch` и должен
находиться в диапазоне 1..2100000000. Следующий релиз должен иметь более
высокую версию; опубликованные теги и файлы не перезаписываются.

Проверка версии без сборки и публикации:

```sh
python3 tool/release/version.py v0.1.0
python3 tool/release/version.py v1.2.3
python3 -m unittest discover -s tool/release/tests -v
```

Windows numeric resource содержит major.minor.patch.0 (16-bit поля);
полный build number сохраняется в строковой версии. Android versionCode
не обрезается ради ограничений Windows.

Версия передается Flutter через `--build-name` и `--build-number`.
Изменять pubspec.yaml только ради тега не требуется. Все платформы собираются
из одного SHA, указанного в manifest релиза.

## Состав GitHub Release

- Windows x64 ZIP: executable, DLL и каталог data целиком.
- macOS universal arm64/x86_64 ZIP с приложением `.app`.
- Универсальный Android APK с постоянной release-подписью.
- Manifest с версией, исходным SHA, архитектурами, сертификатом Android и
  статусом подписи desktop; SHA256SUMS для проверки файлов.

Публикация происходит после успешных проверок и готовности всех платформ.
Windows первоначально без Authenticode, macOS без Developer ID/notarization:
ОС может показывать предупреждения при установке. Фактические проверки запуска
будут отражены в отчете реализации; данный документ их не подтверждает.

## Android

Скачать APK из GitHub Releases, разрешить установку приложений для браузера
или файлового менеджера и открыть APK. Следующий release APK устанавливается
поверх предыдущего с сохранением данных благодаря неизменным applicationId
и сертификату и увеличенному versionCode. Встроенный updater не предусмотрен.

Ключ DecoPlanner создается отдельно от ffido, хранится вне репозитория и имеет
защищенную резервную копию. Потеря ключа нарушает возможность обновления
существующих установок. Секреты не публикуются в Git, артефактах или логах.

Смена scaffold applicationId с `com.example.deco_planner` означает, что старые
локальные debug-сборки не относятся к публичной линии обновлений. Перенос
их данных не входит в выпуск; при необходимости экспортировать планы заранее.

## Ключ Android и восстановление

В GitHub environment `release` настроены секреты ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD,
ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS; variable ANDROID_CERT_SHA256 содержит
отпечаток публичного сертификата. Release-job получает их только на этапе
Android signing. Environment допускает только теги v*, без ручного reviewer.
PR workflows их не получают, в repository-wide Secrets копий ключа нет. Gradle release без явного
ключа завершается ошибкой; Android debug остается доступным для разработки.

Локальные signing-параметры: DECOPLANNER_ANDROID_KEYSTORE,
DECOPLANNER_ANDROID_STORE_PASSWORD, DECOPLANNER_ANDROID_KEY_PASSWORD,
DECOPLANNER_ANDROID_KEY_ALIAS. Значения не передавать аргументами команд или
через tracked файлы. Для проверки APK:

```sh
python3 tool/release/verify_android.py build/app/outputs/flutter-apk/app-release.apk --tag v0.1.0
```

Команда требует ANDROID_HOME и ANDROID_CERT_SHA256. Она проверяет apksigner,
applicationId, versionName и versionCode, не выводя секреты.

Ключ создан в `~/.local/share/decoplanner/signing`, защищенная копия —
`~/Documents/DecoPlanner-signing-backup`. Каталоги имеют режим 700, keystore и
credentials.json — 600. Копия проверена извлечением сертификата и сравнением
файлов. Оба расположения на одном компьютере: для защиты от потери устройства
владелец должен перенести копию в свое защищенное внешнее хранилище.

При восстановлении использовать keystore и credentials.json из копии,
сверить SHA-256 сертификата с ANDROID_CERT_SHA256 и загрузить прежние значения
через stdin `gh secret set`, без вывода паролей и без замены ключа новым.
Временный ключ CI удаляется trap при любом результате сборки.

## Публикация и исправление ошибок

После merge проверенного PR выбрать новую версию и создать тег на main.
Проверить ее resolver-ом до push. Только tag push публикует релиз;
ветки и PR релизов не создают. Первый реальный тег требует отдельного решения
владельца о версии; задача настройки не создает публичный тестовый релиз.

Release workflow проверяет принадлежность точного SHA к main, повторяет CI,
собирает и проверяет файлы, затем создает draft, загружает полный комплект,
скачивает и проверяет его и только после этого публикует. Неудачная загрузка
оставляет draft. При повторном запуске опубликованный релиз проверяется без
замены файлов. Несовпадение SHA или содержимого draft останавливает процесс:
не применять --clobber и не перемещать опубликованный тег; исправление
публиковать новой версией. Неподписанные desktop-сборки не являются notarized.
