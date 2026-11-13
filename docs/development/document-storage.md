# Документы и безопасная запись

`PlannerDocument` — immutable документ приложения, `PlanRequest` остаётся чистым
контрактом расчёта. Схема документа1 не совпадает с версией расчётной модели.
Сохранение/загрузка реализованы в `DocumentRepository`; экран управления файлами,
автосохранение и native import/export подключаются отдельно в задаче7.4.

## JSON

UTF-8 envelope содержит `format: decoplanner-plan`, `schemaVersion: 1`,
`sha256` и `document`. SHA-256 вычисляется по компактному JSON payload с
рекурсивной сортировкой object keys; порядок списков и численные значения
сохраняются. Перестановка ключей не меняет checksum, изменение данных меняет.

Payload содержит:

| Поле | Содержание |
|---|---|
| id/name | Стабильный файловый ID и пользовательское название |
| createdAt/modifiedAt | ISO8601 UTC; modifiedAt не раньше createdAt |
| modelVersion/plan | Исходная версия модели и полный PlanRequest: уровни, SI, параметры, газы, bailout links и initial state |
| preferences | Метры/футы, тема, пользовательский textScale |
| gases/tanks/settingsPresets | Типизированные справочники с собственными уникальными ID |
| results | Result snapshots с inputRevision/dependencyVersion, всеми tissues/VPM arrays и oxygen unavailable reason |
| comparisons | Замороженные пары полного ввода и результатов с названием, временем и собственной modelVersion |
| toolDrafts | Точные строки незавершённых форм; пустой/нечисловой ввод не теряется |

Core JSON читатели повторно проверяют физические данные. Все списки/maps
закрыты для изменения. Ключ результата совпадает с dive/bailout ID, версия
результата — с сохранённой версией контекста; snapshot revision не из будущего.
Размер ограничен32MiB, nesting —128. Некорректный UTF-8/JSON, состав, metadata,
checksum, oversized и неизвестная schema дают разные typed failures.

При смене calculation modelVersion совместимые физические входы schema1
читаются текущим input contract; исходная версия сохраняется в документе.
`usesCurrentModel=false` запрещает выдавать сохранённые outputs за актуальный
расчёт. Старые числа/причины CNS и замороженные comparisons не переписываются
под новую версию. Unsupported document schema не перезаписывается даже при
наличии backup. Импорт/открытие не должны менять живой план до успешной проверки.

## Файлы и восстановление

Каталог: `path_provider.getApplicationSupportDirectory()/plans`, пути собирает
`package:path`. Только ASCII ID `[A-Za-z0-9][A-Za-z0-9_-]{0,79}` участвует в
файловом имени; название пользователя не используется как путь.

Запись последовательно выполняет:

1. Encode/hash/size validation вне UI isolate.
2. Запись `<id>.pending` с flush, чтение и побайтовую/schema/checksum проверку.
3. Копирование проверенного прежнего primary через `<id>.last-good.pending`
   в `<id>.last-good.json`; старый primary ещё сохранён.
4. Публикацию pending через rename в `<id>.json`.
5. Удаление оставшихся временных файлов без удаления primary/backup.

Чтения/записи сериализованы одним repository instance. Ошибка операции не
отравляет очередь. Encoding, parsing, hash и полная проверка записанных байтов
выполняются в отдельных isolates; чтение ограничено и по metadata, и по chunks.

Повреждённый или отсутствующий primary позволяет открыть проверенный backup
с `recoveredFromBackup` и исходной причиной. Чтение ничего не перезаписывает.
Если backup уже является единственной хорошей копией, repair-save не заменяет
его перед публикацией нового primary. Orphan `.pending` не считается документом.
Ошибка после publication может означать уже опубликованную новую ревизию;
предыдущая всё ещё доступна в last-good. Future schema, oversized и IO failures
не маскируются автоматическим открытием другого документа.

Проверены fault injection всех11стадий, torn/wrong-but-valid temporary data,
corrupt/missing primary, repair failure, unknown schema, old model, очередь
после ошибки, небезопасные ID, size limit и parent heartbeat на крупном документе.
Native macOS integration отдельно проверяет реальный application-support путь,
запись двух ревизий и last-good recovery в изолированном временном подкаталоге;
пользовательские документы тест не заменяет.

## Экран документов и автосохранение

Кнопка «Документы» в app bar открывает список с созданием, сохранением,
переименованием и подтверждаемым удалением. Ошибочные и неизвестные документы
остаются видны в списке с причиной; пригодный backup помечен явно. При старте
открывается последний изменённый доступный план; ошибка другого файла показана
в редакторе. Прочитанные результаты всегда stale до нового расчёта.

DocumentSession отделяет переходы между документами от calculation ViewModel.
Изменения сохраняются через600мс после последнего уведомления, дополнительно
при inactive/paused и по кнопке. Текущий ввод сохраняется перед открытием,
созданием и импортом; при ошибке записи переход отменяется. Изменения во время
IO остаются dirty до следующей записи. Выбор погружения не меняет документ,
а тема/единицы/черновик MOD сохраняются без инвалидирования расчёта.
Принудительное завершение процесса до окончания debounce/записи может потерять
последние изменения; надпись «Сохранено локально» появляется после записи.

Удаление сначала публикует flush+rename marker `<id>.deleted`, затем убирает
primary/backup/pending. Marker запрещает поздним save и оставшемуся backup
восстановить удалённый план; повторное удаление завершает очистку. Marker
остаётся на диске. Импорт всегда получает новый ID.

При первом расчёте документа со старым modelVersion предыдущие результаты
сохраняются в отдельном comparison вместе с прежними входами и версией;
текущие результаты получают только текущую версию. Смена документа отменяет
worker и очищает выбор ветви; старый ответ не может подменить новый план.

## Перенос JSON

Импорт использует `file_selector`1.1.0: нативный выбор JSON на macOS/Windows,
Android/iOS. Чтение ограничено32МиБ по длине и каждому chunk; parsing/hash
выполняется в isolate. Отмена выбора ничего не меняет. Неверный документ,
unknown schema и oversized оставляют текущий ввод и ID на месте. Импорт
создаёт отдельную локальную копию, а исходный файл не перезаписывается.

Экспорт encode/hash выполняет в isolate. На macOS/Windows `file_selector`
предоставляет Save dialog и запись выбранного файла с flush. На Android/iOS
`share_plus`11.1.0 передаёт JSON системному share sheet; на iPad задаётся
popover origin. Dismissed считается отменой; unavailable показывает отсутствие
подтверждения. Выбор приложения в share sheet не объявляется гарантированным
сохранением. Название очищается для suggested filename, включая Windows
reserved names; внутри локального хранилища используются только ID.

Версии зависимостей разрешены на Flutter3.41.6/Dart3.11.4; share_plus11.1
поддерживает существующий Android Java17/AGP без обновления SDK. macOS sandbox
разрешает user-selected read/write. Регистрация, облако и сеть не используются.

Проверены99 root unit/widget tests и4 native macOS integration scenarios,
включая реальный экран list/save/new/open/delete, native storage/recovery и
OC/CCR/bailout. Mock platform adapter проверяет cancel/error/import/export;
375×667/667×375/1440×900 при text200% не дают overflow. Нативные Open/Save sheets
и mobile share sheet ещё не пройдены взаимодействиями с ОС; попытка CUA после
запуска main увидела актуальное окно, но AX/input не позволили пройти диалоги.
Windows/iOS/Android runtime недоступны в текущем списке устройств. Эти ограничения
не считаются успешной проверкой платформенных диалогов.
