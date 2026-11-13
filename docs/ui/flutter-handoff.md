# Передача Flutter-разработчику

Это дизайн для будущего приложения iOS/Android/macOS/Windows. Flutter-проект не создан, SDK/пакеты не выбраны. Исходное ядро не перенесено. Опора: [расчётный контракт](../calculations/contract.md), [ограничения](../calculations/limitations.md), [экраны](screens.md), [сценарии](flows.md).

## Компоненты

| Дизайн | Flutter mapping | Ответственность |
|---|---|---|
| Глобальная навигация | Scaffold, NavigationBar / NavigationRail | Текущий destination, без пересоздания plan state |
| Адаптивные панели | LayoutBuilder, Row/Column, Expanded/Flexible, ConstrainedBox | Доступная ширина; формы≤640; при крупном тексте последовательная структура |
| Формы уровней/газов | Form, TextFormField, selectors, FocusTraversalGroup | Label/unit/error, временный ввод, submit всех полей |
| Уровни/остановки | ListView.builder; desktop table при достаточной ширине | Стабильный ID строки, сохранение редактирования, раскрытие деталей |
| Диалоги | Dialog / fullscreen editor, FocusScope | Focus trap/return, Save/Cancel, последствия удаления |
| Статус | Semantics live region + текстовый компонент | Неактуальность/ошибки/завершение, без announce каждой цифры |
| Shortcuts | Shortcuts, Actions, Focus | Контекстные клавиши и доступные текстовые альтернативы |
| Профиль/ткани | Компонент графика + численная таблица | Выбор точки всеми inputs, единицы, легенда; пакет пока не выбран |
| Тема | ThemeData/ColorScheme + semantic extensions при необходимости | Только разрешённые token pairs; масштабирование текста |

SVG — спецификационные рисунки, не виджеты для вставки целиком. В приложении используются настоящие поля/кнопки/semantics. Material Symbols outlined при необходимости сопровождают текст; у иконок единый стиль и область 48. Макеты 200% используют компактную кнопку «Меню» с доступным полным именем вместо тесной нижней панели. Обычная мобильная подпись «Инстр.» имеет semantic label «Инструменты».

## Слои и модели состояния

View отображает immutable snapshot и передаёт команды ViewModel. ViewModel хранит ввод и состояния, не вычисляет декомпрессию. Репозиторий/вычислительная граница изолирует будущий расчётный движок. Constructor injection и Listenable/ChangeNotifier достаточны для начальной реализации; выбор codegen/DI/state-management не требуется этим дизайном. Офлайн-расчёт не требует сетевых сервисов.

Смысловые сущности: PlanDraft, DiveDraft, LevelDraft, GasDraft, ModelSettings, AltitudeSettings, Cylinder, CalculationSnapshot, ScenarioResult, ToolDraft. Это названия для handoff, не публичный API существующего кода. Draft хранит raw input и parsed quantity отдельно: пустой/промежуточный ввод не обнуляет физическую величину. GasId/DiveId стабильны при сортировке; связи не зависят от индекса видимой строки.

CalculationSnapshot содержит requestId, inputRevision, stateDependencyRevision, model/settings/units, result либо structured failure. ToolResult дополнительно связан с toolRevision; стоимость — с recipeRevision. Поддерживаются empty/draft/invalid/calculating/ready/stale/error/unavailable. Старый ответ не принимается после изменения входов; invalidation распространяется от dive N на следующие dive и связанные bailout. Не следует инвалидировать физический результат из-за темы или масштаба. Переключение единиц сохраняет каноническую величину без повторного округления.

## Вычислительная граница

Входы/выходы основаны на PlanRequest/PlanResult из contract.md: модель B/C/VPM, OC/CCR/bailout, settings, уровни, газы, начальное состояние и SI. UI не передаёт обфусцированные имена Java, глобальные O или FXML ID. Физические величины имеют unit tags; проценты UI явно переводятся в доли. Бар, ATA и эквивалентная глубина давления не взаимозаменяемые подписи. Для сравнения и печати сохраняются входы и контекст результата.

