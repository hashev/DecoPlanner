# Проверка состояний и доступности

Промежуточный аудит реализации 2026-11-13, Flutter3.41.6/Dart3.11.4.
Проверка semantics/widget tree не заменяет прослушивание настоящего screen reader.
Задача10.3 принята владельцем с перечисленными ограничениями; перечисленные ниже ограничения не считаются PASS.

## Состояния (7.2)

PlannerViewModel хранит последовательность, настройки/газы и snapshots. Изменение
раннего dive делает устаревшими все последующие dive и связанные bailout;
изменение только bailout сохраняет основной результат. Проверено на реальной
цепочке из трёх dive с тремя ветвями, с сохранением старых результатов и raw draft.
Ответы worker ограничены generation/revision/dependency/model/protocol identity.
Ошибка основного или отдельного branch сохраняет ввод, исправление даёт новый
результат. DocumentSession восстанавливает raw drafts и помечает кеши stale.

P05 масштабирует временную ось ×1–×4. Горизонтальное перемещение доступно
жестом, scrollbar и отдельными кнопками влево/вправо; «Весь профиль» сбрасывает
масштаб/позицию. Касание выбирает ближайшую физическую точку в преобразованной
координате. Численная таблица/ползунок/кнопки точек остаются альтернативой графику.
Масштаб — состояние представления, не физический параметр; тема и единицы
сохраняют масштаб и identity результата. Клавиатурная активация проверена Tab/Enter.

RangeViewModel отклоняет неверный диапазон типизированной ошибкой и восстанавливается
на исправленном запросе. Убрано асинхронное окно перед созданием handle:
немедленная отмена больше не возобновляет запуск после очистки старой подписки.
Старая подписка отменяется без ожидания, callbacks защищены generation.

Доказательства: planner_view_model_test, planner_bailout_view_model_test,
range_view_model_test, profile_view_test, document_session_test,
mixing_view_model_test и form/tool/widget tests.

## RT01–RT12

| Проверка | Фактическое покрытие | Осталось |
|---|---|---|
| RT01 поля/назад | Widget формы/dirty Back/Cancel/Save, native редакторы OC/CCR/bailout | Системный Back на физических mobile |
| RT02 resize | Widget599/600/999/1000/1440, сохранность результата/раздела | Нативные точные breakpoints599/600/999/1000/1440 и Windows; Mac zoom/unzoom проверен |
| RT03 orientation | Widget portrait/landscape, формы доступны | Физические iOS/Android/split view |
| RT04 text200 | Основной shell, формы, инструменты, P05/P06/P08/PDF на нескольких размерах | Самый большой системный Dynamic Type на mobile |
| RT05 keyboard/error | Form validation/submit и сохранность raw input | Физические mobile keyboard/insets; остальные маршруты |
| RT06 keyboard | Ползунок профиля, zoom/pan Tab/Enter; обычные Material controls | Полный маршрут без мыши и остальные модальные формы/Escape |
| RT07 VoiceOver | Semantics labels, live regions, численная альтернатива графикам | Настоящий VoiceOver iOS/macOS |
| RT08 TalkBack/Narrator | Автоматический labeledTapTargetGuideline для shell/инструментов/настроек | Настоящие TalkBack/Narrator, полный аудит icon actions |
| RT09 reduced motion | Theme animation duration0; route builder убирает переход при disableAnimations; расчёт сохранён | Native системная настройка и все модальные/необязательные анимации |
| RT10 contrast | Flutter textContrastGuideline и androidTapTargetGuideline48 для видимой области shell/инструментов/настроек при375/1000 в обеих темах, с прокруткой | Остальные состояния/раскрытия и визуальный focus contrast; P05/P06/P08 и5dialogs дополнительно проверены ниже |
| RT11 dependencies | Три dive/три bailout, late answers, cancel/timeout/error/retry; реальное ядро | Итоговый сквозной аудит всей матрицы |
| RT12 print/back | PDF adapter failure/retry, native Save/Print cancel и Share dismissal, raster/preview, dirty Back | Физическая печать и mobile OS dialogs |

## Reduced motion

При системном disableAnimations отключена анимация смены темы. Общий
PageTransitionsTheme пропускает визуальное движение обычных MaterialPageRoute;
при обычных настройках делегирует стандартному platform builder Flutter.
WidgetsBindingObserver отслеживает изменение accessibility features во время
работы. Это не меняет расчётный revision и не перезапускает worker.

Автоматические guidelines проверяют только смонтированную/видимую область.
Проход нескольких scroll-позиций основных разделов не заявляется как проверка
всех экранов или как WCAG-сертификация. Ошибки форм дополнительно используют
стандартные error semantics InputDecorator и live-region для общих ошибок.

Формы уровней/настроек/переключений/bailout/баллонов теперь переводят focus
к первому invalid-полю и прокручивают его после layout ошибки. Проверен
сценарий375×667 с keyboard inset180px: пустая глубина, сохранённый O2,
переход с нижней части формы обратно к ошибке без потери введённых значений.
Это имитация insets, не проверка физической mobile-клавиатуры.

