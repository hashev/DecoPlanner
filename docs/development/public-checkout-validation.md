# Проверка публикуемого состава

2026-11-13, Flutter3.41.6 / Dart3.11.4, macOS arm64.
В отдельной временной директории развёрнут только публикуемый набор из
`git ls-files --cached --others --exclude-standard`, без private reference,
oracle sources, .dart_tool, build, Pods, пользовательских документов и Git history.
Локальный manifest содержит SHA каждого файла; сам manifest и временные логи
хранятся в игнорируемом local/. Commit, remote и CI/CD не создавались.

## Реально выполнено в чистой копии

- Официальный MCP pub get корня и чистого Dart-пакета — PASS.
  Корневой lockfile остался побайтно прежним; SDK и package constraints не менялись.
- Официальный MCP: **1006 core tests**, **211 app tests** — PASS;
  analyze обоих пакетов без ошибок; format131 Dart files,0changed.
- Публичные численные аудиты inventory/provenance/assertions, матрицы,
 30corrections, VPM descending/redescent — PASS.
- Settings80controls и public design455entries/18screens/363boards,
 144layout groups/402markdown links — PASS. Приватная проверка в этом режиме
 явно не выполняется, отсутствие reference не выдаётся за её успех.
- `flutter build macos --debug` — PASS с заново созданными caches/Pods/build.
  Есть предупреждение стороннего file_selector_macos0.9.5+1 о deprecated
 `allowedFileTypes`; оно не подавлялось. Release/signing не проверялись.

Дополнительно выполнена iOS compile-only проверка: стандартный
`flutter build ios --debug --no-codesign` остановлен Xcode27.1 из-за minimum13.0
при поддерживаемом SDK диапазоне15.0–27.1. Повторный `xcodebuild` с временными
`CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=15.0` — BUILD SUCCEEDED.
Это не стандартная сборка заявленного minimum13 и не запуск/подпись. Минимум
исходного проекта не повышался. CocoaPods штатно добавил integration entries
в Xcode project/workspace только чистой временной копии. Предупреждения
deprecated API сторонних printing/share/file_selector не подавлялись.

В чистой копии не запускалось второе приложение и не выполнялись повторно native
UI integration: эта проверка подтверждает restore/tests/build без архива.
Native8standard повторно прошли в основном рабочем каталоге через официальный
MCP;1interactive PDF выполнен там ранее.

## Состав и сохранность

В исходном наборе проверены отсутствие local/, workflows, Java classes,
Windows runtime executable/DLL и signing material. Единственный JAR — штатный
Android Gradle wrapper, необходимый scaffold. Проверены ignore для .env,
local/reference, build, local.properties, user-data, exports и p12; обязательные
pubspec.lock, шрифты, SVG manifest и Gradle wrapper не игнорируются.

Проверка характерных private-key/AWS/GitHub/OpenAI token signatures не нашла
совпадений. Это целевой pattern scan, не утверждение о доказанном отсутствии
любого возможного секрета. Все5 font/OFL files соответствуют provenance SHA;
лицензионные notices поставляются локально и регистрируются в приложении.
Оригинал и код внешних oracle не включены ни в runtime, ни в public-набор.

Restore/build/format не меняли executable/test/fixture исходники или root lock.
Статический UX audit ожидаемо перегенерировал свой artifact-audit.json:
в чистой копии отсутствуют необязательные PNG-превью, что явно отражено в отчёте.
Последующие обновления документации/checkbox не меняют проверенные исходники.

Собственная открытая лицензия ещё требует отдельного решения владельца;
это сохранённый workflow follow-up. GitHub remote, commit/push, signing,
установщики и CI/CD остаются отдельными поручениями.

Весь change ещё не завершён: [статус и ограничения доступности/платформ](validation-current.md).

Android Debug APK также собран из чистого набора: `flutter build apk --debug`
— PASS, без signing/release и без подключения устройства. Gradle/SDK dependencies
восстановлены штатным toolchain; source/target8 warnings сторонних модулей
не подавлялись. APK и все build caches остаются вне публикуемого набора.

## Повтор после accessibility исправлений

В новой временной директории развёрнут актуальный public manifest из940файлов,
снова без local/reference и локальных caches. Официальные MCP restore,
1006core/266app tests, analyze обоих пакетов и format137/0changed прошли.
Публичные numerical/settings/design audits и свежие macOS Debug/Android Debug APK
builds проходят. Root lockfile и численные fixtures не менялись. Отдельный
native8/8 прогон в основном каталоге также повторён после окончательных правок.
Предыдущая iOS compile-only проверка относится к предшествующему срезу;
новая iOS сборка после UI-изменений не выполнялась. Последующие изменения
этого отчёта не меняют проверенный executable/test source.