Capabilities возвращают поддерживаемые модели/режимы/комбинации, диапазоны параметров, применимость переключений, смешивания/real gas и ограничения объёма range. Если capability нет, UI объясняет unavailable. Не реализовывать fallback фиктивными данными. Исходные ограничения лицензии не являются capability собственного продукта.

Ошибки разделяются на field validation, unsupported capability, numerical failure/non-convergence, timeout и environment failure. Пользователь получает короткую причину и действие; stacktrace/названия Java-классов не попадают в основной flow. Диагностический контекст хранится для разработчика отдельно. UI не блокируется вычислением; механизм isolate/native worker выбирается при реализации ядра.

Рецепт смешивания возвращает последовательность шагов с gas/amount/pressure, drain либо impossible; boolean legacy-флаг нельзя интерпретировать как универсальный success. Стоимость использует актуальный рецепт, объём баллона, единицы цен и фиксированную top-up плату. No reserves — обязательная подпись, не placeholder для отсутствующего алгоритма.

## Платформенные различия

macOS: Command+Enter для расчёта; Windows: Ctrl+Enter. В обоих Tab/Shift+Tab по порядку чтения, Escape закрывает диалог с восстановлением focus, Enter подтверждает активную форму. Delete внутри поля не удаляет уровень. На touch кнопки 48; drag/swipe никогда не единственный путь. Системная рамка окна и оконные кнопки не рисуются вручную.

iOS/Android: SafeArea, доступная высота при клавиатуре, прокрутка к ошибочному полю и submit. Back с изменённой формой даёт Save/Discard/Continue; модальное окно не уничтожает черновик. Отказ системного share/print сохраняет preview. На desktop resize не сбрасывает данные и не запускает расчёт. Ни ориентация, ни тип оборудования не выбирают breakpoint.

## Будущая runtime-проверка — ещё НЕ выполнена

| ID | Платформы | Шаги | Ожидаемый результат |
|---|---|---|---|
| RT01 | Все | Заполнить P02; открыть P03 и вернуться | Значения и выбранный dive сохранены |
| RT02 | macOS/Windows | Resize599→600→999→1000→1440 и обратно | Те же данные, активный раздел и результат; без overflow |
| RT03 | iOS/Android | Portrait→landscape, split view где доступно | Нет потери формы, все действия достижимы |
| RT04 | Все | Установить самый большой системный текст и 200% | Рефлоу, доступ к полям/CTA, без обрезки |
| RT05 | iOS/Android | Открыть клавиатуру на нижнем поле, submit invalid | Поле/ошибка/Save видимы, focus не закрыт клавиатурой |
| RT06 | macOS/Windows | Только клавиатура: создать уровень, переставить, рассчитать, Escape | Все действия доступны; focus возвращён; no Delete data loss |
| RT07 | iOS/macOS | VoiceOver: форма, ошибка, раскрытие, график | Имена/units/states объявлены; график имеет таблицу |
| RT08 | Android/Windows | TalkBack/Narrator, аналогичный маршрут | Тот же смысловой порядок, нет немых icon actions |
| RT09 | Все | Reduced motion + расчёт/переходы | Необязательная анимация снята; обратная связь остаётся |
| RT10 | Все | Тёмная/светлая тема во всех состояниях | Контраст текста/фокуса и сообщений сохраняется |
| RT11 | Все | Изменить dive1 из 3; запоздалый ответ; unsupported VPM | Все зависимости stale, старый ответ игнорируется, нет fake success |
| RT12 | Все | Печать/share cancel/failure; Back изменённого редактора | Preview/черновик сохранены; понятное восстановление |

Для реализации использовать official dart-flutter MCP для анализа/тестов и подключения к релевантному running app. При изменениях executable lib соблюдать локальное правило hot reload/restart. Сейчас исполняемого Flutter-кода и релевантного приложения нет; runtime validation недоступна и не заменена проверкой PNG. Flutter widget/state tests потребуются при реализации, не для статического документа.