Дополнительно6widget tests проходят для level/settings/gas-switch dialogs в обеих
темах: Enter открывает, Tab остаётся в модальном маршруте и достигает отмены,
Enter отменяет без изменения плана и возвращает primary focus исходной кнопке.
Это проверка трёх диалогов, не всей матрицы focus return/Escape.

## Дополнение задачи10.3: фактически выполнено

Полный текущий прогон: **266 app unit/widget tests PASS**, analyze чистый,
MCP hot reload успешен, runtime errors отсутствуют. Численное ядро не менялось.

- `dialog_keyboard_test.dart`:40случаев (level/settings/switches/bailout/tank,
  обе темы,375/1000, Tab→Enter и Escape). Проверяются trapping/return фокуса,
  неизменность плана, полные semantic labels полей с единицами,48targets/contrast.
- `dirty_escape_test.dart`:4случая изменённых level/bailout drafts375×667,
  обе темы; Escape открывает подтверждение, повторный Escape сохраняет ввод,
  keyboard discard возвращает focus. При disableAnimations длительности
  входа/выхода editor и confirmation равны нулю.
- `result_accessibility_test.dart`:12случаев P05/P06/P08 обеих тем и375/1000,
  labels/48targets/contrast с прокруткой, прямые имена profile icon actions.
  Проверки относятся к смонтированным состояниям; collapsed секции не выдаются
  за проверенные раскрытые поля.
- `icon_names_test.dart`: имена иконок — настоящие semantic labels, а не только
  tooltip. До исправления regression воспроизводила пустое имя. Нативный AX
  после сборки показывает имена Documents/Help/reorder/delete на русском.
- `profile_safe_area_test.dart`:2случая375×667 с top47/bottom34, обе темы;
  последняя кнопка профиля и последняя интерактивная строка численной таблицы
  остаются выше системного индикатора. До исправления кнопка достигала667px
  вместо безопасного предела633px. SafeArea добавлена также на соответствующие
  самостоятельные routes расхода/range/catalog/mixing/auxiliary tools.
- `form_validation_test.dart`:2сценария supportsAnnounce=false/true. Сохраняются
  сырые значения, focus первой ошибки виден выше keyboard inset180; сообщение
  доступно отдельным live region либо отправляется ровно одним announcement.
  Inline error не обязан входить в label текстового поля: это разные semantics
  узлы по контракту Flutter3.41.6.

Исправления: стандартный showDialog при barrierDismissible=false игнорировал
Escape; теперь общий showPlannerDialog сохраняет запрет внешнего клика,
проводит Escape через maybePop/PopScope и учитывает reduced motion.
Все20вызовов приложения используют этот путь, включая Help/confirm/SI.
Отдельные numeric values и вычислительные алгоритмы не менялись.

### Нативная macOS проверка

Проверено через настоящий AX-tree/окно: имена иконок, открытие переключений,
Escape, OC30m/20min, zoom→unzoom→zoom с сохранением ready и метрик. После
проверки восстановлены30m/20min, выполнен пересчёт и возвращён исходный размер
окна. Предыдущий долго живший собственный debug process перестал реагировать
на UI; остановлен только он и его идентифицированный leftover child, после
свежего MCP launch действия работали. Это не ошибка расчёта и не ложный PASS
для прежних неприменившихся действий.

VoiceOver: по разрешению владельца системный переключатель подтверждён
**off→on→off**. Caption panel уже была включена, её настройка не менялась.
Доступ к окну/панели VoiceOver по имени и системному пути дал два таймаута
Computer Use -10005. Речь/субтитры не удалось наблюдать, поэтому фактическое
произнесение и полный VoiceOver маршрут **не подтверждены**. Utility закрыта,
системный переключатель возвращён в исходное off. AX-проверки и widget semantics
не подменяют этот незавершённый пункт.

После принятия задачи10.3 остаются непроверенными: настоящий VoiceOver/TalkBack/Narrator, нативные
mobile keyboard/insets/Back/largest Dynamic Type и полный маршрут RT06 всех
модальных состояний ещё требуют исполнения. Наличие платформенного scaffold
и автоматических контролей не означает PASS этих проверок.

Итог после последнего исправления autofocus:266app/1006core в новой чистой
публикуемой копии,8/8native macOS,137formatted/0changed,analyze/runtime errors
чистые,macOS Debug иAndroid Debug APK — PASS. `dialog_autofocus_test.dart`
проверяет, что внутреннее поле названия сохраняет autofocus при общей Escape
policy. Финальный helper использует FocusScope, не перехватывающий фокус поля.

## Решение владельца о приёмке

Владелец явно принял10.3 как готовую: «Давай считать что 10.3 готова».
Задача закрыта по этому решению с сохранением известных ограничений.
Это не меняет результаты проверок: непроверенные нативные RT-сценарии
и фактическая озвучка screen readers не считаются прошедшими.
