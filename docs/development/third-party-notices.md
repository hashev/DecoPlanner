# Сторонние ресурсы и происхождение

## Шрифты приложения

Fira Sans Regular/SemiBold и Fira Code поставляются локально. Лицензия SIL OFL1.1:
[уведомление Fira Sans](../../assets/fonts/firasans-OFL.txt),
[уведомление Fira Code](../../assets/fonts/firacode-OFL.txt).
Оригинальные copyright notices сохранены в этих файлах. Исходный репозиторий
Google Fonts, точный commit/URL каждого файла и SHA256 записаны в
[assets/fonts/provenance.json](../../assets/fonts/provenance.json).
Fontconfig подтвердил покрытие русского языка во всех трёх TTF.

Приложение регистрирует эти уведомления в LicenseRegistry; они доступны через
«Настройки → Лицензии компонентов». Шрифты не загружаются из сети при запуске.

## Flutter и зависимости

Flutter/Dart SDK и пакеты используют собственные лицензии; стандартная страница
лицензий Flutter собирает notices зависимостей. Версии зафиксированы в root
pubspec.lock. flutter_localizations обеспечивает русские системные контролы;
integration_test — dev dependency и не является расчётным backend.

## Исследовательские источники

Оригинальный Java-дистрибутив/декомпиляция и исходники независимых oracle остаются
в игнорируемом local/. Они не включаются в приложение. Численные fixtures в
packages/deco_core/test содержат provenance отдельно для исходных наблюдений,
независимых результатов и исправлений. Нормализация и изменения precision
указаны явно; модифицированный reference не назван untouched benchmark.

Собственный исходный код опубликован под MIT по решению владельца; см.
[LICENSE](../../LICENSE). Отдельные лицензии сторонних компонентов и ресурсов
сохраняют действие; корневая MIT не переоформляет права на эти материалы.

PDF/printing (Apache2.0) и image (MIT) подключены из pub.dev; версии
зафиксированы в pubspec.lock, notices входят в Flutter licenses. PDF встраивает
поставляемые Fira Sans с указанной выше OFL; сетевые шрифты не используются.
